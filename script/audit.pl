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
	
	my (%dlx,%hzn,@queue);
	
	my $type;
	$type = 'bib' if $opts->{b};
	$type = 'auth' if $opts->{a};
	
	my ($gte,$lte) = map {0 + ($_ // 0)} @{$opts}{qw<g l>};

	HZN: {
		print 'screening ineligible hzn records... ';
		
		my $exclude;
		if ($type eq 'bib') {
			$exclude = Hzn::Util::Exclude::Bib->new->ids($gte,$lte);
		} elsif ($type eq 'auth') {
			$exclude = Hzn::Util::Exclude::Auth->new->ids($gte,$lte);
		}
		say scalar keys %$exclude;
		
		print 'scanning hzn... ';
		
		my $make_where = sub {
			if ($gte && $lte) {
				return "where $type# >= $gte and $type <= $lte";
			} elsif ($gte) {
				return "where $type# >= $gte";
			} elsif ($lte) {
				return "where $type# <= $lte";
			} else {
				return '';
			}
		};
		
		my $where = $make_where->();
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
	}
	
	DLX: {
		local $| = 1;
		print 'scanning dlx... ';
		
		my $query = {};
		$query->{_id}->{'$gte'} = $gte if $gte;
		$query->{_id}->{'$lte'} = $lte if $lte;
		
		my $col = MongoDB->connect($opts->{M})
			->get_database('undlFiles')
			->get_collection($type.'s');
		
		my $cursor = $col->find($query,{'998' => 1});
	
		my $i = 0;
		while (my $jmarc = $cursor->next) {
			my $update_id = update_id($jmarc);
			$dlx{$jmarc->{_id}} = $update_id // '';
			
			_update_status($i,'?') if ($i % 100) == 0 || $i == 0;
			$i++;
		}	
		
		print "\n";
	}
	
	my ($to_delete,$to_update) = (0,0);
	open my $out, '>', $opts->{o};
	
	for my $id (keys %hzn) {
		my ($h,$d) = map {$_ // ''} ($hzn{$id},$dlx{$id});
		if ($h ne $d) {
			# add the record to update queue
			say {$out} $id;
			$to_update++;
		}
	}
	
	for my $id (keys %dlx) {
		if (! $hzn{$id}) {
			# delete
			$to_delete++;
		}
	}
	
	say "scanned: ".scalar keys %hzn;
	say "elapsed: ".((time - $t) / 60)." minutes";
	say "update candidates: ".$to_update;
	say "flagged for deletion: ".$to_delete;
}

sub update_id {
	my $jmarc = shift;
	
	return get($jmarc,'998','x');
}

sub get {
	my ($jmarc,$tag,$code) = @_;
	
	for my $f (@{$jmarc->{$tag}}) {
		for my $s (grep {$_->{code} eq $code} @{$f->{subfields}}) {
			return $s->{value};
		}
	}
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

