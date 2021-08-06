use v5.10;

package Hzn::SQL::MARC::Bib;
use Moo;
extends 'Hzn::SQL::MARC';

has 'statement' => (
	is => 'rw',
	lazy => 1,
	builder => sub {
		my $self = shift;
		my $criteria = $self->criteria;
		return qq {
			select 
				b.bib#,  
				b.tag,
				b.indicators,
				a.indicators as auth_inds,
				str_replace (
					str_replace ( 
						b.text + convert(varchar(8000),bl.longtext), 
						char(10), 
						"" 
					),
					char(13),
					""
				) as text,
				str_replace (	
					str_replace ( 
						a.text + convert(varchar(8000),al.longtext),
						char(10),
						""
					),
					char(13),
					""
				) as auth_text,
				b.cat_link_xref#,
				b.tagord
			from 
				bib b, 
				auth a, 
				bib_longtext bl, 
				auth_longtext al
			where 
				b.bib# in ( $criteria )		
				and b.cat_link_xref# *= a.auth#
				and a.tag like "1%"
				and b.bib# *= bl.bib#
				and b.tag *= bl.tag
				and b.tagord *= bl.tagord
				and a.auth# *= al.auth#
				and a.tagord *= al.tagord
				order by b.bib#, b.tag, b.tagord
		};
	}
);

1;
