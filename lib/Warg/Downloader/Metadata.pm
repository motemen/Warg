package Warg::Downloader::Metadata;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

has script => (
    is  => 'ro',
    isa => 'Path::Class::File',
    coerce   => 1,
    required => 1,
);

has http_config => (
    is  => 'rw',
    # isa => 'Maybe[HTTP::Config]',
);

has code => (
    is  => 'rw',
    isa => 'CodeRef',
);

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
    $self->{http_config} = do { no strict 'refs'; ${"$pkg\::Config"} };
}

# TODO HTTP::Config 微妙に使いづらいのでなんぞ適当に
sub handles_res {
    my ($self, $res) = @_;

    return 0 unless $self->http_config;

    if (ref $self->http_config eq 'HTTP::Config') {
        return $self->http_config->matching($res);
    } elsif (ref $self->http_config eq 'Regexp') {
        return $res->base =~ $self->http_config;
    }
}

sub new_downloader {
    my ($self, %args) = @_;
    return Warg::Downloader->new(
        %args,
        code => $self->code,
    );
}

1;
