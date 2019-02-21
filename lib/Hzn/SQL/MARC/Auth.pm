use v5.10;

package Hzn::SQL::MARC::Auth;
use Moo;
extends 'Hzn::SQL::MARC';

has 'statement' => (
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		my $criteria = $self->criteria;
		return qq {
			select 
				a.auth#,  
				a.tag,
				a.indicators,
				aa.indicators as auth_inds,
				str_replace (
					str_replace(
						a.text+aa.text+convert(varchar(8000),al.longtext)+convert(varchar(8000),al2.longtext), 	
						char(10), 
						"" 
					),
					char(13),
					""
				) as text,
				a.cat_link_xref#,
				a.tagord
			from 
				auth a, 
				auth aa,
				auth_longtext al,
				auth_longtext al2
			where 
				a.auth# in ( $criteria )
				and a.cat_link_xref# *= aa.auth#
				and aa.tag like "1%"
				and a.auth# *= al.auth#
				and a.tag *= al.tag
				and a.tagord *= al.tagord
				and aa.auth# *= al2.auth#
				and aa.tagord *= al2.tagord
				order by a.auth#, a.tag, a.tagord
		};
	}
);

package Hzn::SQL::MARC::Auth::Alt;
use Moo;
extends 'Hzn::SQL::MARC';

has 'statement' => (
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		my $criteria = $self->criteria;
		return qq {
			select 
				a.auth#,  
				a.tag,
				a.indicators,
				aa.indicators as auth_inds,
				str_replace (
					str_replace(
						a.text + convert(varchar(8000),al.longtext), 	
						char(10), 
						"" 
					),
					char(13),
					""
				) as text,
				str_replace (
					str_replace(
						aa.text + convert(varchar(8000),al2.longtext), 	
						char(10), 
						"" 
					),
					char(13),
					""
				) as auth_text,
				a.cat_link_xref#,
				a.tagord
			from 
				auth a, 
				auth aa,
				auth_longtext al,
				auth_longtext al2
			where 
				a.auth# in ( $criteria )
				and a.cat_link_xref# *= aa.auth#
				and aa.tag like "1%"
				and a.auth# *= al.auth#
				and a.tag *= al.tag
				and a.tagord *= al.tagord
				and aa.auth# *= al2.auth#
				and aa.tagord *= al2.tagord
				order by a.auth#, a.tag, a.tagord
		};
	}
);

1;