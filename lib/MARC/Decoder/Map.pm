package MARC::Decoder::Map;
use MARC::Decoder::Data;

sub new {
	my $class = shift;
	my %params = @_; # || die "named arguments required";
	return bless {params => \%params}, $class;
}

sub map {
	my $self = shift;
	return $self->{map} if $self->{map};
	$self->{map} = MARC::Decoder::Data->load;
	return $self->{map};
}

sub marc_ucs {
	my ($self,$charset,$marc8) = @_;
	my $return = $self->map->{$charset}->{marc}->{$marc8}->{'ucs'};
}

sub marc_ucs_alt {
	my ($self,$charset,$marc8) = @_;
	my $return = $self->map->{$charset}->{marc}->{$marc8}->{'alt'};
}

sub marc_utf8 {
	my ($self,$charset,$marc8) = @_;
	return $self->map->{$charset}->{marc}->{$marc8}->{'utf-8'};
}

sub is_combining {
	my ($self,$charset,$marc8) = @_;
	return 1 if $self->map->{$charset}->{marc}->{$marc8}->{is_combining};
}

1;