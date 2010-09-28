package Warg::Downloader;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

has script => (
    is  => 'ro',
    isa => 'Path::Class::File',
    coerce   => 1,
    required => 1,
);

has client => (
    is  => 'rw',
    isa => 'Warg::IRC::Client',
);

has logger => (
    is  => 'rw',
    isa => 'Log::Handler',
);

has code => (
    is  => 'ro',
    isa => 'CodeRef',
    lazy_build => 1,
);

sub _build_code {
    my $self = shift;

    (my $pkg = $self->script) =~ s/\W/_/g;

    my $code = eval "package $pkg;\n" . scalar $self->script->slurp;
    die $@ if $@;

    return $code;
}

has mech => (
    is  => 'rw',
    isa => 'Warg::WWW::Mechanize',
    default => sub { Warg::WWW::Mechanize->new },
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Coro;
use AnyEvent;
use Coro::AnyEvent;
use HTTP::Request::Common;

sub from_script {
    my ($class, $script) = @_;
    return $class->new(script => $script);
}

sub work {
    my ($self, $url) = @_;
    async {
        $self->code->($self, $url);
    };
}

sub log {
    my ($self, $level, @args) = @_;
    if (my $logger = $self->logger) {
        $logger->log($level, @args);
    }
}

sub prompt {
    my ($self, $prompt) = @_;

    local $| = 1;
    print "$prompt: ";

    my $w = AE::io *STDIN, 0, Coro::rouse_cb;
    Coro::rouse_wait;

    chomp (my $res = <STDIN>);
    return $res;
}

sub download {
    my ($self, $url) = @_;
    my $fh;
    my $res = $self->mech->get($url, ':content_cb' => sub {
        my ($data, $res) = @_;
        warn length $data;
        warn $data;
        unless (defined $fh) {
            my $filename = $res->filename || $url;
            $filename =~ s/[^\w\.]/_/g;
            open $fh, '>', $filename;
        }
        print $fh $data;
    });
use Data::Dumper;
    warn Data::Dumper->new([$res])->Indent(1)->Dump;
}

package Warg::WWW::Mechanize;
use base 'WWW::Mechanize';
use HTML::TreeBuilder::XPath;

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

sub agent {
    'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.3 (KHTML, like Gecko) Chrome/6.0.472.62 Safari/534.3';
}

1;
