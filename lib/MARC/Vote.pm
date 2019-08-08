use v5.10;
use strict;
use warnings;

package Voting::Vote;
use Moo;

has 'member' => (is => 'rw');
has 'vote' => (is => 'rw'); 

package Voting::Results;
use Moo;
use List::Util qw|sum|;

has 'Y' => (is => 'rw', default => 0);
has 'N' => (is => 'rw', default => 0);
has 'A' => (is => 'rw', default => 0);
has 'X' => (is => 'rw', default => 0);

sub total {
	my $self = shift;
	return sum map {$self->$_ || 0} qw|Y N A X|;
}

sub string {
	my $self = shift;
	return 'ADOPTED WITHOUT VOTE' unless $self->total;
	return join('-', map {$self->$_ || 0} qw|Y N A total|);
}

package Voting::Resolution;
use Moo;
use Data::Dumper;
use Carp qw|cluck|;
use List::Util qw|none|;

has 'votes' => (is => 'rw', default => sub {[]});
has 'results' => (is => 'rw', default => sub {Voting::Results->new});
has 'symbol' => (is => 'rw');
has 'body' => (
	is => 'rw',
	#trigger => sub {
	#	my ($self,$val) = @_;
	#	chop $val if $val && substr($val,-1) eq '/';
	#	return $val;
	#}
);
has	'session' => (is => 'rw');
has	'id' => (is => 'rw');
has 'title' => (is => 'rw');
has 'meeting_symbol' => (is => 'rw');
has 'draft_symbol' => (is => 'rw');
has 'report_symbol' => (is => 'rw');
has	'date' => (
	is => 'rw',
	trigger => sub {
		my ($self,$val) = @_;
		return unless $val;
		$val =~ s/^(\d{4})(\d{2})(\d{2})$/$1-$2-$3/;
		$self->{date} = $val;
	}
);

sub results_string {
	my $self = shift;
	return $self->results->string;
}

sub count{results_string(@_)}

sub add_vote {
	my ($self,$member,$vote) = @_;
	if ($vote) {
		$vote =~ s/\s+$//;
		$vote = uc $vote;
	} 
	$vote ||= 'X';
	cluck "invalid vote: '$vote'\n" if none {$_ eq $vote} qw|Y N A X|;
	push @{$self->{votes}}, Voting::Vote->new(member => $member, vote => $vote);
	$self->results->{$vote}++;
}

sub get_vote {
	my ($self,$country) = @_;
	for (@{$self->votes}) {
		$_->member eq $country && return $_->vote;
	}
}

sub import_marc {
	my ($self,$r) = @_;
	die "import must be a MARC::Record\n" if ref $r ne 'MARC::Record';
	if (my $f = $r->get_field('791')) {
		$self->symbol($f->get_sub('a'));
		$self->body($f->get_sub('b'));
		$self->session($f->get_sub('c'));
	}
	if (my $f = $r->get_field('245')) {
		#$self->title(join ' ', $f->list_subfield_values(qw|a b c|));
		$self->title($f->get_sub('a') =~ s/ :$//r);
	}
	if (my $val = $r->get_value('269','a')) {
		$self->date($val);
	}
	if (my $val = $r->get_value('952','a')) {
		$self->meeting_symbol($val);
	}
	if (my $val = $r->get_value('993','a')) {
		$self->draft_symbol($val);
	}
	for my $f ($r->fields(qw|967 968 969|)) {
		$self->add_vote($f->get_sub('e'), $f->get_sub('d'));
	}
}

sub to_marc {
	my $self = shift;
	require MARC;
	
}

package Voting::Batch;
use Moo;
use List::Util; # qw|uniq|;
use JSON::XS;
use Data::Dumper;

has 'resolutions' => (is => 'ro');

sub add_resolution {
	my ($self,$res) = @_;
	push @{$self->{resolutions}}, $res;
}

sub to_tsv {
	my ($self,%p) = @_;
	my $h; {
		$p{path} ? open($h,'>',$p{path}) : ($h = *STDOUT);
	}
	my @inits = qw (
		symbol
		date
		title
		count
	);
	my %seen;
	$seen{$_} = 1 for map {$_->member} map {@{$_->votes}} @{$self->resolutions};
	push my @header, @inits, sort keys %seen;
	say {$h} join "\t", @header;
	for my $res (@{$self->resolutions}) {
		my @row = map {$res->$_} @inits;
		for my $i (@row..$#header) {
			my $member = $header[$i];
			my $vote = $res->get_vote($member) || '';
			push @row, $vote;
		}
		
		say {$h} join "\t", @row;
	}
}

sub to_json {
	my $self = shift;
	my %params = @_;
	my @objs;
	for my $res (@{$self->resolutions}) {
		# ... 
		#push @objs, $obj; 
	}
	my $j = JSON->new;
	$j->pretty(1) if $params{pretty};
	return $j->encode(\@objs);
}

sub uniq {
	my %seen;
	$seen{$_} ||= 1 for @_;
	return keys %seen;
}

# my $test = <<'#';
package main;
use Get::Hzn;
use Data::Dumper;

my $b = Voting::Batch->new;

Get::Hzn::Dump::Bib->new->iterate (
	criteria => $ARGV[0],
	callback => sub {
		my $r = shift;
		my $res = Voting::Resolution->new;
		$res->import_marc($r);
		$b->add_resolution($res);
	}
);

$|++;
$b->to_tsv(path => $ARGV[1]);

#


1;