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
use Try::Tiny;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Hzn::SQL;
use Hzn::Export::Bib::DLX;
use Hzn::Export::Auth::DLX;
use MongoDB;

CHECK_CONNECTION: {
	my $check = MongoDB->connect($ARGV[0]);
	$check->list_databases;
}

$|++;

mkdir 'logs';
open my $LOG, '>', 'logs/log_'.time.'.txt' or die "$!";
*STDERR = $LOG;

my $index = Index->new;

say {$LOG} localtime.' starting';
print 'initializing @ '.localtime.'... ';
init_index('bib');
init_index('auth');
say "done";

my $wait = $ARGV[1] // 300;
say 'next update time: '.localtime(time + $wait)->hms;
say '-' x 50;

while (1) {
	sleep $wait;
	
	say 'scanning auths @ '.localtime;
	my $count = scan_index('auth');
	say '-' x 33;
	say {$LOG} localtime.' scanned auths; wrote '.$count;
	
	say 'scanning bibs @ '.localtime;
	scan_index('bib');
	say '-' x 33;
	say {$LOG} localtime.' scanned bibs; wrote '.$count;
	
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
	
	my ($tries, $count) = 0 x 2;
	
	UPDATE: if (@to_update) {
		my $class = 'Hzn::Export::'.($type eq 'auth' ? 'Auth' : 'Bib').'::DLX';
		my $ids = join(',',@to_update);
		my $export = $class->new (
			output_type => 'mongo',
			mongodb_connection_string => $ARGV[0],
			sql_criteria => "select $type\# from $type\_control where $type\# in ($ids)"
		);
		
		try {
			use autodie;
			$tries++;
			$count = $export->run;
		} catch {
			warn join "\n", "export failed", $@;
			if ($tries < 10) {
				say "retrying...";
				sleep $tries * 5;
				goto UPDATE;
			} else {
				die "export failed $tries times :("
			}
		};
		
		my @to_delete = grep {! $seen{$_}} keys %{$index->index->{$type}};
		
		say 'deleting:          '.scalar(@to_delete).'...';
		
		my $data_col = $export->data_collection_handle;
		my $hist_col = $export->data_history_collection_handle;
		
		for my $id (@to_delete) {
		    my $record_hist = $hist_col->find_one({_id => 0 + $id}) || {};
			$record_hist->{deleted} = {'user' => 'HZN', 'time' => DateTime->now};
			$hist_col->replace_one({_id => $id}, $record_hist, {upsert => 1});
			
			$data_col->find_one_and_delete({_id => 0 + $id});
			delete $index->index->{$type}->{$id};
		}
		
	}
	
	return $count // 0;
}
