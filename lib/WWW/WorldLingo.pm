package WWW::WorldLingo;
use base qw( Class::Accessor::Fast );
use strict;
use warnings;
use Carp;

our $VERSION  = "0.01";

__PACKAGE__->mk_accessors(qw( server
                              api agent mimetype encoding
                              subscription password 
                              srclang trglang srcenc trgenc
                              dictno gloss
                              data
                              ));

__PACKAGE__->mk_ro_accessors(qw( error error_code ));

use HTTP::Request::Common;
use LWP::UserAgent;
use HTML::TokeParser;

use constant ERROR_CODE_HEADER => "X-WL-ERRORCODE";

my %Errors = (
              0    => "Successful", # no error
              6    => "Subscription not paid",
              26   => "Incorrect password",
              28   => "Source language not in subscription",
              29   => "Target language not in subscription",
              176  => "Invalid language pair",
              177  => "No input data",
              502  => "Invalid Mime-type",
              1176 => "Translation timed out",
              );


sub new : method {
    my ( $class, $arg_hashref ) = @_;
    my $self = $class->SUPER::new({
                                   subscription =>"S000.1",
                                   password => "secret",
                                   server => "http://www.worldlingo.com/",
                                   %{$arg_hashref || {}},
                                  });

    $self->api( $self->server . $self->subscription() . "/api");

    unless ( $self->agent )
    {
        eval { require LWPx::ParanoidAgent; };
        my $agent_class = $@ ? "LWP::UserAgent" : "LWPx::ParanoidAgent";
        my $ua = $agent_class->new(agent => __PACKAGE__ ."/". $VERSION);
        $self->agent($ua);
    }
    $self;
}

sub translate : method {
    my ( $self, $data ) = @_;
    $self->{_error} = $self->{_error_code} = undef;

    $self->data($data) if $data;

    my $request = POST $self->api, scalar $self->_arguments;

    my $response = $self->agent->request($request);

    my $error_code = $response->header(ERROR_CODE_HEADER);

    if ( $response->is_success and $Errors{$error_code} eq "Successful" )
    {
        return $response->decoded_content;
    }
    elsif ( $error_code ) # API error
    {
        $self->{_error} = $Errors{$error_code} || "Unknown error!";
        $self->{_error_code} = $error_code;
    }
    elsif ( not $response->is_success  ) # Agent error
    {
        $self->{_error} = $response->status_line || "Unknown error!";
        $self->{_error_code} = $response->code;
    }
    else # this is logically impossible to reach
    {
        confess "Unhandled error";
    }
    return;
}

sub _arguments : method {
    my $self = shift;
    my @uri = ( "wl_errorstyle", 1 );

    croak "No data given to translate" unless $self->data =~ /\w/;
    croak "No srclang set" unless $self->srclang;
    croak "No trglang set" unless $self->trglang;


    for my $arg ( qw( password srclang trglang mimetype srcenc trgenc
                      data dictno gloss) )
    {
        next unless $self->$arg;
        push @uri, "wl_$arg", $self->$arg(); # arg pairs for HRC::POST
    }
    return wantarray ? @uri : \@uri; # HRC::POST handles encoding args
}


1;

__END__

=head1 NAME

WWW::WorldLingo - tie into WorldLingo's subscription based translation service.

=head1 VERSION

0.01

=head1 SYNOPSIS

 use WWW::WorldLingo;
 my $wl = WWW::WorldLingo->new();
 $wl->srclang("en");
 $wl->trglang("it");
 my $italian = $wl->translate("Hello world")
    or die $wl->error;
 print $italian, "\n";

=head1 DESCRIPTION

This module makes using WorldLingo's translation API simple. The
service is subscription based. They do not do free translations except
as randomly chosen test translations; e.g., you might get back
Spanish, German, Italian, etc but you won't know which till it's
returned. Maximum of 25 words for tests.

If you are not a subscriber, this module is mostly useless.


=head1 INTERFACE 

=head3 See the WorldLingo API docs for clarification

=over 4

=item $wl = WWW::WorldLingo->new(\%opt)

Create a WWW::WorldLingo object. Can accept any of its attributes as
arguments. Defaults to the test account WorldLingo provides.

=item $wl->data

Set/get the string (src) to be translated. You can use the
C<translate> method to feed the object its src data too.

=item $wl->translate([$data])

Perform the translation of the data and return the result (trg).
Accepts new data so the object can be reused easily.

If nothing is returned, there was an error. Errors can either be set
by the API -- you did something wrong in your call or they have a
problem -- or the requesting agent -- you have some sort of connection
issues.

=item $wl->error

A text string of the error.

=item $wl->error_code

The code of the error. If it's from WorldLingo, it's a proprietary
number. If it's from the user agent, it's the HTTP status code.

=item $wl->api

The URI for service calls.

=item $wl->agent

The web agent. Tries to use L<LWPx::ParanoidAgent>. Falls back to
L<LWP::UserAgent>. You can provide your own as long as it's a subclass
of L<LWP::UserAgent> (like L<WWW::Mechanize>) or a class which offers
the same hooks into the L<HTTP::Request>s and L<HTTP::Response>s.

You will save a little overhead if you provide your agent when you
construct your object. That will prevent the default from being
created. You can override or change agents at any time.

=item $wl->mimetype

=item $wl->encoding

=item $wl->subscription

Your WorldLingo subscription ID. The default is their test account,
C<S000.1>.

=item $wl->password

Your WorldLingo password. The default is for their test account,
C<secret>.

=item $wl->srclang

The language your origial data is in.

=item $wl->trglang

The language you want returned as translated.

=item $wl->srcenc

The encoding of your original language.

=item $wl->trgenc

The encoding you want back for your translated text.

=item $wl->dictno

WorldLingo allows paid users to build their own dictionaries to
deal with custom terminology and filtering.

=item $wl->gloss

WorldLingo has special glossaries to try to improve translation
quality.

=back


=head1 DIAGNOSTICS

See L<HTTP::Status> for error codes thrown by the agent. Here is a
short list of WorldLingo diagnostics.

 Error code   Error
      0       Successful
     26       Incorrect password
     28       Source language not in subscription
     29       Target language not in subscription
    176       Invalid language pair
    177       No input data
    502       Invalid Mime-type
   1176       Translation timed out

Access this information after a failed C<translation> request with
C<error_code> and C<error>.


=head1 DEPENDENCIES

L<HTTP::Request::Common>, L<LWP::UserAgent>, L<Carp>, an Internet
connection.


=head1 TO DO

Better tests. Very little of the real object is being looked at by the
tests right now.

Get the API from WorldLingo that comes with a subscription account to
fill in the blanks.

Support for multiple requests at once, partitioned in XHTML so they
can be separated back out on return.

Docs for the Mime stuff.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-www-worldlingo@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Ashley Pond V, C<< <ashley@cpan.org> >>.


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Ashley Pond V.

This module is free software; you can redistribute it and modify it
under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

Because this software is licensed free of charge, there is no warranty
for the software, to the extent permitted by applicable law. Except when
otherwise stated in writing the copyright holders and/or other parties
provide the software "as is" without warranty of any kind, either
expressed or implied, including, but not limited to, the implied
warranties of merchantability and fitness for a particular purpose. The
entire risk as to the quality and performance of the software is with
you. Should the software prove defective, you assume the cost of all
necessary servicing, repair, or correction.

In no event unless required by applicable law or agreed to in writing
will any copyright holder, or any other party who may modify and/or
redistribute the software as permitted by the above licence, be
liable to you for damages, including any general, special, incidental,
or consequential damages arising out of the use or inability to use
the software (including but not limited to loss of data or data being
rendered inaccurate or losses sustained by you or third parties or a
failure of the software to operate with any other software), even if
such holder or other party has been advised of the possibility of
such damages.

