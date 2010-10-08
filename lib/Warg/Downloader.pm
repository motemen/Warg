package Warg::Downloader;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

# is
# - downloader, session
# has
# - coderef to execute
# - interface
# - mech
# does
# - download file
# - interact with human via interface

with 'Warg::Role::Log';

has code => (
    is  => 'ro',
    isa => 'CodeRef',
    required => 1
);

our $id = 0;

has id => (
    is  => 'rw',
    isa => 'Int',
    default => sub { ++$id },
);

has mech => (
    is  => 'rw',
    isa => 'Warg::Mech',
    default => sub {
        return Warg::Mech->new;
    },
);

has interface => (
    is => 'rw',
    default => sub {
        require Warg::Interface::Console;
        return  Warg::Interface::Console->new;
    },
);

has args => (
    is  => 'rw',
    isa => 'Maybe[HashRef]',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Warg::Mech;

use AnyEvent;
use Coro;
use Coro::LWP;
use Coro::AnyEvent;
use Carp;
use File::Util qw(escape_filename);

sub metadata_class {
    my $class = shift;

    require Warg::Downloader::Metadata;
    return 'Warg::Downloader::Metadata';
}

sub from_script {
    my ($class, $script, %args) = @_;
    my $meta = $class->metadata_class->new(script => $script);
    return $meta->new_downloader(%args);
}

sub work_sync {
    my ($self, $url) = @_;
    $self->code->($self, $url);
}

sub work {
    my $self = shift;
    my $url  = shift or croak 'missing url';

    async {
        $self->work_sync($url);
    };
}

sub log_name {
    return "Downloader[$_[0]{id}]";
}

sub say {
    my ($self, @args) = @_;
    $self->log(notice => @args);
    $self->interface->say("@args", $self->args);
}

sub ask {
    my ($self, $prompt) = @_;
    return $self->interface->ask($prompt, $self->args);
}

sub prepare_request {
    my ($self, $req) = @_;
    $self->log(debug => $req->method, $req->uri);
}

sub download {
    my ($self, $url, $option) = @_;

    $option ||= {};

    $self->say("start downloading <$url>");

    my ($filename, $fh);
    my $res = $self->mech->get($url, ':content_cb' => sub {
        my ($data, $res) = @_;
        unless (defined $fh) {
            $filename = $res->filename || $url;
            $filename = $option->{prefix} . $filename if defined $option->{prefix};
            $filename = escape_filename $filename;

            open $fh, '>', $filename or die $!;
            $self->log(info => "filename: $filename");
        }
        print $fh $data;
    });
    close $fh if defined $fh;

    $self->say("downloaded $filename");
}

1;
