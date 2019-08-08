use strict;
use warnings;
use feature 'say';

package MARC::Field;
use Data::Dumper;
use Carp qw/confess carp cluck/;
use List::Util qw/first any/;
use Alpha;

has 'is_leader' => (
	is => 'ro',
	default => sub {
		my ($self,$att) = @_;
		$self->tag || confess 'tag must be set to determine if leader';
		return $self->{tag} eq '000' ? 1 : 0;
	}
);
has 'is_controlfield' => (
	is => 'ro',
	default => sub {
		my ($self,$att) = @_;
		$self->tag || confess 'tag must be set to determine if controlfield';
		return substr($self->{tag},0,2) eq '00' ? 1 : 0;
	}
);
has 'is_datafield' => (
	is => 'ro',
	default => sub {
		my ($self,$att) = @_;
		$self->tag || confess 'tag must be set to determine if datafield';
		return 1 if $self->tag =~ /^[A-Z]{3}$/; # exception for FFT
		return substr($self->{tag},0,2) eq '00' ? 0 : 1;
	}
);
has 'is_header' => (
	is => 'ro',
	default => sub {
		my ($self,$att) = @_;
		$self->tag || confess 'tag must be set to determine if header field';
		return substr($self->{tag},0,1) eq '1' ? 1 : 0;
	}
);
has 'is_overwritable' => (
	is => 'rw',
);
has 'place' => (
	is => 'rw'
);
has 'is_authority_controlled' => (
	is => 'rw',
);
has 'authority_controlled_subfields' => (
	is => 'rw',
	default => []
);
has 'delimiter' => (
	is => 'rw',
	param => 0,
	default => "\x{1F}"
);
has 'delim' => (
	is => 'alias',
	method => 'delimiter',
	param => 0
);
has 'padder' => (
	is => 'rw',
	default => sub {''}
);
has 'trailer' => (
	is => 'rw',
	default => sub {''}
);
has 'terminator' => (
	is => 'rw',
	default => "\x{1E}"
);
has 'tag' => (
	is => 'rw',
	param => 0
);
has 'indicators' => (
	is => 'rw',
	param => 0,
	default => sub {
		my ($self,$att) = @_;
		return '' unless $self->is_datafield;
		
		my $return = '  ';
		substr($return,0,1) = $self->ind1 if $self->ind1;
		substr($return,1,1) = $self->ind2 if $self->ind2;
		
		return $return;
	},
	trigger => sub {
		my ($self,$val) = @_;
		return unless $self->is_datafield;
		my $att = \$self->{indicators};
		
		#$val =~ s/ /_/g;  
		$val .= ' ' while length $val < 2;
		($self->{ind1},$self->{ind2}) = map {substr($val,$_,1)} (0,1);
		$$att = $val;
	
		return $$att;
	}
);
has 'inds' => (
	is => 'alias',
	param => 0,
	method => 'indicators'
);
has 'ind1' => (
	is => 'rw',
	param => 0,
	trigger => sub {
		my ($self,$val) = @_;
		my $att = \$self->{ind1};
		return $self->_ind_x($att,1,$val);
	}
);
has 'ind2' => (
	is => 'rw',
	param => 0,
	trigger => sub {
		my ($self,$val) = @_;
		my $att = \$self->{ind2};
		return $self->_ind_x($att,2,$val);
	}
);
has 'auth_indicators' => (
	is => 'rw',
	param => 0
);
has 'text' => (
	is => 'rw',
	param => 0,
	default => sub {
		my $self = shift;
		$self->_build_text;
		return $self->{text};
	},
	trigger => sub {
		my ($self,$val) = @_;
		my $att = \$self->{text};
		if (defined $val) {
			#chop $val if $$att && substr($$att,-1) eq $self->terminator;
			chop $val if substr($val,-1) eq $self->terminator;
			$$att = $val;
			$self->_parse_text;
		}
		$$att //= '';
		#$$att .= $self->terminator if substr($$att,-1) ne $self->terminator; # ?
		return $$att;
	}
);
has 'auth_text' => (
	is => 'rw',
	param => 0,
	trigger => sub {
		my ($self,$val) = @_;
		$self->{auth_text} = $val;
		$self->_parse_auth_text;
		return $self->{auth_text};
	}
);
has 'chars' => (
	is => 'method',
	code => sub {
		my $self = shift;
		my $text = $self->text;
		return if ! $text;
		my $term = $self->terminator;
		$text =~ s/$term$//;
		return $text;
	}	
);
has 'xref' => (
	is => 'rw',
	param => 0,
	trigger => sub {
		my ($self,$val) = @_;
		$self->set_subfield('0',$val,replace => 1) if $val;
		return $val;
	}
);
has 'position' => (
	is => 'method',
	code => sub {
		my $self = shift;
		return substr $self->text,$_[0],1 if scalar(@_) == 1;
		my %params = @_;
		my ($val,$pos,$len) = @params{qw/value start length/};
		confess 'method "position" only available for leader and controlfields' unless $self->is_leader or $self->is_controlfield;
		my $text = \$self->{text};
		$$text ||= '';
		if ($val) {
			confess 'named argument "start" required for method "position"' unless defined $pos;
			$len ||= length $val;
			$$text .= '|' while length $$text < ($pos + $len);
			substr($$text,$pos,$len) = $val;
		}
		if ($len) {
			$$text .= '|' while length($$text) < ($pos + $len);
			return substr $self->text,$pos,$len;
		} elsif (my $text = $self->text) {
			return substr $text,$pos;
		} else {
			return;
		}
	}
);
has 'field_length' => (
	is => 'method',
	code => sub {
		my ($self,$return) = @_;
		if ($self->is_datafield) {
			$return += length($self->$_) for (qw/text ind1 ind2/);
		} else {
			$return = length($self->text);
		}
		$return;
	}
);
has 'change_tag' => (
	is => 'method',
	code => sub {
		my ($self,$to_tag) = @_;
		$self->tag($to_tag);
		undef $self->{'is_'.$_} for qw/leader controlfield datafield header/;
		return $self;
	}
);
has 'check' => (
	is => 'method',
	code => sub {
		my ($self,$sub,$match) = @_;
		my $type = ref $match;
		my $subs;
		$sub = undef if $sub eq '*';
		for my $val ($self->list_subfield_values($sub)) {
			if ($type eq 'Regexp') {
				return 1 if $val =~ /$match/i;
			} elsif (index '*', $type > -1) {
				$match =~ s/\*{2,}/\*/g;
				my @parts = map {"\Q$_\E"} split /\*/, $match;
				my $rx = join '.*?', @parts;
				substr($match,0,1) ne '*' && ($rx = '^'.$rx);
				substr($match,-1) ne '*' && ($rx .= '$');
				my $check = qr/$rx/i;
				return 1 if $val =~ /$check/;
			} else {
				return 1 if $val eq $match;
			}
		}
		return 0;
	}
);

has 'subfield_order' => (
	is => 'method',
	code => sub {
		my $self = shift;
		return map {$_->code} $self->subfields;
	}
);
has 'set_subfield' => (
	is => 'method',
	code => sub {
		my ($self,$code,$val,%params) = @_;
		return unless defined $val;
		if ($params{replace} && any {$_->code eq $code} $self->subfields) {
			$_ ->value($val) for first {$_} grep {$_->code eq $code} $self->subfields;
		} else {
			my $sub = MARC::Subfield->new(code => $code, value => $val);
			$sub->place(scalar(grep {$_->{code} eq $code} @{$self->subfields}) + 1);
			push @{$self->{subfields}}, $sub;
			$self->xref($val) if $code eq '0';
		}
		$self->_build_text;
		return $self;
	}
);
has 'set_sub' => (
	is => 'alias',
	method => 'set_subfield'
);
has 'subfield_count' => (
	is => 'method',
	code => sub {
		my ($self,$sub) = @_;
		return scalar @{$self->get_subs($sub)};
	}
);
has 'set_auth_subfield' => (
	is => 'method',
	code => sub {
		my ($self,$code,$val,%params) = @_;
		return unless defined $val;
		confess 'xref must be set before auth_text' unless $self->xref;
		if ($params{replace} && any {$_->code eq $code} $self->subfields) {
			$_ ->value($val) for first {$_} grep {$_->code eq $code} $self->subfields;
		} else {
			my $sub = MARC::Subfield->new(code => $code, xref => $self->xref);
			push @{$self->{auth_subfields}}, $sub;
		}
		return $self;
	}
);
has 'get_values' => (
	is => 'method',
	code => sub {
		my $self = shift;
		my @codes = @_;
		return $self->text if $self->is_controlfield;
		return map {$_->value} $self->subfields if ! @codes;
		my @return;
		for my $sub ($self->subfields) {
			push @return, $sub->value if any {$sub->code eq $_} @codes;
		}
		return wantarray ? @return : $return[0];
	}
);
has 'get_value' => (
	is => 'alias',
	method => 'get_values'
);
has 'subfield' => (
	is => 'method',
	code => sub {
		my ($self,$sub,$val) = @_; 
		$self->set_subfield($sub,$val) and return $self if $val;
		return $self->get_subfield($sub);
	}
);
has 'sub' => (
	is => 'alias',
	method => 'subfield'
);
has 'get_subfield' => (
	is => 'method',
	code => sub {
		my ($self,$code,$incidence) = @_;
		my @vals = $self->get_subs($code);
		#return '' unless $vals;
		return '' if scalar @vals == 0;
		if ($incidence) {
			(return wantarray ? @vals : \@vals) if $incidence eq '*';
			return $vals[$incidence+1] if $incidence >= 0;
		}
		return $vals[0];
	}
);
has 'get_sub' => (
	is => 'alias',
	method => 'get_subfield'
);
has 'get_subfields' => (
	is => 'method',
	code => sub {
		my ($self,$code) = @_;
		#return $self->text if $self->is_controlfield;
		return $self->list_subfield_values unless defined $code;
		my @vals = map {$_->value} grep {$code eq $_->code} grep {defined} @{$self->{subfields}};		
		return @vals;
	}
);
has 'get_subs' => (
	is => 'alias',
	method => 'get_subfields'
);
has 'subfields' => (
	is => 'method',
	code => sub {
		my $self = shift;
		my @return = grep {defined} @{$self->{subfields}}; 
		return wantarray ? @return : \@return;
	},
);
has 'auth_subfields' => (
	is => 'method',
	code => sub {
		my $self = shift;
		my @return = grep {defined} @{$self->{auth_subfields}}; 
		return wantarray ? @return : \@return;
	},
);
has 'list_subfield_values' => (
	is => 'method',
	code => sub {
		my ($self,@codes) = @_;
		if (@codes > 0) {
			my @return;
			for my $code (@codes) {
				push @return, map {$_} $self->get_subs($code);
			}
			return @return;
		} else {
			return map {$_->value} $self->subfields;
		}
	}
);
has 'delete_subfield' => (
	is => 'method',
	code => sub {
		my ($self,@codes) = @_;
		$self->xref('') if any {$_ eq '0'} @codes;
		for my $code (@codes) {
			@{$self->{subfields}} = grep {$_->code ne $code} @{$self->{subfields}};
		}
		$self->{xref} = undef if any {$_ eq '0'} @codes;
		$self->_build_text;
		return $self;
	}
);

sub _ind_x {
	my ($self,$ref,$ind,$val) = @_;
	
	my $pos = $ind - 1;
	my $att = $ref;
	my $inds = \$self->{indicators};
	if (defined $val) {
		#$self->_validate_input('ind'.$ind,$val);
		$$inds //= '';
		$$inds .= ' ' while length $$inds < 2;
		substr($$inds,$pos,1) = $val;
		$$att = $val; # if defined $val;
	}
	return $$att if $$att;
	
	if ($$inds) {
		$$att = substr $$inds,$pos,1;
	} else {
		$$att = ' ';
	}	
	return $$att;
}

# handle concatenated auth text that causes subfields to be out of order:
# replace empty subfields with next found instance of subfield
sub _normalize_subfield_order {
	my $self = shift;
	my ($d,$t) = ($self->delimiter,$self->terminator);
	my @blanks = ($self->{text} =~ m/($d.)(?=$d)/g);
	for my $sub (@blanks) {
		$self->{text} =~ s/$sub(.*?)($sub[^$d$t]+)/$2$1/;	
	}
}

sub _parse_text {
	my $self = shift;
	
	confess 'must set tag before parsing text' unless defined $self->tag;
	my ($d,$t) = ($self->delimiter,$self->terminator);
	return unless $self->is_datafield;
	chop $self->{text} if substr($self->{text},-1) eq $t;
	$self->_normalize_subfield_order;
	
	return unless $self->{text};
	#confess 'no delim' unless index($self->{text},$d) > -1;
	return unless index($self->{text},$d) > -1;
	
	undef $self->{subfields};
	my (@subfields,$newtext);
	
	for (split /[\Q$d$t\E]/, $self->text) {
		my $sub = substr $_,0,1,'';
		next if ! $_;
		$self->set_subfield($sub,$_);
	}
}

sub _parse_auth_text {
	my $self = shift;
	
	my ($d,$t) = ($self->delimiter,$self->terminator);
	
	for (grep {$_} split /[\Q$d$t\E]/, $self->auth_text) {
		my $code = substr $_,0,1,'';
		my $val = $_ or next;
		$self->set_auth_subfield($code,$val);
	}
}

sub _build_text {
	my $self = shift;
	
	my $att = \$self->{text};	
	undef $$att;
	for (@{$self->subfields}) {
		$$att .= $self->delimiter.$_->code.$self->padder.$_->value.$self->trailer;
	}
	#$$att .= $self->terminator if $$att;
}

my $debug = <<'#';
package main;
use MARC;
use Get::Hzn;

Get::Hzn::Dump::Bib->new->iterate (
	criteria => 'select bib# from bib_control where bib# between 100000 and 100100',
	callback => sub {
		my $r = shift;
		say $r->id;
	}
);

#

package end;

1

__END__