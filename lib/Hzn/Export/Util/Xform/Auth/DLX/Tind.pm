
package Hzn::Export::Xform::Auth::DLX::Tind;

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

sub _110_980 {
	my $record = shift;
	
	$record->add_field(MARC::Field->new(tag => '980')->set_sub('a','AUTHORITY'));
	
	for my $tag (keys %{&AUTH_TYPE}) {
		if ($record->has_tag($tag)) {
			my $field = MARC::Field->new(tag => '980')->set_sub('a',AUTH_TYPE->{$tag});
			$record->add_field($field);
			last;
		}
	}
	
	if (my $field = $record->fields('110')) {
		if ($field->get_sub('9') eq 'ms') {
				$field->delete_subfield('9');
				my $field = MARC::Field->new(tag => '980')->set_sub('a','MEMBER');
			$record->add_field($field);
		}
	}
}
