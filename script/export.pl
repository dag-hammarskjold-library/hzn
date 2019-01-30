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
use Hzn::SQL::MARC;

use Hzn::Export::Auth;
use Hzn::Export::Auth::DLX;
use Hzn::Export::Auth::DLX::Tind;

use Hzn::Export::Bib;
use Hzn::Export::Bib::DLX;
use Hzn::Export::Bib::DLX::Tind;

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
		['M:' => 'mongo collection handle'],
		['t:' => 'export type ("DLX", "Tind"); defaults to raw MARC'],
		['3:' => 's3 db'], # deprecated
		['m:' => 'MongoDB connection string'],
	);
	my @copy = @ARGV;
	getopts (join('', map {$_->[0]} @opts), \my %opts);
	if (! %opts || $opts{h}) {
		say join ' - ', @$_ for @opts;
		exit;
	}
	$opts{$_} || die "required opt $_ missing\n" for qw||;
	-e $opts{$_} || die qq|"$opts{$_}" is an invalid path\n| for qw||;
	
	$opts{ARGV} = \@copy;
	return \%opts;
}

sub MAIN {
	my $opts = shift;
		
	my $class = do {
		my $class = 'Hzn::Export::'.($opts->{a} ? 'Auth' : 'Bib');
		$class .= '::DLX' if $opts->{t};
		$class .= '::Tind' if $opts->{t} && $opts->{t} eq 'Tind';
		$class;
	};
	
	my $export = $class->new; #
	
	$opts->{s} && $export->sql_criteria($opts->{s});
	$opts->{m} && $export->modified_since($opts->{m});
	$opts->{u} && $export->modified_until($opts->{u});
	
	if ($opts->{f}) {
		$export->output_type($opts->{f});
		$export->output_filename($opts->{o}),
	} elsif ($opts->{M}) {
		require MongoDB;
		$export->mongodb_collection_handle (
			MongoDB->connect($opts->{M})
			->get_database('undlFiles')
			->get_collection(($opts->{a} ? 'auth' : 'bib').'_JMARC')
		)
	}
	
	if ($opts->{t} && $opts->{t} eq 'Tind') {
		die 's3 db not found' unless -e $opts->{3};
		$export->s3_db_path($opts->{3});
	}
	
	$export->run;
}