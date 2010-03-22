package Data::ICal::Folder;

use Moose;

use Data::ICal::Folder::Entry;

has 'entries' => (is => 'rw', isa => 'ArrayRef[Data::Ical::Folder::Entry]', default => sub { [] });

sub add_entry {
    my $self = shift;
    my ($entry_data) = @_;
    my $entry;
    if (ref $entry_data eq 'Data::ICal::Folder::Entry') {
        $entry = $entry_data;
    }
    else {
        $entry = Data::ICal::Folder::Entry->new(%{$entry_data});
    }
    
    push @{$self->entries}, $entry;
}

1;
