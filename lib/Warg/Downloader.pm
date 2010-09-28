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
    is  => 'ro',
    isa => 'Warg::IRC::Client',
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
    isa => 'WWW::Mechanize',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

sub from_script {
    my ($class, $script) = @_;
    return $class->new(script => $script);
}

sub work {
    my ($self, $url) = @_;
    my $code = $self->code;
    return $self->$code($url);
}

1;
