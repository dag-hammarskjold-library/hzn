use v5.10;

package Hzn::Util::Exclude;
use Moo;
use List::Util qw<any>;

sub ids {
	my ($self,$gte,$lte) = @_;
	
	my $type = $self->type;
	
	if ($gte) {
		$self->{sql} .= "and $type\# >= $gte";
	}
	if ($lte) {
		$self->{sql} .= "and $type\# <= $lte";
	}
	
	my $get = Hzn::SQL->new(statement => $self->{sql}, save_results => 1)->run;
	
	my %ids;
	$ids{$_} = 1 for map {$_->[0]} @{$get->results};
	
	return \%ids;
}

1;