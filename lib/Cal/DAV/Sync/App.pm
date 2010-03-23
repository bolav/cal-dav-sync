package Cal::DAV::Sync::App;

use strict;
use Moose;

with 'MooseX::Getopt';

use Cal::DAV;
use Cal::DAV::Sync::Schema;

has 'user1' => (is => 'rw', isa => 'Str');
has 'pass1' => (is => 'rw', isa => 'Str');
has 'url1' => (is => 'rw', isa => 'Str');

has 'user2' => (is => 'rw', isa => 'Str');
has 'pass2' => (is => 'rw', isa => 'Str');
has 'url2' => (is => 'rw', isa => 'Str');

has 'dsn' => (is => 'rw', isa => 'Str', default => 'dbi:SQLite:sync.db');

has 'cal1' => (is => 'rw', isa => 'Cal::DAV', lazy_build => 1);
has 'cal2' => (is => 'rw', isa => 'Cal::DAV', lazy_build => 1);
has 'schema' => (is => 'rw', isa => 'Cal::DAV::Sync::Schema', lazy_build => 1);

sub _build_schema {
    my $self = shift;
    
    Cal::DAV::Sync::Schema->connect($self->dsn);
}

sub _build_cal1 {
    my $self = shift;
    
    Cal::DAV->new( user => $self->user1, pass => $self->pass1, url => $self->url1, );
}

sub _build_cal2 {
    my $self = shift;
    
    Cal::DAV->new( user => $self->user2, pass => $self->pass2, url => $self->url2, );
}


use Data::Dump qw/dump/;

sub _get_cal {
    my $self = shift;
    my ($url) = @_;
    
    my $cal_rs = $self->schema->resultset('Calendar')->search( {url => $url} );
    my $cal = $cal_rs->first;
    if (!$cal) {
        $cal = $self->schema->resultset('Calendar')->create({ url => $url, ctag => '', });
    }
    return $cal;
}

sub run {
    my $self = shift;
    
    # Get CAL 1.
    # Get CAL 2.
    
    # Check ctag, for changes
    # Check that all things are in both
    
    my $cal1 = $self->_get_cal($self->url1);
    my $cal2 = $self->_get_cal($self->url2);
    
    my $dl_cal1 =  $self->cal1->cal;
    my $dl_cal2 =  $self->cal2->cal;
    
    if ($self->cal1->ctag eq $cal1->ctag) {
        print "No changes in cal1\n";
    }
    else {
        if (ref $dl_cal1 eq 'Data::ICal::Folder') {
            print "Downloaded folder cal1\n";
            $cal1->save_ical_folder($dl_cal1);
            # Check for deletes
        }
    }

    if ($self->cal2->ctag eq $cal2->ctag) {
        print "No changes in cal2\n";
    }
    else {
        if (ref $dl_cal2 eq 'Data::ICal::Folder') {
            print "Downloaded folder cal2\n";
            $cal2->save_ical_folder($dl_cal2);
            # Check for deletes
        }
    }

    $self->cal2->auto_commit(1);
    $self->cal1->dav->DebugLevel(2);
    $self->cal2->dav->DebugLevel(2);
    
    foreach my $e ($dl_cal1->entries) {
        if ($dl_cal2->exists_fn($e->fn)) {
            print "Existing event".$e->as_string."\n";
        }
        else {
            if (! defined $e->cal) {
                my $newe = Cal::DAV->new( user => $self->user1, pass => $self->pass1, url => $e->url, );
                $e->cal($newe->cal);
            }
            print "saving ".$e->as_string." to ".$self->url2."\n";

            $self->cal2->add_event($e);
        }
    }
    $self->cal2->auto_commit(0);

    $self->cal1->auto_commit(0);
    foreach my $e ($dl_cal2->entries) {
        if ($dl_cal1->exists_fn($e->fn)) {
            print "Existing event".$e->as_string."\n";
        }
        else {
            if (! defined $e->cal) {
                my $newe = Cal::DAV->new( user => $self->user2, pass => $self->pass2, url => $e->url, );
                $e->cal($newe->cal);
            }
            print "saving ".$e->as_string." to ".$self->url1."\n";

            $self->cal1->add_event($e);
        }
    }
    $self->cal1->auto_commit(0);
    
    
    $cal1->update({ ctag => $self->cal1->ctag });
    $cal2->update({ ctag => $self->cal2->ctag });
    
}

1;
