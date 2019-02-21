use v5.10;
use sigtrap;

package Hzn::SQL;
use Moo;
use Carp qw<carp croak cluck confess>;

use lib 'c:\repos\modules';
use MARC::Decoder;

has 'database' => (
	is => 'rw',
	default => 'horizon'
);

has 'script' => (
	is => 'rw',
	isa => sub {
		die if ! -e $_[0];
	}
);

has 'statement' => (
	is => 'rw',
	lazy => 1,
	builder => sub {
		my $self = shift;
		
		if (my $path = $self->script) {
			local $/ = undef;
			open my $script,'<',$path;
			return <$script>;
		} 
	},
);

has 'temp_script' => ( 
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		
		confess q{Attribute "statement" or "script" must be set} unless $self->statement;		
		my $path = 'temp_'.time.'.sql';
		open my $temp,'>',$path;
		say {$temp} ($self->statement // '')."\nGO";
		
		return $path;
	}
);

has 'cmd' => (
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		
		my $path = $self->temp_script;
		my $db = $self->database;
		my $usr = $ENV{HORIZON_USERNAME} // die 'environemnt variable HORIZON_USERNAME must be set';
		my $pwd = $ENV{HORIZON_PASSWORD} // die 'environment variable HORIZON_PASSWORD must be set';
		
		return qq{isql -S horizon -U $usr -P $pwd -s "\x{9}" -h 0 -w 500000 -D $db -i $path -J cp850};	
	}
);

has 'decoder' => (
	is => 'ro',
	default => sub {
		require MARC::Decoder;
		return MARC::Decoder->new;
	}
);

has 'encoding' => (
	is => 'rw',
	isa => sub {
		#cluck
		confess 'encoding can only be "marc8" or "utf8"' unless $_[0] =~ /^(marc8|utf8)/;
	},
	default => 'marc8',
);

has 'save_results', is => 'rw', default => 0;
has 'header', is => 'ro', default => sub {[]};
has 'results_cache', is => 'ro', default => sub {[]};
has 'verbose', is => 'rw', default => 0;
has 'output_file', is => 'rw';
has 'output_fh' => (
	is => 'ro',
	lazy => 1,
	builder => sub {
		my $self = shift;
		open my $fh,'>:utf8',$self->output_file or die;
		return $fh;
	}
);

###

# sub BUILD {}

sub DESTROY {
	my $self = shift; 
	unlink $self->temp_script if $self->temp_script;
}

###

sub run {
	my ($self,%p) = @_;
	my $callback = $p{callback};
	

	my $pid = open my $raw, '-|', $self->cmd or die "wtf?";
	local $SIG{INT} = sub {kill 1, $pid; die "SIGINT"}; #  
	
	if ($self->encoding eq 'utf8') {
		binmode STDOUT, ':utf8';
	}
	
	my @results;
	
	RAW: while (my $line = <$raw>) {

		CATCH: {
			if ($. == 1 && $line =~ /^Msg \d+/) {
				say "\nSybase error!\n", $line, <$raw>;
				die $self->statement."\n";
			}
		}
		
		JUNK: {
			$. == 2 && next RAW; # header separator row
			index($line,"\t") == -1 && next RAW;
		}
		
		
		my @row = split(/\t/,$self->_clean($line));
		
		if ($. == 1) {
			$self->{header} = \@row;
			say {$self->output_fh} join "\t", @row if $self->output_fh;
			next;
		}
		
		push @results, \@row;
		say join "\t", @row if $self->{verbose};
		say {$self->output_fh} join "\t", @row if $self->output_fh;
		
		CALLBACK: {
			if ($callback) {
				confess 'invalid callback' if ref $callback ne 'CODE';
				$callback->(\@row,$self->header);
			}
		}
	}
	
	unlink $self->temp_script;
	
	if ($self->save_results) {
		$self->{results_cache} = \@results;
	}
	
	return wantarray ?  @results : $self;
}

sub results {
	my $self = shift;
	confess 'Attribute "save_results" must be set to a true value to return cached results with method "results"' unless $self->{save_results};
	return @{$self->{results_cache}};
}

sub _clean {
	my ($self,$str) = @_;
	
	# convert marc8 to utf8
	$str = $self->decoder->decode($str) if $str =~ /[\x{80}-\x{FF}]|\x{1B}|<U\+....>/ && $self->encoding eq 'utf8';
	# remove newlines
	$str =~ s/[\r\n]//g;
	# remove ascii ctrl chars
	$str =~ s/[\x10-\x1A]//g;
	# remove leading tab and any leading space in the first column
	$str =~ s/^\t *//;
	# remove any trailing trailing spaces and trailing tab
	$str =~ s/ *\t$//;
	# remove trailing spaces in columns
	$str =~ s/ +\t/\t/g;
	# remove leading spaces in columns
	$str =~ s/\t +/\t/g;
	# remove the string 'NULL' when it's the only string in the column
	$str =~ s/(\t)?NULL(\t)/$1 ? "$1$2" : "$2"/ge;
	
	return $str;
}

1;