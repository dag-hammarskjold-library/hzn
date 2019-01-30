use v5.10;
use strict;
use warnings;

package Hzn::Export::Auth;
use Moo;
extends 'Hzn::Export';
with 'Hzn::Export::Common';

has 'marc_type', is => 'ro', default => 'Auth';

sub _exclude {
	return 0;
}

sub _xform {
	my ($self,$record,$audit,undef) = @_;
	
	die "Audit data required" unless ref $audit eq 'Hzn::Export::Util::AuditData';
	
	$self->_xform_common($record,$audit);
}

1;