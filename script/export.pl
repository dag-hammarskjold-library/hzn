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

# local
use lib "$FindBin::Bin/../lib";
use Hzn::SQL::MARC;

use Hzn::Export::Auth;
use Hzn::Export::Auth::DLX;
use Hzn::Export::Auth::DLX::UNDL;

use Hzn::Export::Bib;
use Hzn::Export::Bib::DLX;
use Hzn::Export::Bib::DLX::UNDL;

package main;

RUN: {
	MAIN(options());
}

sub options {
	my @opts = (
		['h' => 'help'],
		['a' => 'export auths'],
		['b' => 'export bibs'],
		['s:' => 'SQL statement'],
		['S:' => 'SQL script'],
		['m:' => 'modified since'],
		['u:' => 'modified_until'],
		['l:' => 'path to file containing list of ids'],
		['o:' => 'output file'],
		['R' => 'export in raw mode'],
		['D' => 'export in DLX mode'],
		['U' => 'export in UNDL mode'],
		['X' => 'export as XML'],
		['C' => 'export as MARC21 (.mrc)'],
		['K' => 'export as .mrk'],
		['B' => 'write exported data to MongoDB (as BSON)'],
		['M:' => 'MongoDB connection string'],
		['3:' => 'S3 db path']
	);
	
	my @copy = @ARGV;
	getopts (join('', map {$_->[0]} @opts), \my %opts);
	if (! scalar %opts || $opts{h}) {
		say join ' - ', @$_ for @opts;
		exit;
	}
	
	VALIDATE: {
		(none {$opts{$_}} qw<l m s S>) && die "-l, -m, -s or -S required\n"; 
		(none {$opts{$_}} qw<X C K B>) && die "-X, -C, -K, or -B required\n";
		(none {$opts{$_}} qw<R D U>) && die "-R, -D or -U required\n"; 
		
		$opts{D} && $opts{U} && die "-D and -U conflict\n";
		
		$opts{B} && ! $opts{M} && die "-M required with -B\n";
		$opts{U} && ! $opts{3} && die "-3 required with -U\n";
		
	}
	
	$opts{ARGV} = \@copy;
	return \%opts;
}

sub MAIN {
	my $opts = shift;
		
	my $class = do {
		my $class = 'Hzn::Export::'.($opts->{a} ? 'Auth' : 'Bib');
		$class .= '::DLX' if $opts->{D};
		$class .= '::DLX::UNDL' if $opts->{U};
		$class;
	};
	
	my $export = $class->new; #
	
	if (my $path = $opts->{l}) {
		open my $fh, '<', $path;
		my @ids;
		while (<$fh>) {
			my @row = split /\s/, $_;
			push @ids, $row[0];
		}
		my $ids = join(',',@ids);
		my $type = $opts->{a} ? 'auth' : 'bib';
		my $sql = "select $type\# from $type\_control where $type\# in ($ids)";
		$export->sql_criteria($sql);
	} elsif ($path = $opts->{S}) {
		local $/ = undef;
		open my $script, '<', $path;
		$export->sql_criteria(<$script>)
	} elsif ($opts->{s}) {
		$export->sql_criteria($opts->{s});
	} 
	
	$opts->{m} && $export->modified_since($opts->{m});
	$opts->{u} && $export->modified_until($opts->{u});
	
	$opts->{M} && $export->mongodb_connection_string($opts->{M});
	
	$opts->{U} && $export->s3_db_path($opts->{3});
	
	$opts->{X} && $export->output_type('xml');
	$opts->{C} && $export->output_type('marc21');
	$opts->{K} && $export->output_type('mrk');
	$opts->{B} && $export->output_type('mongo');
	
	$opts->{o} && $export->output_filename($opts->{o});

	$export->run;
}