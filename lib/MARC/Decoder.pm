use strict;
use warnings;
use feature qw'state say';

package MARC::Decoder;
#use base 'Decoder::Base';
use Alpha;
use MARC::Decoder::Map;
use Unicode::Normalize qw<normalize compose>;

has 'charmap', is => 'ro', default => MARC::Decoder::Map->new;
has 'g0', is => 'rw', deafult => 42;
has 'g1', is => 'rw', default => 45;
has 'code_page', is => 'rw';

# G and bytes per character
my ($g0,$g1);
use constant INTERMEDIATES => {
	'(' => [\$g0, 1],
	'$' => [\$g0, 3],
	')' => [\$g1, 1],
	'$)' => [\$g1, 3]
};

# charset iso code to use for lookup
use constant FINALS => {
	'1' => '31',
	'2' => '32',
	'3' => '33',
	'4' => '34',
	'B' => '42',
	'!E' => '45',
	'N' => '4E',
	'Q' => '51',
	'S' => '53',
	'b' => '62',
	'g' => '67',
	'p' => '70',
	's' => '42'
};

sub decode {
	my ($self,$str) = @_;
	($g0,$g1) = (42,45);
	  
	#my ($g0,$g1) = ($self->g1,$self->g0);
	my ($bytes,$index,$c,@utf8) = (1,0,0);
	
	CHARS: while ($index < length($str)) {
		my $char = substr($str,$index,1);
		my $dec = ord $char;
		my $hex = sprintf "%X",$dec;
		
		PROCESS_ESCAPE: {
			# set G and bytes based on escape sequence
			if ($hex eq '1B') {
				my $rest = substr($str,$index);
				
				my ($intermediate,$final,$seq,$g);
				for my $i (sort keys %{&INTERMEDIATES}) {
					# sort ensures multibyte matches last
					$intermediate = $1 if $rest =~ /^\x{1B}(\Q$i\E)/;
				}
				if ($intermediate) {
					for my $f (sort keys %{&FINALS}) {
						# sort ensures multibyte matches last
						$final = $1 if $rest =~ /^\x1B\Q$intermediate\E(\Q$f\E)/;
					}
					$g = INTERMEDIATES->{$intermediate}->[0];
					$bytes = INTERMEDIATES->{$intermediate}->[1];
					$seq = $char.$intermediate.$final;
				} else {
					# special cases w/ no intermediate 
					$intermediate = '';
					$g = \$g0;
					$bytes = 1;
					$final = $1 if $rest =~ /^\x1B([bpgs])/;
					$seq = $char.$final;
				}
				die "invalid escape sequence in string $str" if ! $final;
				$$g = FINALS->{$final};
				$index += length $seq;
				next CHARS;
			}
		}
		
		my $g = ($dec > 127 ? \$g1 : \$g0);
		#my $g = ($dec > 127 ? \$self->{g1} : \$self={g0});
		
		SET_HEX: {
			if ($bytes > 1) {
				my $char = substr($str,$index,$bytes);
				$hex = uc join '',unpack('(H2)*', $char);
				# how to determine G for multibytes???
				#$g = \$g0;
			} elsif ($bytes == 1) {
				#$g = ($dec > 128 ? \$g1 : \$g0);
			}
		}
		
		CONVERT: {
			my ($unicode,$utf8);
			
			ENCODE: {
				$unicode = $hex if $dec < 128 and $g0 eq 42; # skip lookup if g0 is ascii
				
				EXCEPTIONS:{
					#$unicode = '20' if $dec < 27; # useless random control chars
					$unicode = 'FC' if $hex eq '81'; # weird encoding in horizon where \x{81} = ü
					$unicode = 'F3' if $hex eq '02'; # invalid character. replace with "?"
					$g = \$g0 and $hex = '22' if $hex eq '92'; # \x{92} = single quote
					$g = \$g0 and $hex = '20' if $hex eq 'A0'; # space
					# weird undocumented chars in Horizon. convert them to the correct MARC8 before looking up UCS
					$hex = 'E2' if $hex eq 'D4'; # combining acute
					$hex = 'E2' if $hex eq 'E2'; # combining acute
					$hex = 'F0' if $hex eq 'AD'; # combining cedilla
					$hex = 'E8' if $hex eq 'DE'; # combining umlaut
					$hex = 'E3' if $hex eq 'D2'; # combining circumflex
					$hex = 'E3' if $hex eq 'DF'; # combining circumflex
				}
				$unicode ||= $hex if $hex eq '20'; # hex 20 is space in all charsets
				$unicode ||= $self->charmap->marc_ucs($$g,$hex);
				$unicode ||= $self->charmap->marc_ucs_alt($$g,$hex);
				#warn 'mapping error in charset '.$$g.", char 0x$hex: position $index\n$str" if ! $unicode; # probably invalid multibyte char / 8 bit control char (not supported)
				$unicode ||= $hex;
				$utf8 = pack 'U*', hex $unicode; # encode
			}
			
			WRITE: {
				# add to array of transcoded characters
				if ($self->charmap->is_combining($$g,$hex)) {
					# switch combining char from leading to trailing
					$utf8[$c+1] = $utf8;
				} else {
					if ($utf8[$c]) {
						# combining char is already here; put this char before it
						$utf8[$c-1] = $utf8;
					} else {
						$utf8[$c] = $utf8;
					}
				}
			}
		}
		
		$c++;
		$index += $bytes;
	}
	
	my $return = normalize('C',compose(join '', grep {defined $_} @utf8));
	
	LITERALS: {
    	my @lits = ($return =~ /(<U\+....>)/g);
		for my $lit (@lits) {
			my $rep = $lit;
			my $hex = $1 if $lit =~ /U\+(....)/;
			$rep = pack "U*", hex $hex;
			$return =~ s/\Q$lit\E/$rep/;
		}
	}
	
	return $return;
}

1;