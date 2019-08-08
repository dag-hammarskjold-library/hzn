package Hzn::Util::Exclude::Bib;
use Moo;
extends 'Hzn::Util::Exclude';

has 'type', is => 'ro', default => 'bib';

has 'sql' => ( 
	is => 'ro', 
	default => q {
		select bib# 
		from bib_control 
		where bib# not in (
			select bib# from bib where tag in ("191","791")
		) 
		and bib# not in (
			select bib# from bib where tag = "099" and text like "%bDHU%"
		)
	}
);

1;