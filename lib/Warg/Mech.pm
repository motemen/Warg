package Warg::Mech;
use base 'WWW::Mechanize';
use HTML::TreeBuilder::XPath;
use Scalar::Util qw(weaken);

sub new {
    my ($class, %args) = @_;

    my $downloader = delete $args{downloader};
    my $logger     = delete $args{logger};

    my $self = $class->SUPER::new(%args);
    $self->{downloader} = $downloader;
    $self->{logger}     = $downloader->logger if $downloader;

    $self->add_handler(
        request_send => sub {
            my ($req) = @_;
            $self->log(debug => $req->method, $req->uri);
            return;
        },
    );
    $self->add_handler(
        response_data => sub {
            my ($res) = @_;
            $self->log(debug => $res->request->uri, $res->code, $res->content_type);
            return;
        },
    );

    return $self;
}

sub prepare_request {
    my ($self, $req) = @_;

    $req->headers->init_header(
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
