package Warg::Interface::WebSocket;
use Any::Moose;

extends 'Warg::Interface';

has port => (
    is  => 'rw',
    isa => 'Int',
    metaclass => 'Getopt',
    default   => 8080,
);

has server => (
    is  => 'rw',
    isa => 'Twiggy::Server',
    lazy_build => 1,
);

sub _build_server {
    my $self = shift;
    return Twiggy::Server->new(
        port => $self->port
    );
}

has handle => (
    is  => 'rw',
    isa => 'AnyEvent::Handle',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Coro;
use Twiggy::Server;
use Plack::Request;
use Plack::Middleware::WebSocket;

sub say {
    my ($self, $message, $args) = @_;
    utf8::encode $message if utf8::is_utf8 $message;
    $self->handle->push_write("\x00$message\xff");
}

sub ask {
    my ($self, $prompt, $args) = @_;

    $self->say($prompt, $args);
    
    my $cb = rouse_cb;
    $self->handle->push_read(
        line => "\xff", sub {
            my $msg = $_[1];
            $msg =~ s/^\x00//;
            $cb->($msg);
        }
    );

    my $reply = rouse_wait $cb;
    return $reply;
}

my $DATA = do { local $/; <DATA> };

sub to_app {
    my ($self, $cb) = @_;

    my $app = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $res = $req->new_response(200);

        if ($req->path eq '/') {
            $res->content_type('text/html; charset=utf-8');
            my $data = $DATA;
            $data =~ s/{{{HOST}}}/$env->{HTTP_HOST}/g;
            $res->content($data);
            return $res->finalize;
        }
        elsif ($req->path eq '/ws') {
            my $handle = $env->{'websocket.impl'}->handshake or do {
                $res->code($env->{'websocket.impl'}->error_code);
                return $res->finalize;
            };

            $self->handle($handle);
            on_read $handle sub {
                $handle->push_read(
                    line => "\xff", sub {
                        my $msg = $_[1];
                        $msg =~ s/^\x00//;
                        $cb->($msg);
                    }
                );
            };

            return sub {
            };
        }
        else {
            $res->code(404);
            return $res->finalize;
        }
    };
    return Plack::Middleware::WebSocket->wrap($app);
}

sub setup {
    my $self = shift;
    $self->server->register_service($self->to_app($cb));
}

sub interact {
    my ($self, $cb) = @_;
    $self->setup;
    AE::cv->wait;
}

1;

__DATA__
<!DOCTYPE html>
<html>
  <head>
    <title>warg</title>
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
    <style type="text/css">
#log {
  border: 1px solid #DDD;
  padding: 0.5em;
}
    </style>
  </head>
  <body>
    <script type="text/javascript">
function log (msg) {
  $('#log').text($('#log').text() + msg + "\n");
}

$(function () {
  var ws = new WebSocket('ws://{{{HOST}}}/ws');

  log('WebSocket start');

  ws.onopen = function () {
    log('connected');
  };

  ws.onmessage = function (ev) {
    log('received: ' + ev.data);
    $('#message').val('');
  };

  ws.onerror = function (ev) {
    log('error: ' + ev.data);
  }

  ws.onclose = function (ev) {
    log('closed');
  }

  $('#form').submit(function () {
    ws.send($('#message').val());
    return false;
  });
});
    </script>
    <form id="form">
      <input type="text" name="message" id="message" />
      <input type="submit" />
    </form>
    <pre id="log"></pre>
  </body>
</html>
