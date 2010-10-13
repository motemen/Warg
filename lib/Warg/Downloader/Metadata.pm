package Warg::Downloader::Metadata;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

has script => (
    is  => 'ro',
    isa => 'Path::Class::File',
    coerce   => 1,
    required => 1,
);

has config => (
    is  => 'rw',
    isa => 'Warg::Downloader::Config',
);

has code => (
    is  => 'rw',
    isa => 'CodeRef',
);

has name => (
    is  => 'rw',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_name {
    my $self = shift;
    return $self->script->basename;
}

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Warg::Downloader;

sub _eval_script {
    my $self = shift;

    (my $pkg = $self->script) =~ s/\W/_/g;

    my $code = $self->script->slurp;
    my $sub  = eval qq{ package $pkg; $code };
    die $@ if $@;
    die 'script did not return a CODE' unless ref $sub eq 'CODE';

    return ($pkg, $sub);
}

sub BUILD {
    my $self = shift;

    my ($pkg, $sub) = $self->_eval_script;
    $self->{code} = $sub;

    my $config = do { no strict 'refs'; ${"$pkg\::Config"} };
    $self->{config} = Warg::Downloader::Config->new($config);
}

sub handles_res {
    my ($self, $res) = @_;
    return 0 unless $self->config;
    return $self->config->handles_res($res);
}

sub new_downloader {
    my ($self, %args) = @_;
    return Warg::Downloader->new(
        %args,
        code => $self->code,
        metadata => $self,
    );
}

package Warg::Downloader::Config;
use Any::Moose;

has regexp      => ( is => 'rw', isa => 'RegexpRef' );
has http_config => ( is => 'rw', isa => 'HTTP::Config' );

sub BUILDARGS {
    my ($class, @args) = @_;

    if (@args == 1) {
        if (ref $args[0] eq 'Regexp') {
            return { regexp => $args[0] };
        } elsif (ref $args[0] eq 'HTTP::Config') {
            return { http_config => $args[0] };
        }
    }
}

sub handles_res {
    my ($self, $res) = @_;

    if ($self->regexp) {
        return $res->base =~ $self->regexp;
    } elsif ($self->http_config) {
        return $self->http_config->matching($res);
    }
}

1;
