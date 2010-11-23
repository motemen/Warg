use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use Text::MicroTemplate::File;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Getopt::Long;
use Path::Class;

GetOptions
    'control-socket|C=s' => \my $socket;

my ($host, $port) = $socket =~ /^(.*):(\d+)$/ ? ($1, $2) : ('unix/', $socket);

my $mtf = Text::MicroTemplate::File->new(
    include_path => [ file(__FILE__)->dir->stringify ],
    use_cache    => 1,
);

# connect
my $handle_cv = AE::cv;

tcp_connect $host, $port, sub {
    my $fh = shift
        or die "Could not connect to ($host, $port): $!";
    $handle_cv->send(AnyEvent::Handle->new(fh => $fh));
};

my $handle = $handle_cv->recv or die;

my $app = sub {
    my $env = shift;
    $env->{'psgi.streaming'} or die;

    $handle->push_write("jobs\r\n");

    return sub {
        my $respond = shift;

        $handle->push_read(json => sub {
            my $api_result = $_[1];

            my $req = Plack::Request->new($env);
            my $res = $req->new_response(200);
            $res->content_type('text/html');
            $res->content($mtf->render_file('index.mt', result => $api_result));

            $respond->($res->finalize);
        });
    };
};

$app;
