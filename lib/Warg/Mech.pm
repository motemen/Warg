package Warg::Mech;
use strict;
use warnings;
use base 'WWW::Mechanize';
use HTML::TreeBuilder::XPath;
use Scalar::Util qw(weaken);
use Guard ();
use Carp;
use LWPx::ParanoidAgent;

# XXX LWPx::ParanoidAgent does not support add_handler() ?
# BEGIN {
#     @WWW::Mechanize::ISA = qw(LWPx::ParanoidAgent);
# }

our $log_fh;

if ($ENV{WARG_MECH_NO_ZLIB}) {
    $WWW::Mechanize::HAS_ZLIB = 0;
}

if (my $log = $ENV{WARG_MECH_LOG}) {
    open $log_fh, '>', "$log.${\time}.$$";
    $log_fh->autoflush(1);
}

sub new {
    my ($class, %args) = @_;

    my $downloader = delete $args{downloader};
    my $logger     = delete $args{logger};

    my $self = $class->SUPER::new(%args);
    $self->{downloader} = $downloader;
    $self->{logger}     = $logger || ($downloader && $downloader->logger);

    $self->setup_handlers;

    return $self;
}

sub setup_handlers {
    my $self = shift;

    $self->add_handler(
        request_send => sub {
            my ($req) = @_;
            $self->log(debug => $req->method, $req->uri);
            return;
        },
    );
    $self->add_handler(
        response_done => sub {
            my ($res) = @_;
            $self->log(debug => $res->request->method, $res->request->uri, '=>', $res->code, $res->content_type);

            if ($log_fh) {
                print $log_fh "@@@ REQUEST @@@\n", $res->request->as_string, "\n";
                if ($res->content_type =~ m(^text/)) {
                    print $log_fh "@@@ RESPONSE @@@\n", $res->as_string, "\n";
                } else {
                    print $log_fh "@@@ RESPONSE HEADER @@@\n", $res->headers->as_string, "\n";
                }
            }

            return;
        },
    );
}

sub prepare_request {
    my ($self, $req) = @_;

    $self->SUPER::prepare_request($req);

    $req->headers->header(
        User_Agent => 'Mozilla/5.0 (Windows; U; Windows NT 6.1; ja; rv:1.9.2.6) Gecko/20100625 Firefox/3.6.6',
    );

    $req->headers->init_header(
        Accept => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    );

    return $req;
}

sub downloader {
    my $self = shift;
    weaken($self->{downloader} = $_[0]) if @_;
    return $self->{downloader};
}

sub logger {
    my $self = shift;
    $self->{logger} = $_[0] if @_;
    return $self->{logger};
}

sub log {
    my $self = shift;
    if ($self->logger) {
        $self->logger->log(@_);
    }
}

sub clone {
    my $self = shift;
    my $cloned = $self->SUPER::clone();
    $cloned->logger($self->logger);
    $cloned->setup_handlers;
    return $cloned;
}

sub tree {
    my $self = shift;
    return $self->{tree} ||= HTML::TreeBuilder::XPath->new_from_content($self->response->decoded_content);
}

sub update_html {
    my ($self, $html) = @_;
    $self->_destroy_tree;
    return $self->SUPER::update_html($html);
}

sub get_basic_credentials {
    my ($self, $realm, $uri, $isproxy) = @_;
    if ($self->downloader) {
        my $user_pass = $self->downloader->ask(qq(Basic auth for '$realm' <$uri>));
        return split /:/, $user_pass;
    }
}

sub no_follow_redirect {
    my $self = shift;
    carp 'no_follow_redirect in void context' unless defined wantarray;

    my $requests_redirectable = $self->requests_redirectable([]);
    return Guard::guard {
        $self->requests_redirectable($requests_redirectable);
    };
}

sub _destroy_tree {
    my $self = shift;
    if (my $tree = delete $self->{tree}) {
        $tree->delete;
    }
}

sub DESTROY {
    my $self = shift;
    local $@;
    $self->_destroy_tree;
}

1;
