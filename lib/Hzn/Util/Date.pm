use v5.10;
use strict;
use warnings;

package Hzn::Util::Date;
use Carp qw<confess>;
use Time::Piece;
use List::Util qw<any>;

# no functions are exported for now. call these using the fully qualified package name

# all datetimes are presumed to be UTC

sub hzn_unix {
	my ($hzn_date,$hzn_time,$gmt_adjust) = @_;
	
	confess 'Hzn date not provided' if ! $hzn_date;
	$hzn_time ||= 0;
	
	my $unixish = ($hzn_date * 86400) + ($hzn_time * 60);
	$gmt_adjust ||= 0;
	return $unixish + ($gmt_adjust * 3600);
}

sub unix_hzn {
	my $unix = shift;
	$unix ||= gmtime;
	my $days = int ($unix / 86400);
	my $mins = int (($unix - ($days * 86400)) / 60);
	return ($days,$mins);
}

sub unix_8601 {
	my $unix = shift;
	return gmtime($unix)->strftime('%Y%m%d%H%M%S');
}

sub _8601_unix {
	my $str = shift // confess 'ISO 8601 string not provided';
	$str =~ s/[^\d]//g;
	$str .= '0' while length $str < 14;
	my $dt = Time::Piece->strptime($str,'%Y%m%d%H%M%S');
	return $dt->epoch;
}

sub _8601_hzn {
	my $date = shift // confess 'Date not provided';
	my $unix = _8601_unix($date);
	return unix_hzn($unix);
}

sub hzn_8601 {
	my ($hzn_date,$hzn_time,$gmt_adjust) = @_;
	confess 'Hzn date not provided' if ! $hzn_date;
	$hzn_time ||= 0;
	$gmt_adjust ||= 0;
	my $unix = hzn_unix($hzn_date,$hzn_time,$gmt_adjust);
	return unix_8601($unix);
}

sub _269_260 {
	my $date = shift // confess 'Date not provided';
	$date =~ s/[^\d]//g;
	my $len = length($date);
	confess 'invalid date' unless $date =~ /^\d+$/ && any {$_ eq $len} 4,6,8;
	return Time::Piece->strftime('%d %b. %Y') 
}

sub _260_269 {
	my $date = shift // confess 'Date not provided';
	$date =~ s/[^\w\s]//g;
	my $dt = Time::Piece->strptime($date,'%d %b %Y');
	return $dt->strftime('%Y-%m-%d');
}

1;

