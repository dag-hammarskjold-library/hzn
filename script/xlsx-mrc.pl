use v5.10;
use strict;
use warnings;

package XLSX;
use Data::Dumper;

# dist
use Spreadsheet::ParseXLSX;

sub new {
	my ($class,$path) = @_;
	my $self = {};
	bless $self,$class; 
	
	my $parser = Spreadsheet::ParseXLSX->new;
	my $book = $parser->parse($path);
	
	for my $sheet ($book->worksheets) {
		my (@header,@rows);
		my ($rmin,$rmax,$cmin,$cmax) = ($sheet->row_range,$sheet->col_range);
		for my $row ($rmin..$rmax) {	
			my @row;
			for my $col ($cmin..$cmax) {
				if (my $cell = $sheet->get_cell($row,$col)) {
					if ($row == 0) {
						push @header, $cell->value;
					} else {
						push @row, $cell->value;
					}
				}
			}
			push @rows, \@row;
		}
		unshift @rows, \@header;
		push @{$self->{sheets}}, \@rows;
	}
	
	return $self;
}

sub sheets {
	my $self = shift;
	
	return @{$self->{sheets}};
}

package main;
# core 
use Getopt::Std;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use FindBin;
use List::Util qw<none>;


#use MongoDB;

# local
use lib "$FindBin::Bin/../lib";
use Hzn::SQL;
use Hzn::Util::Date;

RUN: {
	MAIN(options());
}

sub options {
	my @opts = (
		['h' => 'help'],
		['f:' => '.xlsx file']
	);
	
	getopts (join('', map {$_->[0]} @opts), \my %opts);
	if (! %opts || $opts{h}) {
		say join ' - ', @$_ for @opts;
		exit;
	}
	
	return \%opts;
}

sub MAIN {
	my $opts = shift;
	
	my @sheets = XLSX->new($opts->{f})->sheets;
	
	for my $sheet (@sheets) {
		my $header = shift @$sheet;
		for my $rownum (0..$#$sheet) {
			my $row = $sheet->[$rownum];
			for my $colnum (0..$#$row) {
				my $tag = $row->[$colnum];
				
			}
		}
	}
}