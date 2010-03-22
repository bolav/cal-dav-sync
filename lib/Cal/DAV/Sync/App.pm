package Cal::DAV::Sync::App;

use strict;
use Moose;

with 'MooseX::Getopt';

use Cal::DAV;
use Cal::DAV::Sync::Schema;
# use XML::DOM::Parser;
use HTTP::DAV::Utils;

has 'user' => (is => 'rw', isa => 'Str');
has 'pass' => (is => 'rw', isa => 'Str');
has 'url' => (is => 'rw', isa => 'Str');
has 'dsn' => (is => 'rw', isa => 'Str', default => 'dbi:SQLite:sync.db');

has 'cal' => (is => 'rw', isa => 'Cal::DAV', lazy_build => 1);
has 'parser' => (is => 'rw', isa => 'XML::DOM::Parser', lazy_build => 1);
has 'schema' => (is => 'rw', isa => 'Cal::DAV::Sync::Schema', lazy_build => 1);

sub _build_schema {
    my $self = shift;
    
    Cal::DAV::Sync::Schema->connect($self->dsn);
}

sub _build_parser {
    my $self = shift;
    
    XML::DOM::Parser->new();
    
}

sub _build_cal {
    my $self = shift;
    
    my $c = Cal::DAV->new( user => $self->user, pass => $self->pass, url => $self->url, DebugLevel => 2);
    $c->dav->DebugLevel(2);
    return $c;
}

use Data::Dump qw/dump/;

sub get_hrefs {
    my $self = shift;
    my ($res, $property) = @_;
    
    my @retval;
    
    my $content = $res->get_property($property);
    my $doc = $self->parser->parse($content);

    my @nodes_href= HTTP::DAV::Utils::get_elements_by_tag_name($doc,"D:href");
    
    my $href;
    
    foreach my $node_href (@nodes_href) {
        $href = $node_href->getFirstChild->getNodeValue();
        my $href_uri = HTTP::DAV::Utils::make_uri($href);
        my $res_url = $href_uri->abs( $res->get_uri );
        push @retval, $res_url;
    }
    
    return @retval;
}

sub run {
    my $self = shift;
    print $self->cal->cal;
}

sub get_calendar_home {
    my $self = shift;
    my ($url) = @_;
    
    my $res = $self->cal->dav->new_resource( -uri => $url );
    $res->propfind( -depth => 0, -text => '
    <D:prop xmlns:x1="urn:ietf:params:xml:ns:caldav">
     <x1:calendar-home-set/>
     <x1:calendar-user-address-set/>
     <x1:schedule-inbox-URL/>
     <x1:schedule-outbox-URL/>
     <D:displayname/>
    </D:prop>' );
    
    my @hrefs = $self->get_hrefs($res, 'calendar-home-set');
    return $hrefs[0];
}

sub get_calendars {
    my $self = shift;
    my ($url) = @_;
    
    my $res = $self->cal->dav->new_resource( -uri => $url );
    $res->propfind( -depth => 1, -text => '
    <D:prop xmlns:x3="http://apple.com/ns/ical/" xmlns:x2="urn:ietf:params:xml:ns:caldav">
     <CS:getctag xmlns:CS="http://calendarserver.org/ns/"/>
     <D:displayname/>
     <x2:calendar-description/>
     <x3:calendar-color/>
     <x3:calendar-order/>
     <D:resourcetype/>
     <x2:calendar-free-busy-set/>
    </D:prop>
    ' );
    
    my @retval;
    
    foreach my $res_c ($res->get_resourcelist->get_resources()) {
        if ($res_c->get_property('resourcetype') =~ /calendar/) {
            push @retval, $res_c->get_uri;
        }
    }
    return @retval;
}

1;
