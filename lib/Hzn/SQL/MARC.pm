use v5.10;

package Hzn::SQL::MARC;
use Moo;
use Carp qw'confess';
use Hzn::SQL;
use MARC;

use Data::Dumper;

has 'encoding', is => 'rw', default => 'utf8';
has 'processed' => (is => 'ro');

has 'criteria', is => 'ro';

has 'statement' => (
	is => 'ro',
	default => sub {
		die 'attribute "statement" must be implemented by subclass';
	}
);

sub iterate {
	my ($self,%params) = @_;
	
	$self->{criteria} = $params{criteria} // die;
	
	my $callback = $params{callback} // die;
	confess 'invalid callback' if ref $callback ne 'CODE';
	
	my $sql = Hzn::SQL->new (
		encoding => $self->encoding,
		statement => $self->statement
	);
	
	my (%index,$record);
	
	$sql->run (
		callback => sub {
			my $row = shift;
			my ($id,$tag,$inds,$auth_inds,$text,$auth_text,$xref,$place) = @$row[0..7];
				
			die if ! $id; # this should be impossible if subclass is implemented correctly
		
			confess "invalid tag ($tag) in record ".$record->id if $tag !~ /^\d{3}$/;
			
			if (! $index{$id}) {
				
				if ($record) {
					# run callback on the last record
					$callback->($record);
				}
				
				$record = MARC::Record->new->id($id);
	
				$index{$id} = 1;
			}
			
			my $field = MARC::Field->new (
				tag => $tag,
				xref => $xref,
				indicators => $inds,
				auth_indicators => $auth_inds,
				auth_text => $auth_text,
				text => $text.$auth_text,
			);
			
			$record->add_field($field);
		}
	);
	
	# catch last record !
	if ($record) {
		$callback->($record);
	}
	
	$self->{processed} = scalar keys %index;
}

1;

