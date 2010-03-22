package Cal::DAV::Sync::Schema::Result::Calendar;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('calendar');
__PACKAGE__->add_columns(
  'id'   => { data_type => 'INTEGER', is_nullable => 0, size => undef, is_auto_increment => 1, },
  'url'  => { data_type => 'VARCHAR', is_nullable => 0, size => 255 },
  'ctag' => { data_type => 'VARCHAR', is_nullable => 0, size => 255 },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(events => 'Cal::DAV::Sync::Schema::Result::Event','cid');


sub save_ical_folder {
    my $self = shift;
    my ($folder) = @_;
    
    foreach my $e (@{$folder->entries}) {
        my $event_rs = $self->events->search({ fn => $e->fn });
        my $event = $event_rs->first;
        if ($event) {
            # Update
        }
        else {
            $self->events->create({ fn => $e->fn, etag => $e->etag, lastmodified => $e->lastmodified });
        }
    }
}


1;