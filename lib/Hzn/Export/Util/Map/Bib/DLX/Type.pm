use v5.10;
use strict;
use warnings;

package Hzn::Export::Util::Map::Bib::DLX::Type;
use Moo;
use List::Util qw<pairs>;
use MARC::Field;

use constant TYPE => {
	map => 'Maps',
	sp => 'Speeches',
	vot => 'Voting Data',
	img => 'Images and Sounds',
	docpub => 'Documents and Publications',
	rd => 'Resolutions and Decisions',
	rpt => 'Reports',
	mr => 'Meeting Records',
	lnv => 'Letters and Notes Verbales',
	pub => 'Publications',
	drpt => 'Draft Reports',
	drd	=> 'Draft Resolutions and Decisions',
	pr => 'Press Releases',
	ai => 'Administrative Issuances',
	ta => 'Treaties and Agreements',
	lco => 'Legal Cases and Opinions',
	nws => 'NGO Written Statements',
	pet => 'Petitions',
	cor => 'Concluding Observations and Recommendations',
	res => 'Resolutions',
	dec => 'Decisions',
	prst => 'Presidential Statements',
	sgr => 'Secretary-General\'s Reports',
	asr => 'Annual and Sessional Reports',
	per => 'Periodic Reports',
	vbtm => 'Verbatim Records',
	sum => 'Summary Records',
	sgl	=> 'Secretary-General\'s Letters',
};

sub _make_989 {
	my $field = MARC::Field->new(tag => '989');
	$field->set_sub($_->key,TYPE->{$_->value}) for pairs @_;
	return $field;
}

sub map {
	my ($self,$r) = @_;
	my $make = \&_make_989;
			
	Q_1: {
		last unless $r->check('245','*','*[cartographic material]*')
			|| $r->check('007','*','a')
			|| $r->check('089','b','B28')
			|| $r->check('191','b','ST/LEG/UNTS/Map*');
		$r->add_field($make->(a => 'map'));
	}
	Q_2: {
		last unless $r->check('089','b','B22');
		$r->add_field($make->(a => 'sp'));
	}
	Q_3: {
		last unless $r->check('089','b','B23');
		$r->add_field($make->(a => 'vot'));
	}
	Q_4: {
		last unless $r->check('245','*',qr/(video|sound) recording/)
			|| $r->check('007','*','s')
			|| $r->check('007','*','v')
			|| $r->check('191','*','*ORAL HISTORY*');
		$r->add_field($make->(a => 'img'));
	}
	Q_5: {
		last unless $r->check('191','*','*/RES/*');
		$r->add_field($make->(a => 'docpub', b => 'rd', c => 'res'));
	}
	Q_6: {
		last unless $r->check('191','a','*/DEC/*')
			&& $r->check('089','b','B01');
		$r->add_field($make->(a => 'docpub', b => 'rd', c => 'dec'));
	}
	Q_7: {
		last unless $r->check('191','a','*/PRST/*')
			|| $r->check('089','b','B17');
		$r->add_field($make->(a => 'docpub', b => 'rd', c => 'prst'));
	}
	Q_8: {
		last unless $r->check('089','b','B01')
			&& ! $r->check('989','b',TYPE->{rd});
		$r->add_field($make->(a => 'docpub', b => 'rd'));
	}
	Q_9: {
		last unless $r->check('089','b','B15')
			&& $r->check('089','b','B16')
			&& ! $r->check('245','*','*letter*from the Secretary-General*');
		$r->add_field($make->(a => 'docpub', b => 'rpt', c => 'sgr'));
	}
	Q_10: {
		last unless $r->check('089','b','B04');
		$r->add_field($make->(a => 'docpub', b => 'rpt', c => 'asr'));
	}
	Q_11: {
		last unless $r->check('089','b','B14')
			&& ! $r->check('089','b','B04');
		$r->add_field($make->(a => 'docpub', b => 'rpt', c => 'per'));
	}
	Q_12: {
		last unless $r->check('089','b','B16')
			&& $r->check('245','*','*Report*')
			&& $r->check('989','b','Reports');
		$r->add_field($make->(a => 'docpub', b => 'rpt'));
	}
	Q_13: {
		last unless $r->check('191','a','*/PV.*');
		$r->add_field($make->(a => 'docpub', b => 'mr', c => 'vbtm'));
	}
	Q_14: {
		last unless $r->check('191','a','*/SR.*');
		$r->add_field($make->(a => 'docpub', b => 'mr', c => 'sum'));		
	}
	Q_15: {
		last unless $r->check('089','b','B03')
			&& ! $r->check('989','b','Meeting Records');
		$r->add_field($make->(a => 'docpub', b => 'mr'));
	}
	Q_16: {
		last unless $r->check('089','b','B15')
			&& ! $r->check('245','*','Report*')
			&& ! $r->check('989','c','Secretary-General\'s*');
		$r->add_field($make->(a => 'docpub', b => 'lnv', c => 'sgl'));
	}
	Q_17: {
		last unless $r->check('089','b','B18')
			&& ! $r->check('089','b','Letters*');
		$r->add_field($make->(a => 'docpub', b => 'lnv'));
	}
	Q_18: {
		last unless $r->has_tag('022')
			|| $r->has_tag('020')
			|| $r->check('089','b','B13')
			|| $r->has_tag('079');
		$r->add_field($make->(a => 'docpub', b => 'pub'));
	}
	Q_19: {
		last unless $r->check('089','b','B08');
		$r->add_field($make->(a => 'docpub', b => 'drpt'));
	}
	Q_20: {
		last unless $r->check('089','b','B02');
		$r->add_field($make->(a => 'docpub', b => 'drd'));
	}
	Q_21: {
		last unless $r->check('191','b','*/PRESS/*')
			|| $r->check('089','b','B20');
		$r->add_field($make->(a => 'docpub', b => 'pr'));
	}	
	Q_22: {
		last unless $r->check('089','b','B12')
			|| $r->check('191','a',qr/\/(SGB|AI|IC|AFS)\//);
		$r->add_field($make->(a => 'docpub', b => 'ai'));
	}
	Q_23: {
		last unless $r->check('089','b','A19');
		$r->add_field($make->(a => 'docpub', b => 'ta'));
	}
	Q_24: {
		last unless $r->check('089','b','A15')
			|| $r->check('089','b','B25');
		$r->add_field($make->(a => 'docpub', b => 'lco'));
	}
	Q_25: {
		last unless $r->check('089','b','B21')
			|| $r->check('191','a','*/NGO/*');
		$r->add_field($make->(a => 'docpub', b => 'nws'));
	}
	Q_26: {
		last unless $r->check('191','a','*/PET/*');
		$r->add_field($make->(a => 'docpub', b => 'pet'));
	}	
	Q_27: {
		last unless $r->check('089','b','B24');
		$r->add_field($make->(a => 'docpub', b => 'cor'));
	}	
	Q_28: {
		last unless ! $r->has_tag('989');
		$r->add_field($make->(a => 'docpub'));
	}
	
	die "no criteria met to make 989 in bib# ".$r->id unless $r->has_tag('989');
}

1;