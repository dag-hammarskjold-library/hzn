use v5.10;
use strict;
use warnings;

# core 
use Getopt::Std;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use FindBin;
use List::Util qw<none>;

# dist
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

RUN: {
	MAIN(options());
}

sub options {
	my @opts = (
		['h' => 'help'],
		['b' => 'bibs'],
		['a' => 'auths'],
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
	
	my $t = time;
	
	my $type;
	$type = 'bib' if $opts->{b};
	$type = 'auth' if $opts->{a};
	
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
	
	UPDATE: {
		say 'update candidates: '.scalar(@to_update).'...';
		
		my $class = 'Hzn::Export::'.($type eq 'auth' ? 'Auth' : 'Bib').'::DLX';
		my $ids = join(',',@to_update) || 0;
		my $export = $class->new (
			output_type => 'mongo',
			mongodb_connection_string => $opts->{M},
			sql_criteria => "select $type\# from $type\_control where $type\# in ($ids)"
		);
		$export->run;
		
		say 'deleting '.scalar(@to_delete).'...';
		
		my $col = $export->data_collection_handle;
		for my $id (@to_delete) {
			$col->find_one_and_delete({_id => 0 + $id});
		}
	}
	
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
	
	print "\n";
	
	return \%hzn;
}

sub excludes {
	my ($type,$gte,$lte) = @_;
	
	print 'screening ineligible hzn records... ';
		
	my $exclude;
	if ($type eq 'bib') {
		$exclude = Hzn::Util::Exclude::Bib->new->ids($gte,$lte);
	} elsif ($type eq 'auth') {
		$exclude = Hzn::Util::Exclude::Auth->new->ids($gte,$lte);
	}
	
	say scalar keys %$exclude;
	
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
		for my $s (grep {$_->{code} eq $code} @{$f->{subfields}}) {
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
	
	my $cursor = $col->find($query,{'998' => 1});
	
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

