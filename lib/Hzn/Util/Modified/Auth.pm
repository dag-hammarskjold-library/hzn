package Hzn::Util::Modified::Auth;
use Moo;

extends 'Hzn::Util::Modified';

has 'marc_type', is => 'ro', default => 'bib';

sub since {
	my ($self,$from,$to) = @_;
	return $self->SUPER::since($from,$to);
}

1;