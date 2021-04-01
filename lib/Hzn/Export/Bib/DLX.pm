use v5.10;
use strict;
use warnings;

package Hzn::Export::Bib::DLX;
use Moo;
extends 'Hzn::Export::Bib';

use DBI;
use List::Util qw<any>;

use Hzn::Export::Util::Map::Bib::DLX::Body;
use Hzn::Export::Util::Map::Bib::DLX::Type;
use Hzn::Export::Util::Xform::Bib::DLX;

use constant DESC => {
	#'[cartographic information]' => 'a',
	#'[cartographic material]' => 'a',
	'[video recording]' => 'v',
	'[sound recording]' => 's',
	'ORAL HISTORY' => 's'
};

has 'marc_type', is => 'ro', default => 'Bib';

has 'body_mapper', is => 'ro', default => sub {Hzn::Export::Util::Map::Bib::DLX::Body->new};
has 'type_mapper', is => 'ro', default => sub {Hzn::Export::Util::Map::Bib::DLX::Type->new};

sub _exclude {
	my ($self,$record) = @_;
	
	return 1 if $record->record_status eq 'd';
	
	return 1 unless 
		$record->has_tag('191') 
		|| $record->has_tag('791') 
		|| any {$_ eq 'DHU'} $record->get_values('099','b');
			
	return 0;
}

sub _xform {
	my ($self,$record,$audit,$item) = @_;
	
	$self->SUPER::_xform($record,$audit,$item);
	
	DATES: {
		for my $pair (['269', 'a'], ['992', 'a'], ['992', 'b']) {
			my ($tag, $sub) = @$pair;
			
			if (my $field = $record->get_field($tag)) {
				my $new = join '-', grep {$_} ($field->get_sub($sub) =~ /(\d{4})(\d{2})?(\d{2})?/);
				$field->set_sub($sub, $new, replace => 1) if $new;
			}
		}
	}
	
	_007: {
		for my $field ($record->get_fields(qw/191 245/)) {
			while (my ($key,$val) = each %{&DESC}) {
				$record->add_field(MARC::Field->new(tag => '007', text => $val)) if $field->text =~ /\Q$key\E/;
			}
		}
	}
	
	_020: {
		$_->delete_subfield('c') for $record->get_fields('020');
	}
	
	_590: {
		next unless any {$_ eq 'VOT'} $record->get_values('039','a');
	
		my $new_field = MARC::Field->new(tag => '590');
		
		if ($record->has_tag('996')) {
			$new_field->set_sub('a','Vote');
		} else {
			$new_field->set_sub('a','Without Vote');
		} 
		
		$record->add_field($new_field);
	}
	
	_650: {
		last;
		for ($record->fields('650')) {
			my $ai = $_->auth_indicators;
			$ai && (substr($ai,0,1) eq '9') && $_->change_tag('651');
		}
	}
	
	_856: {
		for my $f ($record->get_fields('856')) {
			$record->delete_field($f) if 
				any {$f->get_sub('u') =~ /\Q$_\E/} qw|daccess-ods.un.org dds.ny.un.org|
				or $f->get_sub('3') =~ /Purchasing information/;
		}
	}
	
	_949: {
		$record->delete_tag('949');
	}
	
	_967: {
		for my $tag (qw/968 969/) {
			$record->change_tag($tag,'967');
		}
	}
	
	_981: {
		$self->body_mapper->map($record);
	}
	
	_989: {
		$self->type_mapper->map($record);
	}
	
	_993: {
		Hzn::Export::Util::Xform::Bib::DLX::_993($record);
	}
}

1;
