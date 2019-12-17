use v5.10;
use strict;
use warnings;

# Arguments: 
#	@ARGV[0] = <mongodb connection string>
#	@ARGV[1] = <wait time between updates in seconds> [optional. default is 300]

package Index;
use Moo;

has 'index', is => 'rw', default => sub {{}};

package main;
use Time::Piece;
use Time::Seconds;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Hzn::SQL;
use Hzn::Export::Bib::DLX;
use Hzn::Export::Auth::DLX;

$|++;

my $index = Index->new;

print 'initializing @ '.localtime.'... ';
init_index('bib');
init_index('auth');
say "done";

my $wait = $ARGV[1] // 300;
say 'next update time: '.localtime(time + $wait)->hms;
say '-' x 50;

while (1) {
	sleep $wait;

	say 'scanning bibs @ '.localtime;
	scan_index('bib');
	say '-' x 33;

	say 'scanning auths @ '.localtime;
	scan_index('auth');
	say '-' x 33;
	
	say 'next update time: '.localtime(time + $wait)->hms;
	say '-' x 50;
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
	
	my (@to_update,%seen);
	for (@{$get->results}) {
		my ($id,$timestamp) = @$_[0,1];
		my $key = \$index->index->{$type}->{$id};
		$$key //= '';
		if ($$key ne $timestamp) {
			push @to_update, $id;
			$$key = $timestamp;
		}
		$seen{$id} = 1;
	}
	
	say 'update candidates: '.scalar(@to_update).'...';
	
	UPDATE: {
		my $class = 'Hzn::Export::'.($type eq 'auth' ? 'Auth' : 'Bib').'::DLX';
		my $ids = join(',',@to_update);
		my $export = $class->new (
			output_type => 'mongo',
			mongodb_connection_string => $ARGV[0],
			sql_criteria => "select $type\# from $type\_control where $type\# in ($ids)"
		);
		
		RUN_EXPORT: { 
			if (@to_update) {
				my $tries = 0;		
				try {
					use autodie;
					$tries++;
					$export->run;
				} catch {
					warn join "\n", "export failed", $@;
					if ($tries < 3) {
						say "retrying...";
						sleep 5;
						goto RUN_EXPORT;
					} else {
						die "export failed $tries times :("
					}
				}
			}
		}
		
		my @to_delete = grep {! $seen{$_}} keys %{$index->index->{$type}};
		
		say 'deleting:          '.scalar(@to_delete).'...';
		
		my $col = $export->data_collection_handle;
		for my $id (@to_delete) {
			$col->find_one_and_delete({_id => 0 + $id});
			delete $index->index->{$type}->{$id};
		}
	}
}
