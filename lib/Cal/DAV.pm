package Cal::DAV;


use strict;
use Data::ICal;
use Data::ICal::Folder;

use HTTP::DAV;
use HTTP::DAV::Utils;

use Moose;

has 'calfolder' => (is => 'rw', isa => 'Data::ICal::Folder', lazy_build => 1,);
has 'isfolder' => (is => 'rw', isa => 'Bool', default => 0,);
has 'ctag' => (is => 'rw', isa => 'Str');
has 'parser' => (is => 'rw', isa => 'XML::DOM::Parser', lazy_build => 1);

sub _build_parser {
    my $self = shift;
    
    XML::DOM::Parser->new();
    
}

sub _build_calfolder {
    my $self = shift;
    
    Data::ICal::Folder->new;
}

our $VERSION="0.6";

=head1 NAME

Cal::DAV - a CalDAV client

=head1 SYNOPSIS

    my $cal = Cal::DAV->new( user => $user, pass => $pass, url => $url);
    # the ics data will be fetched automatically if it's there

    # ... or you can parse some ics 
    $cal->parse(filename => $data);

    # cal now has all the methods of Data::ICal
    # you can now monkey around with the object

    # saves the updated calendar
    $cal->save;

    # deletes the calendar
    $cal->delete;

    # lock the file on the server
    $cal->lock;

    # unlock the file on the server
    $cal->unlock

    # steal the lock
    $cal->steal_lock;

    # also
    $cal->forcefully_unlock_all

    # and
    $cal->lockdiscovery

    # resyncs it with the server
    $cal->get;

    # Get the underlying HTTP::DAV object
    my $dav = $cal->dav;

=head1 DESCRIPTION

C<Cal::DAV> is actually a very thin wrapper round C<HTTP::DAV> and 
C<Data::ICal> but it may gain more functionality later and, in the mean 
time, serves as something that 

=head1 TESTING

In order to test you need to define three environment variables:
C<CAL_DAV_USER>, C<CAL_DAV_PASS> and C<CAL_DAV_URL_BASE> which 
points to a DAV collection that the user supplied has write 
permissions for.

It should be noted that, at the moment, I'm having problems finding
a CalDAV server that allows me to create files and so I can't run all 
the tests.

=head1 METHODS

=cut

=head2 new <arg[s]>

Must have at least C<user>, C<pass> and C<url> args where 
C<url> is the url of a remote, DAV accessible C<.ics> file.

Can optionally take an C<auto_commit> option. See C<auto_commit()> method below.

=cut

# TODO if we remove the option to do operations with other urls 
# we could then cache the resource object
sub new {
    my $class = shift;
    my %args  = @_;
    my %opts;
    for (qw(user pass url)) {
        die "You must pass in a $_ param\n" unless defined $args{$_};
        $opts{"-${_}"} = $args{$_};
    }
    my $dav  = HTTP::DAV->new;
    $dav->credentials(%opts);
    return bless { _dav => $dav, url => $args{url}, _auto_commit => $args{auto_commit} }, $class;
}

=head2 parse <arg[s]>

Make a new calendar object using same arguments as C<Data::ICal>'s C<new()> or C<parse()> methods.

Does not auto save for you.

Returns 1 on success and 0 on failure.

=cut

sub parse {
    my $self = shift;
    my %args = @_;
    $self->{_cal} = Data::ICal->new(%args);
    return (defined $self->{_cal}) ?
        $self->dav->ok("Loaded data successfully") :
        $self->dav->err('ERR_GENERIC', "Failed to load calendar: parse error $@");        
}

=head2 save [url]

Save the calendar back to the server (or optionally to another path).

Returns 1 on success and 0 on failure.

=cut

sub save {
    my $self = shift;
    my $url  = shift || $self->{url};
    my $cal  = $self->{_cal}; # TODO should this be cal()
    return 1 unless defined $cal;
    
    if ($self->isfolder) {
        return $self->save_folder;
    }
    
    my $res  = $self->dav->new_resource( -uri => $url );
    #unless ($self->{_fetched}) {
        #my $ret = $res->mkcol;
        #unless ($ret->is_success) {
        #   return $self->dav->err( 'ERR_RESP_FAIL',"mkcol in put failed ".$ret->message(), $url);
        #}
        #$self->{_fetched} = 1;
    #}
    my $data = $cal->as_string;
    my $ret  = $res->put($data);

    if ($ret->is_success) {
         return $self->dav->ok( "put $url (" . length($data) ." bytes)",$url );
    } else {
         return $self->dav->err( 'ERR_RESP_FAIL',"put failed ".$ret->message(), $url);
    }
}

=head2 delete [url]

Delete the file on the server or optionally another url.

Returns 1 on success and 0 on failure.

=cut

sub delete {
    my $self = shift;
    my $url  = shift || $self->{url};
    my $res  = $self->dav->new_resource( -uri => $url );
    my $ret  = $res->delete();
    if ($ret->is_success) {
         return $self->dav->ok( "deleted $url successfully", $url );
    } else {
         return $self->dav->err( 'ERR_RESP_FAIL',$ret->message(), $url);
    }

}

=head2 get [url]

Refetch the file from the sever to sync it - 

Alternatively fetch an alternative url.

These will lose any local changes.

=cut

sub get {
    my $self = shift;
    my $url  = shift || $self->{url};
    my $res  = $self->dav->new_resource( -uri => $url );
    # dump $res->propfind( -depth => 0 );
    $res->propfind( -depth => 0, );
    if ($res->is_collection) {
        # $res->propfind( -depth => 1 );
        $self->get_dir();
        # print $res->get_resourcelist->as_string . "\n";
        # print $res->as_string . "\n";
        # print "rt: ",$res->get_property("resourcetype"),"\n";
    } 
    else {
        my $ret  = $res->get();
        if ($ret->is_success) {
            $self->{_fetched} = 1;
            #return $self->dav->ok("get $url", $url, $ret->content_length() );
        } else {
            return $self->dav->err('ERR_GENERIC', "get $url failed: ". $ret->message, $url);
        }
        my $data = $res->get_content();
        return $self->dav->err('ERR_GENERIC', "Couldn't get data from $url", $url) unless defined $data;        
        return $self->parse(data => $data);
    }
}

sub get_dir {
    my $self = shift;
    my $url  = shift || $self->{url};
    # my $res  = $self->dav->open( -uri => $url );
    my $res  = $self->dav->new_resource( -uri => $url );
#    $res->propfind( -depth => 1, -text => '<D:prop>
#     <D:getetag/>
#     <D:resourcetype/>
#    </D:prop>' );

    $res->propfind( -depth => 1, );
    $self->ctag($res->get_property('getctag'));
    # Save ctag
        
    my $i = 0;
    
    my $rl = $res->get_resourcelist;
    foreach my $r ( $rl->get_resources() ) {
        $self->calfolder->add_entry(
            { 
                url           => $r->get_uri,
                etag          => $r->get_property('getetag'),
                displayname   => $r->get_property('displayname'),
                lastmodified  => $r->get_property('lastmodifiedepoch'),
            }
        );
    }
    
    $self->{_cal} = $self->calfolder;
    $self->isfolder(1);
    
    # return $res->propfind();
    return $res;
}

sub add_event {
    my $self = shift;
    my ($aentry) = @_;
    
    # Clone entry
    my $entry = $aentry->clone; # ->clone;
    
    $self->calfolder->add_entry($entry);
    if ($self->auto_commit) {
        my $href_uri = HTTP::DAV::Utils::make_uri($entry->fn);
        my $res_url = $href_uri->abs( $self->{url} );
        print "Saving $res_url\n";
        my $res = $self->dav->new_resource( -uri => $res_url );
        $res->put($entry->cal->as_string, 'text/calendar');
    }
    else {
        $entry->dirty(1);        
    }
}

=head2 lock 

Same options as C<HTTP::DAV>'s C<unlock>.

=cut

sub lock {
    my $self = shift;
    my $resp = $self->_do_on_dav('lock', @_);
    if ( $resp->is_success() ) {
      return $self->dav->ok( "lock $self->{url} succeeded",$self->{url} );
    } else {
      return $self->dav->err( 'ERR_RESP_FAIL',$resp->message, $self->{url} );
    }
}

=head2 unlock 

Same options as C<HTTP::DAV>'s C<unlock>.

=cut

sub unlock {
    my $self = shift;
    my $resp = $self->_do_on_dav('unlock', @_);
    if ( $resp->is_success ) {
      return $self->dav->ok( "unlock $self->{url} succeeded",$self->{url} );
    } else {
      # The Resource.pm::lock routine has a hack 
      # where if it doesn't know the locktoken, it will 
      # just return an empty response with message "Client Error".
      # Make a custom message for this case.
      my $msg = $resp->message;
      if ( $msg=~ /Client error/i ) {
          $msg = "No locks found. Try steal";
          return $self->dav->err( 'ERR_GENERIC',$msg,$self->{url} );
      } else {
          return $self->dav->err( 'ERR_RESP_FAIL',$msg,$self->{url} );
      }
    }
}

=head2 steal_lock

Same options as C<HTTP::DAV>'s C<steal_lock>.

=cut

sub steal_lock {
    my $self = shift;
    my $resp = $self->_do_on_dav('steal_lock', @_);
    if ( $resp->is_success() ) {
      return $self->dav->ok( "steal succeeded",$self->{url} );
    } else {
      return $self->dav->err( 'ERR_RESP_FAIL',$resp->message(),$self->{url} );
    }
}

=head2 lockdiscovery

Same options as C<HTTP::DAV::Response>'s C<lockdiscovery>.

=cut

sub lockdiscovery {
    my $self = shift;
    my $resp = $self->_do_on_dav('lockdiscovery', @_);
}

=head2 forcefully_unlock_all 

Same options as C<HTTP::DAV::Response>'s C<forcefully_unlock_all>.

=cut

sub forcefully_unlock_all {
    my $self = shift;
    $self->_do_on_dav('forcefully_unlock_all', @_);
}


sub _do_on_dav {
    my $self = shift;
    my $meth = shift;
    my $url  =     $self->{url};
    my $res  = $self->dav->new_resource( -uri => $url );
    $res->$meth(@_);
}

=head2 dav [HTTP::DAV]

Get the underlying C<HTTP::DAV> object or, alterntively, replace it with 
a a new one.

=cut

sub dav {
    my $self = shift;
    if (@_) {
        $self->{_dav} = shift;
    }    
    return $self->{_dav};
}

=head2 cal 

Get the underlying cal object

=cut

sub cal {
    my $self = shift;
    if (!defined $self->{_cal}) {
        my $ret = $self->get || die "Couldn't autofetch calendar: ".$self->dav->message;
    }
    return $self->{_cal};
}

=head2 auto_commit [boolean]

Whether to auto save on desctruction or not.

Defaults to 0.

=cut

sub auto_commit {
    my $self = shift;
    if (@_) {
        $self->{_auto_commit} = shift;
    }
    return $self->{_auto_commit};

}

=head2 message

Same as C<HTTP::DAV>'s C<message> function.

=cut

sub message {
    my $self = shift;
    return $self->dav->message;
}

=head2 errors

Same as C<HTTP::DAV>'s C<errors> function.

=cut

sub errors {
    my $self = shift;
    return $self->dav->errors;
}
use Carp qw(croak confess cluck);

our $AUTOLOAD;
sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*://;   # strip fully-qualified portion
    # TODO should we cache this in a glob?
    $self->cal->$method(@_) 
}


sub DESTROY {
    my $self = shift;
    $self->save if $self->auto_commit; 
}

=head2 get_hrefs

Get the hrefs from a property.

=cut

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

=head2 get_calendar_home

Returns the uri for calendar-home-set of a dav address.

=cut

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

=head2 get_calendars

Returns the URIs for the calendars in a collection.

=cut

sub get_calendars {
    my $self = shift;
    my ($url) = @_;
    
    my $res = $self->dav->new_resource( -uri => $url );
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
        if ($res_c->get_property('resourcetype') =~ /calendar/) { # This needs an update in HTTP::DAV::Resource
            push @retval, $res_c->get_uri;
        }
    }
    return @retval;
}


=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>, Bjørn-Olav Strand <bo@startsiden.no>

=head1 COPYRIGHT

Copyright 2007-2010, Simon Wistow & ABC Startsiden AS

Released under the same terms as Perl itself.

=head1 SEE ALSO

L<HTTP::DAV>

L<Data::ICal>

http://tools.ietf.org/html/rfc4791

=cut

1;
