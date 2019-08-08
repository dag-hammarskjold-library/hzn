use v5.10;

package Hzn::Util::Exclude::Auth;
use Moo;
extends 'Hzn::Util::Exclude';

has 'from', is => 'rw';
has 'to', is => 'rw';

has 'type', is => 'ro', default => 'auth';

has 'sql' => ( 
	is => 'ro', 
	default => sub {
		my $self = shift;
		
		my $from = $self->from;
		my $to = $self->to;
		
		qq {
			select auth# from (
				select auth# from author where see_flag = 1 
				union
				select auth# from subject where see_flag = 1
			) dd
			where auth# is not null
		}
	}
);

1;