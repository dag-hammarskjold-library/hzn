use v5.10;
use strict;
use warnings;

package Hzn::Export::Util::Map::Bib::DLX::Body;
use Moo;
use List::Util qw<pairs>;
use Data::Dumper;

use constant FILE => <<'EOF';
Economic and Social Council			191__b:"E/*" OR 791__b:"E*" AND NOT 980:"AUTHORITY"
General Assembly	General Assembly Plenary		symbol:/^A\/([1-9]|DEC|RES|BUR|PV|INF|SR|ES-|S-)/ AND NOT 980:"AUTHORITY"
General Assembly	1st Committee		710:/UN\. General Assembly.*(1st|First) Committee/ OR symbol:/A\/C\.1\// AND NOT 980:"AUTHORITY"
General Assembly	2nd Committee		710:/UN\. General Assembly.*(2nd|Second) Committee/ OR symbol:/A\/C\.2\// AND NOT 980:"AUTHORITY"
General Assembly	3rd Committee		710:/UN\. General Assembly.*(3rd|Third) Committee/ OR symbol:/A\/C\.3\// AND NOT 980:"AUTHORITY"
General Assembly	4th Committee		symbol:/A\/(C\.4|SPC)\// OR 710:/UN\. General Assembly.*(4th|Fourth|Special.?Political.*) Committee/ AND NOT 980:"AUTHORITY"
General Assembly	5th Committee		 710:/UN\. General Assembly.*(5th|Fifth) Committee/ OR symbol:/A\/C\.5\// AND NOT 980:"AUTHORITY"
General Assembly	6th Committee		 710:/UN\. General Assembly.*(6th|Sixth) Committee/ OR symbol:/A\/C\.6\// AND NOT 980:"AUTHORITY"
General Assembly	Human Rights Council		191__b:"A/HRC/*" OR 710:"UN. Human Rights Council*" AND NOT 980:"AUTHORITY"
General Assembly	Subsidiary Bodies		191__a:/A\/(AB|AC|CONF|CR|COPUOS|Executive|HQC|ICH|LA|LN|NC|SEC|SITE|UNRRA|WGAP|WGFS|WGUNS)/ AND NOT 980:"AUTHORITY"
International Court of Justice			191__b:"ICJ/*" OR 710:"ICJ*" AND NOT 980:"AUTHORITY"
Secretariat			191__b:"ST/*" AND NOT 980:"AUTHORITY"
Security Council			191__b:"S/*" OR 791__b:"S*" AND NOT 980:"AUTHORITY"
Trusteeship Council			191__b:"T/*" OR 791__b:"T*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Office of the High Commissioner for Human Rights		191__b:"ST/HR*" OR 710:"UN. Office of the High Commissioner for Human Rights*" OR 710:"UN High Commissioner for Human Rights*" OR 710:"UN. Centre for Human Rights*" OR 710:"UN. Division of Human Rights*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Charter-Based Human Rights Bodies	Human Rights Council	191__b:"A/HRC/*" OR 710:"UN. Human Rights Council*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Charter-Based Human Rights Bodies	Commission on Human Rights	191__b:"E/CN.4/*" OR 710:"UN. Commission on Human Rights*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Human Rights Committee	191__b:"CCPR/*" OR 710:"Human Rights Committee*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on Economic, Social and Cultural Rights	191__b:"E/C.12/*" OR 710:"UN. Committee on Economic, Social and Cultural Rights*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Elimination of Racial Discrimination	191__b:"CERD/*" OR 710:"UN. Committee on the Elimination of Racial Discrimination*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Elimination of Discrimination against Women	191__b:"CEDAW/*" OR 710:"UN. Committee on the Elimination of Discrimination against Women*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee against Torture	191__b:"CAT/*" OR 710:"UN. Committee against Torture*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Rights of the Child	191__b:"CRC/*" OR 710:"UN. Committee on the Rights of the Child*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Protection of the Rights of All Migrant Workers and Members of Their Families	191__b:"CMW/*" OR 710:"UN. Committee on the Protection of the Rights of All Migrant Workers and Members of Their Families*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Rights of Persons with Disabilities	191__b:"CRPD/*" OR 710:"UN. Committee on the Rights of Persons with Disabilities*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on Enforced Disappearances	191__b:"CED/*" OR 710:"UN. Committee on Enforced Disappearances*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Human Rights Instruments	191__b:"HRI/*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic Commission for Africa		191__b:"E/ECA/*" OR 191__b:"ST/ECA/*" OR 710:"UN.ECA*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic Commission for Europe		191__b:"E/ECE/*" OR 191__b:"ST/ECE/*" OR 710:"UN.ECE*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic Commission for Latin America and the Caribbean (ECLAC)		191__b:"E/CN.12/*" OR 191__b:"ST/ECLA/*" OR 191__b:"ST/ECLAC/*" OR 191__b:"E/ECLAC*" OR 191__b:"E/LC*" OR 191__b:"E/CEPAL*" OR 710:"UN. CEPAL*" OR 710:"UN. ECLAC*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic and Social Commission for Western Asia		191__b:"E/ESCWA/*" OR 191__b:"ST/ESCWA/*" OR 191__b:"E/ECWA/*" OR 191__b:"ST/ECWA/*" OR 191__b:"WAW/*" OR 191__b:"ESOB/*" OR 191__b:"ST/UNESOB*" OR 710:"UN. ESCWA*" OR 710:"UN. ECWA*" OR 710:"UN Economic and Social Office in Beirut*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic and Social Commission for Asia and the Pacific		191__b:"E/CN.11/" OR 191__b:"E/ESCAP/*" OR 191__b:"ST/ESCAP/*" OR 191__b:"ST/ECAFE/*" OR 191__b:"ECAFE/*" OR 710:"UN. ESCAP*" OR 710:"UN. ECAFE*" AND NOT 980:"AUTHORITY"
Programmes and Funds	Development Programme (UNDP)		191__b:/^(UNDP|DP)/ OR 710:"UNDP*" AND NOT 980:"AUTHORITY"
Programmes and Funds	Environment Programme (UNEP)		191__b:"UNEP/*" OR 710:"UNEP*" AND NOT 980:"AUTHORITY"
Programmes and Funds	Population Fund (UNFPA)		191__b:"FPA/*" OR 710:"UNFPA*" AND NOT 980:"AUTHORITY"
Programmes and Funds	International Children's Emergency Fund (UNICEF)		191__b:"E/ICEF/*" OR 710:"UNICEF*" AND NOT 980:"AUTHORITY"
Programmes and Funds	United Nations Human Settlements Programme (UN-Habitat)		191__b:"HS/*" OR 710:"UN-HABITAT*" AND NOT 980:"AUTHORITY"
Programmes and Funds	World Food Program (WFP)		191__b:"WFP/*" OR 710:"World Food Programme*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Institute for Disarmament Research (UNIDIR)		191__b:"UNIDIR/*" OR 710:"UN Institute for Disarmament Research*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Interregional Crime and Justice Research Institute (UNICRI)		191__b:"UNICRI/*" OR 710:"UN Interregional Crime and Justice Research Institute*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Institute for Training and Research (UNITAR)		191__b:"UNITAR/*" OR 710:"UNITAR*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Research Institute for Social Development (UNRISD)		191__b:"UNRISD/*" OR 710:"UN Research Institute for Social Development*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	UN System Staff College (UNSSC)		191__b:"UNSSC/*" OR 710:"UN System Staff College*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	United Nations University (UNU)		191__b:"UNU/*" OR 710:"UN University*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Peacebuidling Commission		191__b:"PBC/*" OR 710__a:"UN. Peacebuilding Commission*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Conference on Trade and Development (UNCTAD)		191__b:"TD/*" OR 710:"UNCTAD*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Office for Project Services (UNOPS)		191__b:"OPS/*" OR 710:"UNOPS*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Relief and Works Agency for Palestine Refugees in the Near East (UNRWA)		191__b:"UNRWA/*" OR 710:"UNRWA*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Entity for Gender Equality and the Empowerment of Women (UN Women)		191__b:"UNW/*" OR 191__b:"UNIFEM/*" OR 191__b:"CEDAW/*" OR 191__b:"ST/DESA/DAW/*" OR 191__b:"INSTRAW/*" OR 710:"UN-Women*"  OR 710:"UN. International Research and Training Institute for the Advancement of Women*"  OR 710:"UN Development Fund for Women*"  OR 710:"UN. Office of the Special Adviser on Gender Issues and Advancement of Women*"  OR 710:"UN. Division for the Advancement of Women*"  OR 710:"UN. Office on Gender Equality and Advancement of Women*" AND NOT 980:"AUTHORITY"
EOF

has data => (
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		for (split /[\r\n]+/, FILE) {
			my @row = split("\t",$_);
			
			my %vals;
			@vals{qw<a b c>} = @row[0..2];
			my @vals = map {$_, $vals{$_}} sort grep {$vals{$_}} keys %vals; # or next;
			
			my $match_str = $row[3];
			$match_str =~ s/ AND.*//;
			my @conds = split ' OR ', $match_str;
			for (grep {ref $_ ne 'ARRAY'} @conds) {
				my ($tag,$sub,$match) = ($1,$3,$4) if /(\d+|symbol)(__)?([a-z])?\:(.*)/;
				
				chop $match;
				if (substr($match,0,1,'') eq '/') {
					$match = qr/$match/;
				} 
				if ($tag eq 'symbol') {
					$tag = '191';
					$sub = 'a';
					push @conds, ['791',$sub,$match];
				}
				$sub //= '*';
				$_ = [$tag,$sub,$match];
			}
			push @{$self->{data}}, [\@vals, @conds];
		}
		return $self->{data};
	}
);

sub map {
	my ($self,$record) = @_;
	
	my $flag;
	for my $d (@{$self->data}) {
		if (_process($record,@$d)) {
			$flag++;
		}
	}
	return $flag;
}

sub _process {
	my $r = shift;
	my $vals = shift;
	for (@_) {
		my ($tag,$sub,$matcher) = @$_;
		if ($r->check($tag,$sub,$matcher)) {
			_make($r,@$vals);
			return 1;
		}
	}
}

sub _make {
	my $r = shift;
	my $f = MARC::Field->new(tag => '981');
	$f->set_sub($_->key,$_->value) for pairs @_;
	$r->add_field($f);
}

1;

###

__DATA__
Economic and Social Council			191__b:"E/*" OR 791__b:"E*" AND NOT 980:"AUTHORITY"
General Assembly	General Assembly Plenary		symbol:/^A\/([1-9]|DEC|RES|BUR|PV|INF|SR|ES-|S-)/ AND NOT 980:"AUTHORITY"
General Assembly	1st Committee		710:/UN\. General Assembly.*(1st|First) Committee/ OR symbol:/A\/C\.1\// AND NOT 980:"AUTHORITY"
General Assembly	2nd Committee		710:/UN\. General Assembly.*(2nd|Second) Committee/ OR symbol:/A\/C\.2\// AND NOT 980:"AUTHORITY"
General Assembly	3rd Committee		710:/UN\. General Assembly.*(3rd|Third) Committee/ OR symbol:/A\/C\.3\// AND NOT 980:"AUTHORITY"
General Assembly	4th Committee		symbol:/A\/(C\.4|SPC)\// OR 710:/UN\. General Assembly.*(4th|Fourth|Special.?Political.*) Committee/ AND NOT 980:"AUTHORITY"
General Assembly	5th Committee		 710:/UN\. General Assembly.*(5th|Fifth) Committee/ OR symbol:/A\/C\.5\// AND NOT 980:"AUTHORITY"
General Assembly	6th Committee		 710:/UN\. General Assembly.*(6th|Sixth) Committee/ OR symbol:/A\/C\.6\// AND NOT 980:"AUTHORITY"
General Assembly	Human Rights Council		191__b:"A/HRC/*" OR 710:"UN. Human Rights Council*" AND NOT 980:"AUTHORITY"
General Assembly	Subsidiary Bodies		191__a:/A\/(AB|AC|CONF|CR|COPUOS|Executive|HQC|ICH|LA|LN|NC|SEC|SITE|UNRRA|WGAP|WGFS|WGUNS)/ AND NOT 980:"AUTHORITY"
International Court of Justice			191__b:"ICJ/*" OR 710:"ICJ*" AND NOT 980:"AUTHORITY"
Secretariat			191__b:"ST/*" AND NOT 980:"AUTHORITY"
Security Council			191__b:"S/*" OR 791__b:"S*" AND NOT 980:"AUTHORITY"
Trusteeship Council			191__b:"T/*" OR 791__b:"T*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Office of the High Commissioner for Human Rights		191__b:"ST/HR*" OR 710:"UN. Office of the High Commissioner for Human Rights*" OR 710:"UN High Commissioner for Human Rights*" OR 710:"UN. Centre for Human Rights*" OR 710:"UN. Division of Human Rights*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Charter-Based Human Rights Bodies	Human Rights Council	191__b:"A/HRC/*" OR 710:"UN. Human Rights Council*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Charter-Based Human Rights Bodies	Commission on Human Rights	191__b:"E/CN.4/*" OR 710:"UN. Commission on Human Rights*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Human Rights Committee	191__b:"CCPR/*" OR 710:"Human Rights Committee*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on Economic, Social and Cultural Rights	191__b:"E/C.12/*" OR 710:"UN. Committee on Economic, Social and Cultural Rights*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Elimination of Racial Discrimination	191__b:"CERD/*" OR 710:"UN. Committee on the Elimination of Racial Discrimination*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Elimination of Discrimination against Women	191__b:"CEDAW/*" OR 710:"UN. Committee on the Elimination of Discrimination against Women*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee against Torture	191__b:"CAT/*" OR 710:"UN. Committee against Torture*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Rights of the Child	191__b:"CRC/*" OR 710:"UN. Committee on the Rights of the Child*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Protection of the Rights of All Migrant Workers and Members of Their Families	191__b:"CMW/*" OR 710:"UN. Committee on the Protection of the Rights of All Migrant Workers and Members of Their Families*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on the Rights of Persons with Disabilities	191__b:"CRPD/*" OR 710:"UN. Committee on the Rights of Persons with Disabilities*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Committee on Enforced Disappearances	191__b:"CED/*" OR 710:"UN. Committee on Enforced Disappearances*" AND NOT 980:"AUTHORITY"
Human Rights Bodies	Treaty-Based Human Rights Bodies	Human Rights Instruments	191__b:"HRI/*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic Commission for Africa		191__b:"E/ECA/*" OR 191__b:"ST/ECA/*" OR 710:"UN.ECA*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic Commission for Europe		191__b:"E/ECE/*" OR 191__b:"ST/ECE/*" OR 710:"UN.ECE*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic Commission for Latin America and the Caribbean (ECLAC)		191__b:"E/CN.12/*" OR 191__b:"ST/ECLA/*" OR 191__b:"ST/ECLAC/*" OR 191__b:"E/ECLAC*" OR 191__b:"E/LC*" OR 191__b:"E/CEPAL*" OR 710:"UN. CEPAL*" OR 710:"UN. ECLAC*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic and Social Commission for Western Asia		191__b:"E/ESCWA/*" OR 191__b:"ST/ESCWA/*" OR 191__b:"E/ECWA/*" OR 191__b:"ST/ECWA/*" OR 191__b:"WAW/*" OR 191__b:"ESOB/*" OR 191__b:"ST/UNESOB*" OR 710:"UN. ESCWA*" OR 710:"UN. ECWA*" OR 710:"UN Economic and Social Office in Beirut*" AND NOT 980:"AUTHORITY"
Economic Commissions	Economic and Social Commission for Asia and the Pacific		191__b:"E/CN.11/" OR 191__b:"E/ESCAP/*" OR 191__b:"ST/ESCAP/*" OR 191__b:"ST/ECAFE/*" OR 191__b:"ECAFE/*" OR 710:"UN. ESCAP*" OR 710:"UN. ECAFE*" AND NOT 980:"AUTHORITY"
Programmes and Funds	Development Programme (UNDP)		191__b:/^(UNDP|DP)/ OR 710:"UNDP*" AND NOT 980:"AUTHORITY"
Programmes and Funds	Environment Programme (UNEP)		191__b:"UNEP/*" OR 710:"UNEP*" AND NOT 980:"AUTHORITY"
Programmes and Funds	Population Fund (UNFPA)		191__b:"FPA/*" OR 710:"UNFPA*" AND NOT 980:"AUTHORITY"
Programmes and Funds	International Children's Emergency Fund (UNICEF)		191__b:"E/ICEF/*" OR 710:"UNICEF*" AND NOT 980:"AUTHORITY"
Programmes and Funds	United Nations Human Settlements Programme (UN-Habitat)		191__b:"HS/*" OR 710:"UN-HABITAT*" AND NOT 980:"AUTHORITY"
Programmes and Funds	World Food Program (WFP)		191__b:"WFP/*" OR 710:"World Food Programme*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Institute for Disarmament Research (UNIDIR)		191__b:"UNIDIR/*" OR 710:"UN Institute for Disarmament Research*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Interregional Crime and Justice Research Institute (UNICRI)		191__b:"UNICRI/*" OR 710:"UN Interregional Crime and Justice Research Institute*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Institute for Training and Research (UNITAR)		191__b:"UNITAR/*" OR 710:"UNITAR*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	Research Institute for Social Development (UNRISD)		191__b:"UNRISD/*" OR 710:"UN Research Institute for Social Development*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	UN System Staff College (UNSSC)		191__b:"UNSSC/*" OR 710:"UN System Staff College*" AND NOT 980:"AUTHORITY"
Research and Training Institutions	United Nations University (UNU)		191__b:"UNU/*" OR 710:"UN University*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Peacebuidling Commission		191__b:"PBC/*" OR 710__a:"UN. Peacebuilding Commission*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Conference on Trade and Development (UNCTAD)		191__b:"TD/*" OR 710:"UNCTAD*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Office for Project Services (UNOPS)		191__b:"OPS/*" OR 710:"UNOPS*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Relief and Works Agency for Palestine Refugees in the Near East (UNRWA)		191__b:"UNRWA/*" OR 710:"UNRWA*" AND NOT 980:"AUTHORITY"
Other UN Bodies and Entities	Entity for Gender Equality and the Empowerment of Women (UN Women)		191__b:"UNW/*" OR 191__b:"UNIFEM/*" OR 191__b:"CEDAW/*" OR 191__b:"ST/DESA/DAW/*" OR 191__b:"INSTRAW/*" OR 710:"UN-Women*"  OR 710:"UN. International Research and Training Institute for the Advancement of Women*"  OR 710:"UN Development Fund for Women*"  OR 710:"UN. Office of the Special Adviser on Gender Issues and Advancement of Women*"  OR 710:"UN. Division for the Advancement of Women*"  OR 710:"UN. Office on Gender Equality and Advancement of Women*" AND NOT 980:"AUTHORITY"