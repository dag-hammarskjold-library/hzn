use strict;
use warnings;
use feature 'say';

package MARC::Record;
use Alpha;
use Carp qw/croak cluck confess/;
use Data::Dumper;
use Scalar::Util 'refaddr';
use Tie::IxHash;
use List::Util qw<any>;

has 'directory', is => 'rw';
has 'field_terminator', is => 'rw', default => "\x{1E}";
has 'record_terminator', is => 'rw', default => "\x{1D}";
has 'type', is => 'rw';

template 'ctr', code => \&_controlfield_element;

has 'leader', is => 'ctr', tag => '000', from => 0, length => 24;
has 'record_status', is => 'ctr', tag => '000', from => 5, length => 1;
has 'encoding_level', is => 'ctr', tag => '000', from => 17, length => 1;
has 'descriptive_cataloging_form', is => 'ctr', tag => '000', from => 18, length => 1;
has 'id', is => 'alias', method => 'control_number', param => 0; 
has 'record_length', is => 'ctr', tag => '000', from => 0, length => 5;
has 'type_of_record', is => 'ctr', tag => '000', from => 6, length => 1;
has 'bibliographic_level', is => 'ctr', tag => '000', from => 7, length => 1;
has 'character_encoding_scheme', is => 'ctr', tag => '000', from => 9, length => 1;
has 'base_address_of_data', is => 'ctr', tag => '000', from => 12, length => 5;
has 'multipart_resource_record_level', is => 'ctr', tag => '000', from => 19, length => 1;

has 'control_number', is => 'ctr', tag => '001', from => 0, length => 'x';

has 'fixed_length_data_elements', is => 'ctr', tag => '008', from => 0, length => 40;
has 'date_entered_on_file', is => 'ctr', tag => '008', from => 0, length => 5;
has 'type_of_date_publication_status' => is => 'ctr', tag => '008', from => 6, length => 1;
has 'date_1', is => 'ctr', tag => '008', from => 7, length => 4;
has 'date_2', is => 'ctr', tag => '008', from => 11, length => 4;
has 'place_of_publication_production_or_execution', is => 'ctr', tag => '008', from => 15, length => 3;
has 'illustrations', is => 'ctr', tag => '008', from => 18, length => 4;
has 'target_audience', is => 'ctr', tag => '008', from => 22, length => 1;
has 'form_of_item', is => 'ctr', tag => '008', from => 23, length => 1;
has 'nature_of_contents', is => 'ctr', tag => '008', from => 24, length => 4;
has 'government_publication', is => 'ctr', tag => '008', from => 28, length => 1;
has 'biography', is => 'ctr', tag => '008', from => 34, length => 1;
has 'language', is => 'ctr', tag => '008', from => 35, length => 3;
has 'modified_record', is => 'ctr', tag => '008', from => 38, length => 1;
has 'cataloging_source', is => 'ctr', tag => '008', from => 39, length => 1;
	 
has 'import_record' => (
	is => 'method',
	code => sub {
		my ($self,$record) = @_;
		return 'invalid record' if ! ref $record or ref $record !~ /^MARC::Record/;
		undef $self->{fields};
		$self->add_field($_) for @{$record->fields};
		return $self;
	}
);
has 'import_file' => (
	is => 'method',
	code => sub {
		my ($self,$type,$path) = @_;
		confess 'file type not recognized' if ! grep {$_ eq $type} qw/marc21 mrk xml excel/;
		my $set = MARC::Set->new;
		$set->import_file($type,$path);
		my $r = ($set->records)[0];
		$self->add_field($_) for @{$r->fields};
	}
);
has 'import_hash' => (
	is => 'method',
	code => sub {
		my ($self,%hash) = @_;
		while (my ($tag,$place) = each %hash) {
			my $field = MARC::Field->new(tag => $tag);
			while (my ($sub, $vals) = each %$place) {
				if (substr($sub,0,3) eq 'ind') {
					$field->$sub($vals);
				} else {
					if (! ref $vals) {
						$field->set_sub($sub,$vals);
					} elsif (ref $vals eq 'ARRAY') {
						$field->set_sub($sub,$_) for @$vals;
					} else {
						confess "invalid value";
					}
				}
			}
			next if ! $field->text and ! $field->indicators;
			$self->add_field($field);
		} 
	}
);
has 'defaults' => (
	is => 'rw',
	param => 0,	
	trigger => sub {
		use Storable 'dclone';
		my ($self,$record) = @_;
		
		confess 'defaults must be a MARC::Record' if ref $record ne 'MARC::Record';
		my $defaults = dclone($record);
		
		$defaults->delete_tag('001');
		my $fields = $defaults->fields;
		if ($fields) {
			confess 'cannot add defaults after fields already exist' if $self->field_count > 0;
			$self->add_field($_) for (@$fields);
			$_->is_overwritable(1) for @{$self->fields};
			return;
		}
	}
);
has 'named_fields' => (
	is => 'method',
	code => sub {
		my $self = shift;
		my @return;
		my @family = split '::', ref $self;
		my $base = shift(@family).'::'.shift(@family);
		my %meths = $base->methods;
		for (keys %meths) {
			push @return, $_ . ': '.$self->$_ for keys %{$meths{$_}};
		}
		for (@family) {
			my $class = $base."::$_";
			my %meths = $class->methods;
			for (keys %meths) {
				push @return, $_ . ': '.$self->$_ for keys %{$meths{$_}};
			}
			$base .= '::'.$_;
		}
		#push @return, '*' x 100;
		return join "\n", @return;
	}
);
has 'add_field' => (
	is => 'method',
	code => sub {
		my ($self,$field,%params) = @_;
		confess 'invalid MARC::Field' if ref $field ne 'MARC::Field';
		my $tag = $field->tag;
		if ($params{overwrite}) {
			$self->{fields}->{$field->tag}->[0] = $field;
			$field->place(1);
		} else {
			my @fields = $self->fields($tag);
			if (grep {$_->is_overwritable} @fields) {
				for my $e (@fields) {
					if ($e->is_overwritable) {
						for (qw/ind1 ind2/) {
							my $ind = $field->$_;
							$ind ||= '__';
							$e->$_($ind) if $ind =~ /\d/;
						}
						for (@{$field->{subfields}}) {
							$e->set_subfield($_->code,$_->value,replace => 1);
						}
						$e->_build_text;
						$e->is_overwritable(0);
						last;
					}
				}
			} else {
				push @{$self->{fields}->{$tag}}, $field;
				$field->place(scalar @{$self->{fields}->{$tag}});
			}
		}
		return $self;
	}
);
has 'field_count' => (
	is => 'method',
	code => sub {
		my ($self,$tag) = @_;
		if ($tag) {
			if (my $fields = $self->{fields}->{$tag}) {
				return scalar @$fields;
			} else {
				return 0;
			}
		} 
		my $count = 0;
		for my $tag (keys %{$self->{fields}}) {
			my $fields = $self->{fields}->{$tag};
			$count += scalar @$fields;
		}
		return $count;
	}
);
has 'tag_count' => (
	is => 'alias',
	method => 'field_count'
);
has 'delete_tag' => (
	is => 'method',
	code => sub {
		my ($self,$tag,$i) = @_;
		#undef $self->{fields}->{$tag}->[$i-1] if $i;
		splice @{$self->{fields}->{$tag}},$i-1,1 if $i;
		delete $self->{fields}->{$tag} if ! $i;
		$self->id(undef) if $tag eq '001';
	}
);
has 'delete_field' => (
	is => 'method',
	code => sub {
		my ($self,$to_delete) = @_;
		my $tag = $to_delete->tag;
		my $i = 0;
		for my $field ($self->get_fields($tag)) {
			if (refaddr($field) == refaddr($to_delete)) {
				splice @{$self->{fields}->{$tag}}, ++$i, 1;
			}
		}
	}
);
has 'change_tag' => (
		is => 'method',
		code => sub {
			my ($self,$from_tag,$to_tag) = @_;
			my @fields = $self->get_fields($from_tag);
			$_->tag($to_tag) for @fields;
			push @{$self->{fields}->{$to_tag}}, @fields;
			delete $self->{fields}->{$from_tag};
		}
);
has 'get_fields' => (
	is => 'method',
	code => sub {
		my ($self,@tags) = @_;
		
		my @fields;
		if (@tags) {
			for my $tag (sort @tags) {
				my $fields = $self->{fields}->{$tag};
				push @fields, $_ for @$fields;
			}
		} else {
			for my $tag (sort keys %{$self->{fields}}) {
				my $fields = $self->{fields}->{$tag};
				push @fields, @$fields;
			}
		}
		#@fields = grep {defined} @fields;
		
		return wantarray ? @fields : $fields[0];
	}
);
has 'get_field' => (
	is => 'alias',
	method => 'get_fields'
);
has 'fields' => (
	is => 'alias',
	method => 'get_fields'
);
has 'get_values' => (
	is => 'method',
	code => sub {
		my $self = shift;
		my $tag = shift;
		my @codes = @_;
		my @return;
		for my $field ($self->fields) {
			if ($tag && $field->tag eq $tag) {
				push @return, $field->text and next if $field->is_controlfield;
				push @return, $field->get_values($tag,@codes);
			} elsif (! defined $tag) {
				push @return, $field->get_values;
			} 
		}
		return @return;
	}
);
has 'get_value' => (
	is => 'alias',
	method => 'get_values'
);
has 'get_field_sub' => (
	is => 'method',
	code => sub {
		my ($self,$tag,$sub) = @_;
		return 0 unless $self->has_tag($tag);
		my $return = $self->get_field($tag)->get_sub($sub);
		$return //= 0;
		return $return;
	}
);
has 'get_field_subs' => (
	is => 'method',
	code => sub {
		my ($self,$tag,$sub) = @_;
		return [] unless $self->has_tag($tag);
		my @returns;
		for my $field ($self->get_fields($tag)) {
			push @returns, $field->get_sub($sub);
		}
		#my $return = scalar @returns > 1 ? \@returns : $returns[0];
		return wantarray ? @returns : \@returns;
		#return \@returns;
	}
);
has 'field' => (
	is => 'alias', 
	method => 'get_field_sub'
);
has 'has_field' => (
	is => 'method',
	code => sub {
		my ($self,$tag) = @_;
		#print Dumper $self->get_field($tag);
		return 1 if ref $self->get_field($tag) eq 'MARC::Field';
	}
);
has 'has_tag' => (
	is => 'alias',
	method => 'has_field'
);
has 'list_subfields' => (
	is => 'method',
	code => sub {
		my ($self,$tag) = @_;
		my @return;
		for my $field (@{$self->get_fields($tag)}) {
			return $field->text if ! $field->is_datafield;
			push @return, $field->list_subfield_values;
		}
		return @return;
	}
);
has 'check' => (
	is => 'method',
	code => sub {
		my ($self,$tag,$sub,$match) = @_;
		die 'invalid check' unless ($tag && $sub && $match);
		for ($self->get_fields($tag)) {
			return 1 if $_->check($sub,$match);
		}
		return 0;
	}
);
has 'grep' => (
	is => 'method',
	code => sub {
		my ($self,$tag,$sub,$qr) = @_;
		return grep {$_->check($sub,$qr) == 1} $self->get_fields($tag);
	}
);

has 'merge' => (
	is => 'method',
	code => sub {
		my ($self,$to_merge) = @_;
		$_->is_overwritable(1) for $self->fields;
		$self->add_field($_) for $to_merge->fields;
		#print Dumper $self;
	}
);

sub serialize {
	my ($self,%params) = @_;
	
	my %record;
	for my $field ($self->fields) {
		if ($field->is_leader) {
			$record{leader} = $field->text;
		} elsif ($field->is_controlfield) {
			push @{$record{controlfield}}, {tag => $field->tag, value => $field->text}
		} else {
			my @subfields = map {{code => $_->code, value => $_->value}} @{$field->subfields};
			push @{$record{datafield}}, {tag => $field->tag, subfield => \@subfields, ind1 => $field->ind1, ind2 => $field->ind2};
		}
	}

	return \%record;
}

sub serialize_2 {
	my ($self,%params) = @_;
	
	my %record;
	for my $field ($self->fields) {
		if ($field->is_leader) {
			$record{leader} = $field->text;
		} elsif ($field->is_controlfield) {
			push @{$record{fields}}, {
				$field->tag => $field->text
			};
		} else {
			push @{$record{fields}}, {
				$field->tag => {
					ind1 => $field->ind1,
					ind2 => $field->ind2,
					subfields => [ map { {$_->code => $_->value} } @{$field->subfields} ]
				}
			};
		}
	}
	
	return \%record;
}

sub to_json {
	require JSON;
	my ($self,%p) = @_;
	my $data = $p{alt} ? $self->serialize_2 : $self->serialize;
	return JSON->new->pretty(1)->encode($data);
}

sub to_yaml {
	require YAML;
	my $self = shift;
	return YAML::Dump($self->serialize);
}

sub to_tie_ixhash {
	my $self = shift;
	
	my $tie = Tie::IxHash->new;
	$tie->Push(_id => 0 + $self->id);
	
	
	for my $field (grep {$_->is_controlfield} $self->fields) {
		my $tag = $field->tag;
		
		if (! $tie->FETCH($tag)) {
			$tie->Push($tag)	
		} 
		
		my $aref = $tie->FETCH($tag);
		push @$aref, $field->text; 
		
		$tie->STORE($tag,$aref);
	}
	
	for my $field (grep {$_->is_datafield} $self->fields) {
		next if scalar @{$field->subfields} == 0;
		
		my $tag = $field->tag;
		
		if (! $tie->EXISTS($tag)) {
			$tie->Push($tag)	
		} 
		
		my $aref = $tie->FETCH($tag);
		
		my $asubs = $field->auth_subfields;
		
		for my $sub ($field->subfields) {
			for my $asub (@$asubs) {
				if ($sub->code eq $asub->code) {
					$sub->xref($field->xref);
				}
			}
		}
		
		push @$aref, Tie::IxHash->new (
			indicators => [$field->ind1,$field->ind2],
			subfields => [
				map {
					my @payload = $_->xref ? (xref => 0 + $_->xref) : (value => $_->value);
					Tie::IxHash->new (
						code => $_->code,
						@payload
					)
				} 
				$field->subfields
			]
		);
		
		$tie->STORE($tag,$aref);
	}
	
	return $tie;
}

sub to_mongo {
	my ($self,$col) = @_;
	die 'must supply MongoDB collection handle' unless ref $col eq 'MongoDB::Collection';
	
	return $col->replace_one({_id => 0 + $self->id}, $self->to_tie_ixhash, {upsert => 1});
}

sub to_marc21 {
	my $self = shift;
	
	$self->leader((' ' x 20).'4500') if ! $self->leader;
	
	my ($directory,$data);
	my $next_start = 0;
	for my $field ($self->fields) {
		next if $field->is_leader; 
		my $str = ($field->indicators // '').$field->text;
		$str .= $field->terminator if substr($str,-1) ne $field->terminator;
		$data .= $str; 
		my $length = length $str;
		$directory .= $field->tag.sprintf("%04d", $length).sprintf("%05d", $next_start);
		$next_start += $length;
	}
	$data .= $self->record_terminator;
	$self->directory($directory.$self->field_terminator);
	my $leader_dir_len = length($self->directory) + 24; 
	my $total_len = $leader_dir_len + length($data);
	$self->record_length(sprintf("%05d",$total_len));
	$self->base_address_of_data(sprintf("%05d",$leader_dir_len));
		
	return $self->leader.$self->directory.$data;
}

sub to_mrk {
	my $self = shift;
	
	my $str;
	for my $field ($self->fields) {
		$str .= '=';
		my $tag = $field->tag;
		$tag = 'LDR' if $field->is_leader;
		$str .= $tag . '  ';
		if ($field->is_datafield) {
			my $inds = $field->indicators;
			$inds ||= '  ';
			$inds =~ s/ /\\/g;
			$str .= $inds;
		}
		my $text = $field->text;
		next if ! $text;
		my $delim = $field->delimiter;
		$text =~ s/$delim/\$/g;
		my $term = $field->terminator;
		$text =~ s/$term//g;
		$str .= $text;
	} continue {
		$str .= "\n";
	}
	$str .= "\n";
	
	return $str;
}

sub to_xml {
	require XML::Writer;
	my $self = shift;
	
	return if $self->field_count == 0;
	
	my $str;
	my $writer = XML::Writer->new(OUTPUT => \$str);
	
	$writer->setDataMode(1) and $writer->setDataIndent(4); # if $self->pretty;
	$writer->startTag('record');
	
	for my $field ($self->fields) {
		goto SKIP; # Tind doesn't use the "leader" tag. use controlfield 000 instead for tind export :\
		if ($field->is_leader) {
			$writer->startTag('leader');
			$writer->characters($field->chars);
			$writer->endTag('leader');
		} 
		SKIP:
		if ($field->is_controlfield) {
			$writer->startTag('controlfield','tag' => $field->tag);
			$writer->characters($field->chars);
			$writer->endTag('controlfield');
		} elsif ($field->is_datafield && @{$field->subfields} > 0) {
			$writer->startTag('datafield','tag' => $field->tag, 'ind1' => $field->ind1, 'ind2' => $field->ind2);
			for ($field->subfields) {
				$writer->startTag('subfield', 'code' => $_->code);
				$writer->characters($_->value);
				$writer->endTag('subfield');
			}
			$writer->endTag('datafield');
		}
	}
		
	$writer->endTag('record');
	$writer->end;
			
	return $str;
}

sub _controlfield_element {
	#my ($args,$params) = @_;
	#my ($self,$val) = @$args;
	
	my ($name,$properties,$args) = @_;
	#say shift @_;
	
	my ($self,$val) = @$args;
	my ($tag,$pos,$len,$code) = @{$properties}{qw/tag from length code/};
	undef $len if $len eq 'x';
	my $att = \$self->{$name};
	if ($val) {
		#$self->_validate_input($name,$val);
		$self->add_field(MARC::Field->new(tag => $tag)) if (! $self->has_tag($tag));
		$self->get_field($tag)->position(start => $pos, value => $val);
		$code->($self,$val) if $code;
		$$att = $val;
		return $self;
	} elsif (my $field = $self->get_field($tag)) {
		#$len ||= 1;
		$$att = $field->position(start => $pos, length => $len);
	} else {
		#warn $name.' not available: '.$tag.' has not been added';
		#$$att = ''; # x $len;
	}
	$code->($self) if $code;
	$$att ||= '';
	$$att =~ s/\x{1E}$//;
	return $$att;
}


