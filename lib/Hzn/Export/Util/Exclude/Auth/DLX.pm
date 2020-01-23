use v5.10;
use strict;
use warnings;

package Hzn::Export::Util::Exclude::Auth::DLX;
use Moo;

use Hzn::SQL;

has 'data' => (	
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		
		my %data;
		for my $sql (map {"select auth# from $_ where see_flag = 1"} qw<author subject>) {
			my $get = Hzn::SQL->new(statement => $sql);
			$get->run (
				callback => sub {
					my $row = shift;
					my $xref = shift @$row;
					$data{$xref} ||= 1;
				}
			);
		}
		
		return \%data;
	}
);

sub exclude {
	my ($self,$id) = @_;
	return $self->data->{$id} ? 1 : 0;
}

1;