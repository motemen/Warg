package Warg::Downloader::Metadata;
use Any::Moose;

has script => (
    is  => 'ro',
    isa => 'Path::Class::File',
    coerce   => 1,
    required => 1,
);

has http_config => (
    is  => 'rw',
    isa => 'Maybe[HTTP::Config]',
    lazy_build => 1,
);

sub _build_http_config {
    my $self = shift;

    (my $pkg = $self->script) =~ s/\W/_/g;
    my $code = $self->script->slurp;
    my $sub  = eval qq{ package $pkg; $code };
    die $@ if $@;

    no strict 'refs';
    return ${"$pkg\::Config"};
}

no Any::Moose;

__PACKAGE__->meta->make_immutable;

1;
