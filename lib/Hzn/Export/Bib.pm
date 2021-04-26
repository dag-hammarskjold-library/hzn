use v5.10;
use strict;
use warnings;

package Hzn::Export::Bib;
use Moo;
extends 'Hzn::Export';
with 'Hzn::Export::Common';
use Carp qw<confess>;

has 'marc_type', is => 'ro', default => 'Bib';

sub _exclude {
	return 0;
}

sub _xform {
	my ($self,$record,$audit,$item) = @_;
	
	# make sure subclasses are passing the necesary arguments to the superclass
	confess "Audit data required" unless ref $audit eq 'Hzn::Export::Util::AuditData';
	confess "Item data required" unless ref $item eq 'Hzn::Export::Util::ItemData';
	
	$self->_xform_common($record,$audit,$item);
	
	_949: {
		$record->delete_tag('949');
		$record->add_field($_) for $item->to_marc($record->id);
	}
}

1;

