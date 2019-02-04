use v5.10;

package Hzn::Export::Auth::DLX::UNDL;
use Moo;
extends 'Hzn::Export::Auth::DLX';
use Hzn::Export::Util::Xform::Common::DLX::UNDL;

use MARC::Field;

use constant AUTH_TYPE => {
	100 => 'PERSONAL',
	110 => 'CORPORATE',
	111 => 'MEETING',
	130 => 'UNIFORM',
	150 => 'TOPICAL',
	151 => 'GEOGRAPHIC',
	190 => 'SYMBOL',
	191 => 'AGENDA'
};

sub _xform {
	my ($self,$record,$audit) = @_;
	
	$self->SUPER::_xform($record,$audit);
	
	XREFS: {
		Hzn::Export::Util::Xform::Common::DLX::UNDL::_xrefs($record);
	}
	
	_001_005: {
		$record->delete_tag($_) for qw<001 005>;
	}
	
	_035: {
		Hzn::Export::Util::Xform::Common::DLX::UNDL::_035($record,$self->marc_type)
	}
	
	_980: {
		$record->add_field(MARC::Field->new(tag => '980')->set_sub('a','AUTHORITY'));
			
		for my $tag (grep {$record->has_tag($_)} keys %{&AUTH_TYPE}) {
			my $field = MARC::Field->new(tag => '980')->set_sub('a',AUTH_TYPE->{$tag});
			$record->add_field($field);
			last; # there can only be one type; loop should only run once 
		}
		
		if (my $field = $record->fields('110')) {
			if ($field->get_sub('9') eq 'ms') {
				$field->delete_subfield('9');
				my $field = MARC::Field->new(tag => '980')->set_sub('a','MEMBER');
				$record->add_field($field);
			}
		}
		
	}
}

1;