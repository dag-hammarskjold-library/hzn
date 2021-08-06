use v5.10;
use strict;
use warnings;

package Hzn::Export::Auth::DLX;
use List::Util 'none';
use Moo;
extends 'Hzn::Export::Auth';

use Hzn::Export::Util::Exclude::Auth::DLX;

has 'excluder', is => 'ro', default => sub {Hzn::Export::Util::Exclude::Auth::DLX->new};

sub _exclude {
	my ($self, $record) = @_;

	return 1 if $record->get_field('150'); # and none {$record->id eq $_} (923382, 923383, 923384, 923385, 923386, 923387, 923388, 923389, 923392, 923393);
	return 1 if $record->record_status eq 'd';
	return 1 if $self->excluder->exclude($record->id);
}

sub _xform {
	my ($self, $record, $audit) = @_;
	
	$self->SUPER::_xform($record,$audit);
	
	_150: {
		last;
		if (my $field = $record->get_field('150')) {
			if ($field->ind1 eq '9') {
				$record->change_tag('150','151');
				$record->change_tag('450','451') if $record->has_tag('450');
				$record->change_tag('550','551') if $record->has_tag('550');
			}
		}
	}
	
	_4XX: {
		for my $tag (qw/400 410 411 430 450 490 491/) {
			$_->delete_subfield('0') for $record->get_fields($tag);
		}
	}
}

1;
