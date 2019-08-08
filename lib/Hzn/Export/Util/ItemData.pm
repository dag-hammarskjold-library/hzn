use v5.10;
use strict;
use warnings;

package Hzn::Export::Util::ItemData;
use Moo;
use List::Util qw|any|;

use Hzn::Util::Date;

use constant FIELDS => [qw|call barcode item collection copy location status itype create_date|];

has filter => (
	is => 'rw', 
	predicate => 1, 
	isa => sub {
		die unless $_[0] =~ /^select/ || ref $_[0] eq 'ARRAY';
	}
);

has 'data', is => 'ro', default => sub {{}};

has 'ids' => (
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		return [keys %{$self->{data}}]
	}
);

sub BUILD {
	my $self = shift;
	$self->load;
}

sub load {
	my $self = shift;
	
	my $filter;
	if ($self->has_filter) {
		$filter = ref $self->filter eq 'ARRAY' ? join ',', @{$self->filter} : $self->filter;
	}
	my $sql = qq {
		select 
			bib#,
			call_reconstructed,
			str_replace(ibarcode,char(9),"") as barcode,
			item#,
			collection,
			copy_reconstructed,
			location,
			item_status,
			itype,
			creation_date 
		from 
			item 
		where 
			bib# in ($filter)
	};
	
	my $get = Hzn::SQL->new(statement =>$sql);
	$get->run (
		callback => sub {
			my $row = shift;
			my $bib = shift @$row;
			$row->[-1] = Hzn::Util::Date::hzn_8601($row->[-1]) if $row->[-1];
			$self->{data}->{$bib}->{places}++; 
			my $place = $self->{data}->{$bib}->{places};
			my %data;
			@data{@{&FIELDS}} = @$row;
			$self->{data}->{$bib}->{$place} = \%data;
		}
	);
}

sub to_marc {
	my ($self,$id) = @_;
	
	my @fields;
	
	for my $place (grep {$_ ne 'places'} keys %{$self->data->{$id}}) {
		my $field = MARC::Field->new(tag => '949');
		my @vals = @{ $self->data->{$id}->{$place} }{@{&FIELDS}};
		$field->set_sub($_,shift(@vals)) for qw/9 b i k c l z m d/;
		push @fields, $field;
	}
	
	return @fields;
}

1;

my $test = <<'#';

package main;
use Data::Dumper; 

my $it = Hzn::ItemData->new(filter => [50000..51000]);

print Dumper $it;

#