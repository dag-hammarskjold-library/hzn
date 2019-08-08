package MARC::Subfield;
use Alpha;

has 'place', is => 'rw';
has 'code', is => 'rw', param => 0;
has 'value', is => 'rw', param => 0;
has 'val', is => 'alias', target => 'value', param => 0;
has 'xref', is => 'rw', param => 0;
