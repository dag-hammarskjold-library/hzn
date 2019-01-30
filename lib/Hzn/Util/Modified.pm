use v5.10;
use strict;
use warnings;

package Hzn::Util::Modified;
use Moo;
use Carp qw<confess>;
use List::Util qw<none>;
use Hzn::Util::Date;
use Hzn::SQL;

has 'marc_type', is => 'ro';

sub since {
	#my ($self,$from,$to,$mod_type) = @_;
	my ($self,%params) = @_;
	my ($from,$to,$mod_type) = @params{qw<from to mod_type>};
	
	$mod_type && (none {$mod_type eq $_} qw<all new changed>) && confess 'Invalid mod type';
	$mod_type ||= 'all';
	
	my $marc_type = lc $self->marc_type;
	my $sql = qq{select $marc_type\# from $marc_type\_control};
	
	FROM: {
		my ($fdate,$ftime) = Hzn::Util::Date::_8601_hzn($from);
		my $new = "create_date > $fdate or (create_date = $fdate and create_time >= $ftime)";
		my $changed = "change_date > $fdate or (change_date = $fdate and change_time >= $ftime)";
		my %more = (
			all => qq{where (($new) or ($changed))},
			new => qq{where ($new)},
			changed => qq{\nwhere ($changed)},
		);
		$sql .= "\n".$more{$mod_type}."\n";
	}
	
	TO: {
		last unless $to;
		my ($tdate,$ttime) = Hzn::Util::Date::_8601_hzn($to);
		my $new = "create_date < $tdate or (create_date = $tdate and create_time < $ttime)";
		my $changed = "change_date = null or change_date < $tdate or (change_date = $tdate and change_time < $ttime)";
		my %more = (
			all => qq{and (($new) and ($changed))},
			new => qq{and ($new)},
			changed => qq{and ($changed)}
		);
		$sql .= $more{$mod_type};
	}
	
	my @ids;
	Hzn::SQL->new(statement => $sql)->run (
		callback => sub {
			my $row = shift;
			my $id = shift @$row;
			push @ids, $id;
		}
	);
	
	return @ids;
}

1;