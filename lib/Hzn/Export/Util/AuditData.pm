use v5.10;
use strict;
use warnings;

package Hzn::Export::Util::AuditData;
use Moo;
use List::Util qw|any|;
use Get::Hzn;
use Utils qw|date_hzn_8601|;

has 'type' => (
	is => 'ro',
	required => 1, 
	#isa => sub {
	#	#die unless any {$_ eq $_[0]} qw|bib auth|;
	#}
);

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
	
	my $type = lc $self->type;
	my $filter;
	if ($self->has_filter) {
		$filter = ref $self->filter eq 'ARRAY' ? join ',', @{$self->filter} : $self->filter;
	}
	my $sql = <<"	#";
		select 
			$type\#, 
			create_date, 
			create_time,
			create_user,
			change_date,
			change_time,
			change_user
		from 
			$type\_control
	#
	$sql .= "where $type\# in ($filter)" if $filter; 
	my $get = Get::Hzn->new(sql =>$sql);
	$get->execute (
		callback => sub {
			my $row = shift;
			my ($id,$cr_date,$cr_time,$cr_user,$ch_date,$ch_time,$ch_user) = @$row;
			$self->{data}->{$id}->{create_user} = $cr_user;
			$self->{data}->{$id}->{create_date} = date_hzn_8601($cr_date,$cr_time);
			$self->{data}->{$id}->{change_user} = $ch_user;
			$self->{data}->{$id}->{change_date} = date_hzn_8601($ch_date,$ch_time);
		}
	);
}

sub to_marc {
	my ($self,$id) = @_;
	
	my %assign = (
		a => $self->create_date($id),
		b => $self->create_user($id),
		c => $self->change_date($id),
		d => $self->change_user($id),
	);
	
	my $f = MARC::Field->new(tag => '998');
	$f->set_sub($_,$assign{$_}) for grep {$assign{$_}} sort keys %assign;
	
	return $f;
}

sub create_user {
	my ($self,$id) = @_;
	return $self->{data}->{$id}->{create_user};
}

sub create_date {
	my ($self,$id) = @_;
	return $self->{data}->{$id}->{create_date};
}

sub change_user {
	my ($self,$id) = @_;
	return $self->{data}->{$id}->{change_user};
}

sub change_date {
	my ($self,$id) = @_;
	return $self->{data}->{$id}->{change_date};
}

1;

my $test = <<'#';

package main;
use Hzn::AuditData;
use Data::Dumper;

my $au = Hzn::AuditData->new(type => 'bib', filter => [50000..51000]);

say $au->create_date($_) for @{$au->ids};

#