use v5.10;
use strict;
use warnings;

# core 
use Getopt::Std;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use FindBin;

# dist

# local
use lib "$FindBin::Bin/../lib";
use Hzn::SQL;
use Hzn::Util::Modified::Bib;

RUN: {
	MAIN(options());
}

sub options {
	my @opts = (
		['h' => 'help'],
		['s:' => 'sql statment'],
		['S:' => 'sql file'],
		['f:' => ''],
		['t:' => ''],
		['o:' => 'output file'],
		['v' => 'verbose: print results stream to STDOUT'],
		['u' => 'utf8']
	);
	my @copy = @ARGV;
	getopts (join('', map {$_->[0]} @opts), \my %opts);
	$opts{ARGV} = \@copy;
	if (! %opts || $opts{h}) {
		say join ' - ', @$_ for @opts;
		exit;
	}
	$opts{$_} || die "required opt $_ missing\n" for qw||;
	-e $opts{$_} || die qq|"$opts{$_}" is an invalid path\n| for qw||;
	return \%opts;
}

sub MAIN {
	my $opts = shift;
	
	my $sql = Hzn::SQL->new;
	$opts->{u} && $sql->encoding('utf8');
	$opts->{o} && $sql->output_file($opts->{o});
	$opts->{v} = 1 unless $opts->{o}; 
	$opts->{v} && $sql->verbose(1);
	
	if (my $statement = $opts->{s}) {
		$sql->statement($statement);
	} elsif (my $file = $opts->{S}) {
		$sql->script($file);
	}
		
	$sql->run;
}

__END__