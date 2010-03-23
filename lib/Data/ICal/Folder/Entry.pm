package Data::ICal::Folder::Entry;

use Moose;
with 'MooseX::Clone';

has 'fn' => (is => 'rw', isa => 'Str', lazy_build => 1,);
has 'etag' => (is => 'rw', isa => 'Str');
has 'displayname' => (is => 'rw', isa => 'Str');
has 'lastmodified' => (is => 'rw', isa => 'Str');
has 'dirty' => (is => 'rw', isa => 'Int', default => 0);

# One of the following
has 'filepath' => (is => 'rw', isa => 'Str');
has 'url' => (is => 'rw', isa => 'URI');
has 'data' => (is => 'rw', isa => 'Str');

has 'cal' => (is => 'rw', isa => 'Data::ICal');

sub _build_fn {
    my $self = shift;
    
    if ($self->url) {
        my $s = $self->url;
        $s =~ s/^.*\/([^\/]+)$/$1/;
        return $s;
    }
}

sub as_string {
    my $self = shift;
    
    if (defined $self->displayname and $self->displayname) {
        return $self->displayname;
    }
    return $self->fn;
}



1;