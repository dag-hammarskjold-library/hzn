use v5.10;
use strict;
use warnings;

package Hzn::Util::Date;
use Carp qw<confess>;
use Time::Piece;
use List::Util qw<any>;

# no functions are exported for now. call these using the fully qualified package name

# all datetimes are presumed to be UTC

sub hzn_unixish {
	my ($hzn_date,$hzn_time,$gmt_adjust) = @_;
	
	$hzn_date ||= 0;
	$hzn_time ||= 0;
	
	my ($dd,$tt) = (($hzn_date * 86400), ($hzn_time * 60));
	my $unixish = $dd + $tt;
	$gmt_adjust ||= 0;
	return $unixish + ($gmt_adjust * 3600);
}

sub unix_hzn {
	my $unix = shift;
	$unix ||= time;
	my $local = localtime($unix)->epoch;
	my $days = int ($local / 86400);
	my $mins = int (($local - ($days * 86400)) / 60);
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
	#returns 8601 in UTC
	
	return 0 if ! $hzn_date;
	$hzn_time ||= 0;
	$gmt_adjust ||= 0;
	
	my $unix = hzn_unixish($hzn_date,$hzn_time,$gmt_adjust);
	# since the Hzn "epoch time" is local, use localtime to actually get gmtime (ugh)
	return localtime($unix)->strftime('%Y%m%d%H%M%S');
}

sub _269_260 {
	my $date = shift // confess 'Date not provided';
	$date =~ s/[^\d]//g;
	my $mon = substr $date,4,2;
		
	my $format = sub {	
		my $len = length($date);
		if ($len == 4) {
			return '%Y';
		} elsif ($len == 6) {
			return '%b. %Y';
		} elsif ($len == 8) {
			if (any {$mon eq $_} qw<05 06 07>) {
				return '%e %B %Y';
			} else {
				return '%e %b. %Y';
			}
		} else {
			confess 'invalid date';
		}
	};
	
	return Time::Piece->strptime($date,'%Y%m%d')->strftime($format->());
}

sub _260_269 {
	my $date = shift // confess 'Date not provided';
	$date =~ s/[^\w\s]//g;
	return Time::Piece->strptime($date,'%d %b %Y')->strftime('%Y-%m-%d');
}

1;

