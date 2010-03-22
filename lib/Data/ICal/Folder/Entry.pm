package Data::ICal::Folder::Entry;

use Moose;

has 'fn' => (is => 'rw', isa => 'Str', lazy_build => 1,);
has 'etag' => (is => 'rw', isa => 'Str');
has 'displayname' => (is => 'rw', isa => 'Str');
has 'lastmodified' => (is => 'rw', isa => 'Str');


# One of the following
has 'filepath' => (is => 'rw', isa => 'Str');
has 'url' => (is => 'rw', isa => 'URI');
has 'data' => (is => 'rw', isa => 'Str');


sub _build_fn {
    my $self = shift;
    
    if ($self->url) {
        my $s = $self->url;
        $s =~ s/^.*\/([^\/]+)$/$1/;
        return $s;
    }
}



1;