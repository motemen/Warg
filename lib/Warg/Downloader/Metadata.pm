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
    isa => 'Maybe[HTTP::Config]',
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

sub handles_res {
    my ($self, $res) = @_;
    return 0 unless $self->http_config;
    return $self->http_config->matching($res);
}

sub new_downloader {
    my ($self, %args) = @_;
    return Warg::Downloader->new(
        %args,
        code => $self->code,
    );
}

1;
