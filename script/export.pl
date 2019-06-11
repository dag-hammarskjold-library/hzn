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
		['f:' => 'output format ("xml", "mrc", "mrk")'],
		['o:' => 'output file'],
		['m:' => 'modified since'],
		['u:' => 'modified_until'],
		['D' => 'export in DLX mode'],
		['U' => 'export in UNDL mode'],
		['X' => 'export as XML'],
		['C' => 'export as MARC21 (.mrc)'],
		['K' => 'export as .mrk'],
		['B' => 'write exported data to MongoDB (as BSON)'],
		['M:' => 'MongoDB connection string'],
	);
	
	my @copy = @ARGV;
	getopts (join('', map {$_->[0]} @opts), \my %opts);
	if (! %opts || $opts{h}) {
		say join ' - ', @$_ for @opts;
		exit;
	}
	
	VALIDATE: {
		(none {$opts{$_}} qw<X C K B A>) && die "-X, -C, -K, or -B required";
		($opts{B} || $opts{U}) && ! $opts{M} && die "-M required with -B and -U";
		! $opts{D} && ! $opts{U} && die "-D or -U required"; 
		$opts{D} && $opts{U} && die "-D and -U conflict";
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
	
	$opts->{s} && $export->sql_criteria($opts->{s});
	
	$opts->{m} && $export->modified_since($opts->{m});
	$opts->{u} && $export->modified_until($opts->{u});
	
	$opts->{M} && $export->mongodb_connection_string($opts->{M});
	
	$opts->{X} && $export->output_type('xml');
	$opts->{C} && $export->output_type('marc21');
	$opts->{K} && $export->output_type('mrk');
	$opts->{B} && $export->output_type('mongo');
	
	$opts->{o} && $export->output_filename($opts->{o});

	$export->run;
}