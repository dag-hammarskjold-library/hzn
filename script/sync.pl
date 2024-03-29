use v5.10;
use strict;
use warnings;

# core 
use Getopt::Std;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use FindBin;
use List::Util qw<none first>;
use DateTime;

# dist
use Tie::IxHash;
use MongoDB;

# local
use lib "$FindBin::Bin/../lib";
use Hzn::SQL;
use Hzn::Util::Date;
use Hzn::Util::Exclude::Bib;
use Hzn::Util::Exclude::Auth;
use Hzn::Export::Bib::DLX;
use Hzn::Export::Auth::DLX;

package main;
$| = 0;

my $OPTS = options();
my $type = $OPTS->{b} ? 'bib' : $OPTS->{a} ? 'auth' : die '-a or -b required';
mkdir 'logs';
open my $LOG, '>', "logs/sync_$type\_".time.'.txt' or die "$!";
*STDERR = $LOG;
say {$LOG} 'starting...';

my $mongo = MongoDB->connect($OPTS->{M});
my $db = $mongo->get_database('undlFiles');
my $db_log = $db->get_collection('hzn_dlx_log');
my $started = DateTime->now;
$db_log->insert_one(Tie::IxHash->new(action => 'sync', record_type => $type, started => $started, finished => undef));	

my $tries = 0;

sub fail {
	say $@;
	if (++$tries == 10) {
		say 'FATAL: retried max times';
		die $@."\nretried max times";
	}
		
	if (my $wait = $tries * 10) {
		say qq|retrying in $wait seconds...|;
		sleep $wait;
	}
}

RUN: {	
	if (my $chunk = $OPTS->{c}) {
		$OPTS->{g} || $OPTS->{l} && die 'can\'t use -c with -g or -l';
		
		my $max;
		
		MAX: {
			$max = Hzn::SQL->new(statement => "select max($type\#) from $type\_control", save_results => 1)->run->results->[0]->[0];
		
			unless ($max) {
				say "max ID not found";
				sleep(5);
				++$tries == 10 && die "max ID not found";
				goto MAX;
			}
		}
		
		for (my $x = 0; $x < $max; $x += $chunk) {
			say "syncing $type $x - ".($x + $chunk);
			
			$OPTS->{g} = $x;
			$OPTS->{l} = $x + $chunk;
			
			$tries = 0;
			
			CHUNK: eval {
				MAIN($OPTS);
			} or do {
				fail();
				
				goto CHUNK;
			}
		}
	} else {
		eval {
			MAIN($OPTS);
		} or do {
			fail();
	
			goto RUN
		}
	}
	
	$db_log->update_one({action => 'sync', record_type => $type, started => $started}, {'$set' => {'finished' => DateTime->now}});	
}

sub options {
	my @opts = (
		['h' => 'help'],
		['b' => 'bibs'],
		['a' => 'auths'],
		['c:' => 'chunk'],
		['g:' => 'id greater than'],
		['l:' => 'id less than'],
		['M:' => 'mongo connection string'],
		['o:' => 'output file']
	);
	
	my @copy = @ARGV;
	getopts (join('', map {$_->[0]} @opts), \my %opts);
	if (! %opts || $opts{h}) {
		say join ' - ', @$_ for @opts;
		exit;
	}
	
	VALIDATE: {
		next;
	}
	
	$opts{ARGV} = \@copy;
	return \%opts;
}

sub MAIN {
	my $opts = shift;

	CHECK_CONNECTION: {
		$mongo->list_databases;
	}

	my $t = time;
	my $type = $opts->{b} ? 'bib' : $opts->{a} ? 'auth' : die '-a or -b required';

		
	my ($gte,$lte) = map {0 + ($_ // 0)} @{$opts}{qw<g l>};

	my $hzn = scan_horizon($type,$gte,$lte);
	my $dlx = scan_dlx($opts->{M},$type,$gte,$lte);
	my @queue;
	
	my (@to_delete,@to_update);
	
	HZN: for my $id (keys %$hzn) {
		my ($h,$d) = map {$_ // ''} ($hzn->{$id},$dlx->{$id});
		if ($h ne $d) {
			# add the record to update queue;
			
			push @to_update, $id;
		}
	}
	
	DLX: for my $id (keys %$dlx) {
		if (! $hzn->{$id}) {
			# delete
			push @to_delete, $id;
		}
	}
	
	my $class = 'Hzn::Export::'.($type eq 'auth' ? 'Auth' : 'Bib').'::DLX';
	my $export = $class->new (
		output_type => 'mongo',
		mongodb_connection_string => $opts->{M},
	);
	my $wrote;
	
	UPDATE: {
		say 'update candidates: '.scalar(@to_update).'...';

		my $ids = join(',',@to_update) || 0;
		$export->sql_criteria("select $type\# from $type\_control where $type\# in ($ids)");
		$wrote = $export->run;
	}
	
	DELETE: {
		say 'deleting '.scalar(@to_delete).'...';
		
		my $data_col = $export->data_collection_handle;
		my $hist_col = $export->data_history_collection_handle;
		
		for my $id (@to_delete) {
		    my $record_hist = $hist_col->find_one({_id => 0 + $id}) || {};
			$record_hist->{deleted} = {'user' => 'HZN', 'time' => DateTime->now};
			$hist_col->replace_one({_id => $id}, $record_hist, {upsert => 1});
			$data_col->find_one_and_delete({_id => 0 + $id});
		}	
	} 

	say {$LOG} time." - $type: wrote $wrote; deleted ".scalar @to_delete;
	
	say "time elapsed: ".((time - $t) / 60)." minutes";
	say "done";
}

sub scan_horizon {
	my ($type,$gte,$lte) = @_;
	
	my %hzn;
		
	my $exclude = excludes($type,$gte,$lte);
	
	print 'scanning hzn... ';
	
	my $where = make_where($type,$gte,$lte);
	my $from = "from $type\_control";
	
	my $total = do {
		my $select = "select count(*)";
		my $get = Hzn::SQL->new(statement => join(' ',$select,$from,$where), save_results => 1)->run;
		$get->results->[0]->[0];
	};
	
	my $select = "select $type#, timestamp"; 
	my $sql = join ' ', ($select,$from,$where);
	my $i = 0;
	Hzn::SQL->new(statement => join ' ', ($select,$from,$where))->run (
		callback => sub {
			my $row = shift;
			my ($id,$update_id) = @$row;
			
			return if $exclude->{$id};
			$hzn{$id} = $update_id;
			_update_status($i++,$total);
		}
	);
	
	scalar keys %hzn == 0 && die "something is wrong";
	
	print "\n";
	
	return \%hzn;
}

sub excludes {
	my ($type,$gte,$lte) = @_;
	
	print "screening ineligible $type records... ";
		
	my $exclude;
	if ($type eq 'bib') {
		$exclude = Hzn::Util::Exclude::Bib->new->ids($gte,$lte);
	} elsif ($type eq 'auth') {
		$exclude = Hzn::Util::Exclude::Auth->new->ids($gte,$lte);
	}
	
	if (my $c = scalar keys %$exclude) {
		say $c
	} else {
		die "something is wrong";
	}
	
	return $exclude;
}

sub make_where {
	my ($type,$gte,$lte) = @_;
	
	if ($gte && $lte) {
		return "where $type# >= $gte and $type# <= $lte";
	} elsif ($gte) {
		return "where $type# >= $gte";
	} elsif ($lte) {
		return "where $type# <= $lte";
	} else {
		return '';
	}	
}

sub _get {
	my ($jmarc,$tag,$code) = @_;
	
	for my $f (@{$jmarc->{$tag}}) {
		for my $s (first {$_->{code} eq $code} @{$f->{subfields}}) {
			next if ! $s;
			return $s->{value};
		}
	}
}

sub scan_dlx {
	my ($connection_str,$type,$gte,$lte) = @_;
	
	my %dlx;
	
	local $| = 1;
	print 'scanning dlx... ';
		
	my $query = {};
	$query->{_id}->{'$gte'} = $gte if $gte;
	$query->{_id}->{'$lte'} = $lte if $lte;
	
	my $col = MongoDB->connect($connection_str)
		->get_database('undlFiles')
		->get_collection($type.'s');
	
	my $cursor = $col->find($query)->fields({'998.subfields' => 1});
	
	my $i = 0;
	while (my $jmarc = $cursor->next) {
		my $update_id = _get($jmarc,'998','x');
		$dlx{$jmarc->{_id}} = $update_id // '';
			
		_update_status($i,'?') if ($i % 100) == 0 || $i == 0;
		$i++;
	}	
		
	print "\n";
	
	return \%dlx;
}

sub _update_status {
	my ($current,$total) = @_;
	state $chars_to_delete = 0;
	$chars_to_delete = 0 if $current == 0;
	print "\b" x $chars_to_delete;
	my $status = "$current / $total ";
	print $status;
	$chars_to_delete = length $status;
}
