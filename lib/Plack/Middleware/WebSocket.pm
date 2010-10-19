package Plack::Middleware::WebSocket;
use strict;
use warnings;
use parent 'Plack::Middleware';

sub call {
    my ($self, $env) = @_;

    $env->{'websocket.impl'} = Plack::Middleware::WebSocket::Impl->new($env);

    return $self->app->($env);
}

package Plack::Middleware::WebSocket::Impl;
use Plack::Util::Accessor qw(env error_code error_msg);
use Scalar::Util qw(weaken);
use Digest::MD5 qw(md5);
use AnyEvent::Handle;

sub new {
    my ($class, $env) = @_;
    weaken $env;
    return bless { env => $env }, $class;
}

sub handshake {
    my ($self, $respond) = @_;

    my $env = $self->env;

    unless ($env->{HTTP_CONNECTION} eq 'Upgrade' && $env->{HTTP_UPGRADE} eq 'WebSocket') {
        $self->error_code(400);
        return;
    }

    my $fh = $env->{'psgix.io'};
    unless ($fh) {
        $self->error_code(501);
        $self->error_msg('This server does not support psgix.io extention');
        return;
    }

    my $key1 = $env->{'HTTP_SEC_WEBSOCKET_KEY1'};
    my $key2 = $env->{'HTTP_SEC_WEBSOCKET_KEY2'};
    my $n1 = join '', $key1 =~ /\d+/g;
    my $n2 = join '', $key2 =~ /\d+/g;
    my $s1 = $key1 =~ y/ / /;
    my $s2 = $key2 =~ y/ / /;
    $n1 = int($n1 / $s1);
    $n2 = int($n2 / $s2);

    my $len = read $fh, my $chunk, 8;
    unless (defined $len) {
        $self->error_code(500);
        $self->error_msg("read: $!");
    }

    my $string = pack('N', $n1) . pack('N', $n2) . $chunk;
    my $digest = md5 $string;

    my $handle = AnyEvent::Handle->new(fh => $fh);
    $handle->push_write(join "\015\012", (
        'HTTP/1.1 101 Web Socket Protocol Handshake',
        'Upgrade: WebSocket',
        'Connection: Upgrade',
        "Sec-WebSocket-Origin: $env->{HTTP_ORIGIN}",
        "Sec-WebSocket-Location: ws://$env->{HTTP_HOST}$env->{SCRIPT_NAME}$env->{PATH_INFO}",
        '',
        $digest,
    ));
    return $handle;
}

1;
