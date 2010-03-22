package Data::ICal::Folder::Entry;

use Moose;

has 'fn' => (is => 'rw', isa => 'Str');
has 'etag' => (is => 'rw', isa => 'Str');
has 'displayname' => (is => 'rw', isa => 'Str');
has 'lastmodified' => (is => 'rw', isa => 'Str');


# One of the following
has 'filepath' => (is => 'rw', isa => 'Str');
has 'url' => (is => 'rw', isa => 'URI');
has 'data' => (is => 'rw', isa => 'Str');


1;