use v5.10;
use strict;
use warnings;

package Index;
use Moo;

has 'index', is => 'rw', default => sub {{}};

package main;
use Time::Piece;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Hzn::SQL;

$|++;

my $index = Index->new;

print 'initializing @ '.localtime.'... ';
init_index('bib');
init_index('auth');
say "done";

while (1) {
	sleep 300;
	
	say 'scanning bibs @ '.localtime;
	scan_index('bib');
	
	say 'scanning auths @ '.localtime;	
	scan_index('auth');
}

sub init_index {
	my $type = shift;
	my $get = Hzn::SQL->new(statement =>  "select $type\#, timestamp from $type\_control", save_results => 1);
	$get->run;
	$index->index->{$type}->{$_->[0]} = $_->[1] for @{$get->results};
}

sub scan_index {
	my $type = shift;
	my $get = Hzn::SQL->new(statement =>  "select $type\#, timestamp from $type\_control", save_results => 1);
	$get->run;
	for (@{$get->results}) {
		my ($id,$timestamp) = @$_[0,1];
		my $key = \$index->index->{$type}->{$id};
		$$key //= '';
		if ($$key ne $timestamp) {
			say join ' ', $type,$_->[0],'changed!!!';
		
			$$key = $timestamp;
		}
	}
}