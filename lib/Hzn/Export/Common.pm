use v5.10;
use strict;
use warnings;

package Hzn::Export::Common;
use Moo::Role;
use MARC;
use Hzn::Export::Util::AuditData;

sub _xform_common {
	my ($self,$record,$audit) = @_;
	
	#die unless ref $audit eq '';
		
	LEADER: {	
		my $l = $record->leader;
		
		if (length($l) > 24) {
			# chop off end of illegally long leaders in some old records
			$l = substr($record->leader,0,24);
		}
		if (index($l,"\x{1E}") > -1) {
			# special case for one record with \x1E in leader (?)
			$l =~ s/\x{1E}/|/g; 
		}
		
		$record->leader($l);
	}
	
	ENCODING: {
		$record->character_encoding_scheme('a');
	}
	
	_998: {
		my $f = $audit->to_marc($record->id);
		$f->set_sub('z',$self->export_id);
		$record->add_field($f);
	}
}

1;