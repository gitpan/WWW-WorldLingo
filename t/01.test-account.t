use Test::More "no_plan";
# use Test::More tests => 1;
use WWW::WorldLingo;

ok( my $wl = WWW::WorldLingo->new,
    "WWW::WorldLingo->new");
ok( $wl->srclang("en"),
    "Setting srclang to 'en'");
ok( $wl->trglang("it"),
    "Setting trglang to 'it'");
ok( $wl->data("Hello world"),
    "Setting data to 'Hello world'");
is( $wl->api(), "http://www.worldlingo.com/S000.1/api",
    "API address is correct");

# Check if we have internet connection
require IO::Socket;
my $s = IO::Socket::INET->new(PeerAddr => "www.google.com:80",
                              Timeout  => 10,
                             );
if ($s) {
    close($s);
    if ( $ENV{WORLDLINGO_TEST} )
    {
        ok( my $result = $wl->translate() );
        diag( $result );
    }
    else
    {
        diag <<EOT;
You appear to be directly connected to the Internet. If you would like
to run the live test calls to the WorldLingo API server set your
envirnoment variable WORLDLINGO_TEST to a true value and rerun this
test.
EOT
    }

}


# use Data::Dumper; print Dumper $wl;

=pod

Bonjour monde
Hallo Welt
Hello mundo
Hola mundo
Ciao mondo

=cut

