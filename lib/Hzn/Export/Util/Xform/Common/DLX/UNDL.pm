use v5.10;
use strict;
use warnings;

package Hzn::Export::Util::Xform::Common::DLX::Tind;
use MARC::Field;

sub _xrefs {
	my $record = shift;
	
	for my $f ($record->fields) {
		if (my $xref = $f->xref) {
			$xref = '(DHLAUTH)'.$xref;
			$f->xref($xref);
		}
	}
}

sub _035 {
	my ($record,$type) = @_;
			
	for my $field ($record->get_fields('035')) {
		my $ctr = $field->get_sub('a');
		my $pre = substr $ctr,0,1;
		my $new = $record->id.'X';
		$new = $pre.$new if $pre =~ /[A-Z]/;
		$field->set_sub('a',$new,replace => 1);
		$field->set_sub('z',$ctr);
	}
		
	my $pre = lc($type) eq 'bib' ? '(DHL)' : '(DHLAUTH)';
	my $nf = MARC::Field->new(tag => '035');
	$nf->sub('a',$pre.$record->id);
	$record->add_field($nf);
}

1;