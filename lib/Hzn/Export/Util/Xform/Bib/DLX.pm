use v5.10;
use strict;
use warnings;

package Hzn::Export::Util::Xform::Bib::DLX;

sub _993 {
	my $record = shift;
	
	SPLIT: {
		for my $field ($record->fields('993')) {
			if (my $text = $field->sub('a')) {
				my @syms = split_993($text);
				my $inds;
				if ($syms[0]) {
					$inds = $field->inds;
					$field->ind1('9');
				} 
				for (@syms) {
					my $newfield = MARC::Field->new (
						tag => '993',
						indicators => $inds,
					);
					$newfield->sub('a',$_);
					$record->add_field($newfield);
				}
			}
		}
	}
	MEETING: {
		if (my $field = $record->get_field('996')) {
			if (my $pv = pv_from_996($record)) {
				my $newfield = MARC::Field->new (
					tag => '993',
					indicators => '4'
				);
				$newfield->sub('a',$pv);
				$record->add_field($newfield);
			}
		}
	}
	PRSTS: {
		my %prsts;
		for ($record->fields('991')) {
			if (my $text = $_->get_sub('e')) {
				if ($text =~ /.*?(S\/PRST\/[0-9]+\/[0-9]+)/) {
					$prsts{$1} = 1;
				}
			}
		}
		for (keys %prsts) {
			my $field = MARC::Field->new;
			$field->tag('993')->inds('5')->sub('a',$_);
			$record->add_field($field);
		}
	}
}

sub split_993 {
	my $text = shift;
	
	return unless $text && $text =~ /([&;,]|and)/i;
	
	$text =~ s/^\s+|\s+$//;
	$text =~ s/ {2,}/ /g;
	my @parts = split m/\s?[,;&]\s?|\s?and\s?/i, $text;
	s/\s?Amended by //i for @parts;
	my $last_full_sym;
	my @syms;
	for (0..$#parts) {
		my $part = $parts[$_];
		$last_full_sym = $part if $part =~ /^[AES]\//;
		if ($part !~ /\//) {
			$part =~ s/ //g;
			if ($part =~ /^(Add|Corr|Rev)[ls]?\.(\d+)$/i) {
				push @syms, $last_full_sym.'/'.$1.".$2";
			} elsif ($part =~ /(.*)\.(\d)\-(\d)/) {
				my ($type,$start,$end) = ($1,$2,$3);
				push @syms, $last_full_sym.'/'.$type.".$_" for $start..$end;
			} elsif ($part =~ /^(\d+)$/) {
				my $type = $1 if $syms[$_-1] =~ /(Add|Corr|Rev)\.\d+$/i;
				push @syms, $last_full_sym.'/'.$type.".$_";
			} 
		} elsif ($part =~ /\//) {
			if ($part =~ /((Add|Corr|Rev)\.[\d]+\/)/i) {
				my $rep = $1;
				$part =~ s/$rep//;
				push @syms, $last_full_sym.'/'.$part;
			} elsif ($part =~ /^[AES]\//) {
				push @syms, $part;
			} 
		}
	}
	
	return @syms;
}

sub pv_from_996 {
	my $record = shift;

	my $text = $record->get_field('996')->get_sub('a');
	my $meeting = $1 if $text =~ /(\d+).. (plenary )?meeting/i;
	
	return if ! $meeting;
	
	my ($symfield,$body,$session);
	
	for (qw/191 791/) {
		if ($symfield = $record->get_field($_)) {
		
			if (my $sym = $symfield->get_value('a')) {
				return if index($sym, 'CONF') > -1 || substr($sym, 0, 9) eq 'A/HRC/RES';
			}
			
			$body = $symfield->get_sub('b');
			
			if ($session = $symfield->get_sub('c')) {
				$session =~ s/\/$//;
			}
		} else {
			next;
		}
	}
	
	say $record->id.' 996 could not detect session' and return if ! $session;
	say $record->id.' 996 could not detect body' and return if ! $body;			
	
	return if ! grep {$body eq $_} qw|A/HRC/ A/ S/|;
	
	my $pv;
	if (substr($session,-4) eq 'emsp') {
		my $num = substr($session,0,-4);
		$session = 'ES-'.$num;
		if ($num > 7) {
			$pv = $body.$session.'/PV.'.$meeting;
		} else {
			$pv = $body.'PV.'.$meeting;
		}
	} elsif (substr($session,-2) eq 'sp') {
		my $num = substr($session,0,-2);
		$session = 'S-'.$num;
		if ($num > 5) {
			$pv = $body.$session.'/PV.'.$meeting;
		} else {
			$pv = $body.'PV.'.$meeting;
		}
	} elsif ((substr($body,0,1) eq 'A') and ($session > 30)) {
		$pv = $body.$session.'/PV.'.$meeting;
	} else {
		$pv = $body.'PV.'.$meeting;
	}
	
	return $pv;	
}

1;