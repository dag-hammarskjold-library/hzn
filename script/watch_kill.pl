use v5.10;
use strict;
use warnings;

use DateTime;
use MongoDB;

my $mongo = MongoDB->connect($ARGV[0]);

CHECK_CONNECTION: {
	$mongo->list_databases;
}

my $db = $mongo->get_database('undlFiles');
my $db_log = $db->get_collection('hzn_dlx_log');
my $q;

if (scalar @ARGV > 1 && $ARGV[1] eq 'y') {
	$q = 'y'
} else {
	print 'This will kill any running instances of `watch.pl`. Are you sure? (Y/N): ';
	$q = <STDIN>;
	chomp($q);
}

if (lc($q) eq 'y' or lc($q) eq 'yes') { 
	$db_log->insert_one({action => 'kill', time => DateTime->now});
	say "OK. Any running instances of `watch.pl` will quit before the next cycle";
} else {
	say "quitting"
}
