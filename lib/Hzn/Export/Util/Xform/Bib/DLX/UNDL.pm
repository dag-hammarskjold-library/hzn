use v5.10;
use strict;
use warnings;
use utf8;

package Hzn::Export::Util::Xform::Bib::DLX::UNDL;
use List::Util qw<any>;
use URI::Escape;

use constant LANG_ISO_STR => {
	# unicode normalization form C (NFC)
	AR => 'العربية',
	ZH => '中文',
	EN => 'English',
	FR => 'Français',
	RU => 'Русский',
	ES => 'Español',
	#DE => 'Deutsch',
	DE => 'Other',
};

use constant LANG_STR_ISO => {
	# decomposed?
	العربية => 'AR',
	中文 => 'ZH',
	Eng => 'EN',
	English => 'EN',
	Français => 'FR',
	Русский => 'RU',
	Español => 'ES',
	Deutsch => 'DE',
	Other => 'DE',
	
	# composed?
	العربية => 'AR',
	中文 => 'ZH',
	English => 'EN',
	Français => 'FR',
	Русский => 'RU',
	Español => 'ES',
	Other => 'DE',
	
	# alt encoding normalization form? not sure how to convert
	Français => 'FR',
	Español => 'ES',
};

use constant HARVEST_URLS => [
	'digitization.s3.amazonaws', 
	'undl-js.s3.amazonaws',
	'un-maps.s3.amazonaws', 
	'dag.un.org'
];

sub _856 {
	my ($record,$s3_db) = @_;
	
	die 'invalid db ref' unless ref $s3_db eq 'DBI::db';
	
	S3: {
		$s3_db || next;
		my $bib = $record->id;
		for my $ref (map {$s3_db->selectall_arrayref("select lang, key from $_ where bib = $bib")} qw|docs extras|) {
			FILES: for (@$ref) {
				my ($lang,$key) = @$_;
				#say $key;
				$lang = LANG_ISO_STR->{$lang};
				my $newfn = (split /\//,$key)[-1];
				my $isos = $1 if $newfn =~ /-([A-Z]+)\.\w+/;
				my @langs;
				while ($isos) {
					my $iso = substr $isos,0,2,'';
					push @langs, LANG_ISO_STR->{$iso} if LANG_ISO_STR->{$iso};
				}
				$key =~ s/ /%20/g;
				my $FFT = MARC::Field->new(tag => 'FFT')->set_sub('a','http://undhl-dgacm.s3.amazonaws.com/'.$key);
				$FFT->set_sub('n',clean_fn($newfn));
				$FFT->set_sub('d',join(',',@langs));
				for my $check ($record->get_fields('FFT')) {
					next FILES if $check->sub('d') eq $FFT->sub('d');
				}
				$record->add_field($FFT);
			}
		}
	}
	
	my $thumb_url;
	THUMB: for my $f ($record->get_fields('856')) {
		if ($f->check('3',qr/Thumbnail/)) {
			$thumb_url = $f->get_sub('u');
		}
	}
	
	for my $hzn_856 ($record->get_fields('856')) {
		
		my $url = $hzn_856->get_sub('u');
		my $lang = $hzn_856->get_sub('3');
		
		if (any {$url =~ /$_/} qw|daccess-ods.un.org dds.ny.un.org|) {
			
			$record->delete_field($hzn_856);
			
		} elsif (any {$url =~ /$_/} @{&HARVEST_URLS}) {
			
			$record->delete_field($hzn_856);
			
			next if $hzn_856->check('3',qr/Thumbnail/i); 
			chop $url while substr($url,-1,1) eq ' ';
			my $newfn = (split /\//,$url)[-1];
			
			if ($url =~ m|(https?://.*?/)(.*)|) { 
				if (uri_unescape($2) eq $2) {
					$url = $1.uri_escape($2);
					$url =~ s/%2F/\//g;
				} 
			} else {
				die 'invalid url';
			}
		
			my $cleanfn = clean_fn($newfn);
			my $seen = scalar grep {base($cleanfn) eq $_} map {base($_)} $record->get_values('FFT','n');
			$cleanfn = base($cleanfn)."_$seen.".ext($cleanfn) if $seen;
			
			my $FFT = MARC::Field->new(tag => 'FFT')->set_sub('a',$url);
			$FFT->set_sub('n',$cleanfn);
			$lang = 'English' if $lang eq 'Eng';
			$FFT->set_sub('d',$lang);
			
			### restrict tiffs 
			$FFT->set_sub('r','tiff') if $newfn =~ /\.tiff?$/; 
			
			### thumbnail
			$FFT->set_sub('x',$thumb_url) if $thumb_url;
			
			for my $check ($record->get_fields('FFT')) {
				# avoid duplicate FFT fields
				next FIELDS if $check->text eq $FFT->text;
			}
		
			$record->add_field($FFT);
		}
	}
}
	
sub clean_fn {
	# scrub illegal characters for saving on Invenio's filesystem
	my $fn = shift;
	my @s = split '\.', $fn;
	$fn = join '-', @s[0..$#s-1];
	my $ext = $s[-1];
	$fn =~ s/\s//g;
	$fn =~ tr/[];/^^&/;
	$fn .= ".$ext";
	return $fn;
}

sub base {
	my $fn = shift;
	my @parts = split /\./, $fn;
	return join '', @parts[0..$#parts-1];
}

sub ext {
	my $fn = shift;
	my @parts = split /\./, $fn;
	return $parts[-1];
}



1;