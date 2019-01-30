use v5.10;
use strict;
use warnings;

package Hzn::Export::Bib::DLX::Tind;
use Moo;
use DBI;
use List::Util qw<any>;

use Hzn::Export::Util::Xform::Common::DLX::Tind;
use Hzn::Export::Util::Xform::Bib::DLX::Tind;

extends 'Hzn::Export::Bib::DLX';

has 's3_db_path', is => 'rw', required => 1;
has 's3_db_handle' => (
	is => 'ro', 
	lazy => 1, 
	builder => sub {
		my $self = shift;
		DBI->connect('dbi:SQLite:dbname='.$self->s3_db_path,'','')
	}
);

sub _xform {
	my ($self,$record,$audit,$item) = @_;
	
	$self->SUPER::_xform($record,$audit,$item);
	
	_XREFS: {
		Hzn::Export::Util::Xform::Common::DLX::Tind::_xrefs($record);
	}
	
	_001_005: {
		$record->delete_tag($_) for qw<001 005>;
	}
	
	_035: {
		Hzn::Export::Util::Xform::Common::DLX::Tind::_035($record,$self->marc_type);
	}
	
	_856_FFT: {
		Hzn::Export::Util::Xform::Bib::DLX::Tind::_856($record,$self->s3_db_handle);
	}
	
	_980: {
		$record->add_field(MARC::Field->new(tag => '980')->set_sub('a','BIB'));
	}
}

1;