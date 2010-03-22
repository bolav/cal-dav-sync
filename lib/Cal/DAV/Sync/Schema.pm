package Cal::DAV::Sync::Schema;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_namespaces();

=head2 deploy

Calls deploy on all result-classes, if they exist.

=cut

sub deploy {
        my $self = shift;

        $self->next::method(@_);
        
        foreach my $k (keys %{$self->{class_mappings}}) {
                if ($k->can('deploy')) {
                        my $obj = $self->resultset($k)->new({});
                        $obj->deploy();
                }
        }
        
}

1;
