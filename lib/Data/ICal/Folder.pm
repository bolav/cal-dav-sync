package Data::ICal::Folder;

use Moose;

use Data::ICal::Folder::Entry;

has 'entries_hash' => (is => 'rw', isa => 'HashRef', default => sub { {} });

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
    
    $self->entries_hash->{$entry->fn} = $entry;
}

sub entries {
    my $self = shift;
    return values %{$self->entries_hash};
}

sub exists_fn {
    my $self = shift;
    my ($fn) = @_;
    
    if (defined $self->entries_hash->{$fn}) {
        return 1;
    }
    return 0;
}

1;
