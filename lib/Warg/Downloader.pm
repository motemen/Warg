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

has script => (
    is  => 'ro',
    isa => 'Path::Class::File',
    coerce   => 1,
);

our $id = 0;

has id => (
    is  => 'rw',
    isa => 'Int',
    default => sub { ++$id },
);

has code => (
    is  => 'ro',
    isa => 'CodeRef',
    lazy_build => 1,
    # required => 1
);

# TODO metadata に移動
sub _build_code {
    my $self = shift;

    (my $pkg = $self->script) =~ s/\W/_/g;

    my $code = $self->script->slurp;
    my $sub  = eval qq{ package $pkg; $code };
    die $@ if $@;
    die 'not a CODE' unless ref $sub eq 'CODE';

    return $sub;
}

has mech => (
    is  => 'rw',
    isa => 'Warg::WWW::Mechanize',
    lazy_build => 1,
);

sub _build_mech {
    my $self = shift;
    my $mech = Warg::WWW::Mechanize->new(downloader => $self);
    $mech->add_handler(
        request_send => sub {
            my ($req) = @_;
            $self->log(debug => $req->method, $req->uri);
            return;
        },
    );
    $mech->add_handler(
        response_data => sub {
            my ($res) = @_;
            $self->log(debug => $res->request->uri, $res->code, $res->content_type);
            return;
        },
    );
    return $mech
}

has interface => (
    is  => 'rw',
    default => sub {
        require Warg::Downloader::Interface::Console;
        return  Warg::Downloader::Interface::Console->new;
    },
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent;
use Coro;
use Coro::LWP;
use Coro::AnyEvent;
use Carp;

sub from_script {
    my ($class, $script, %args) = @_;
    return $class->new(script => $script, %args);
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

# ほんとうは $sef->log するときに $self->interface->say するようにしたい
# TODO Log::Handler::Output::Warg::Downloader::Interface?
sub say {
    my ($self, @args) = @_;
    $self->log(notice => @args);
    $self->interface->say(@args);
}

sub ask {
    my ($self, $prompt) = @_;
    return $self->interface->ask($prompt);
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
            $filename =~ s/[^\w\.-]/_/g;
            $filename = $option->{prefix} . $filename if defined $option->{prefix};

            open $fh, '>', $filename or die $!;
            $self->log(info => "filename: $filename");
        }
        print $fh $data;
    });
    close $fh if defined $fh;

    $self->say("downloaded $filename");
}

package Warg::WWW::Mechanize;
use base 'WWW::Mechanize';
use HTML::TreeBuilder::XPath;
use Scalar::Util qw(weaken);

sub new {
    my ($class, %args) = @_;
    my $downloader = delete $args{downloader};
    my $self = $class->SUPER::new(%args);
    $self->downloader($downloader) if $downloader;
    return $self;
}

sub agent {
    'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.3 (KHTML, like Gecko) Chrome/6.0.472.62 Safari/534.3';
}

sub downloader {
    my $self = shift;
    weaken($self->{downloader} = $_[0]) if @_;
    return $self->{downloader};
}

sub tree {
    my $self = shift;
    return $self->{tree} ||= HTML::TreeBuilder::XPath->new_from_content($self->response->decoded_content);
}

sub update_html {
    my ($self, $html) = @_;
    if (my $tree = delete $self->{tree}) {
        $tree->delete;
    }
    return $self->SUPER::update_html($html);
}

sub DESTROY {
    my $self = shift;
    if (my $tree = delete $self->{tree}) {
        $tree->delete;
    }
}

sub get_basic_credentials {
    my ($self, $realm, $uri, $isproxy) = @_;
    my $user_pass = $self->downloader->ask(qq(Basic auth for '$realm' <$uri>));
    return split /:/, $user_pass;
}

1;
