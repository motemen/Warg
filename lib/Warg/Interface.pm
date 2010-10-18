package Warg::Interface;
use Any::Moose;

with any_moose 'X::Getopt::Strict';

sub say {
    my $self  = shift;
    my $class = ref $self;
    warn "$class\::say not implemented";
}

sub ask {
    my $self  = shift;
    my $class = ref $self;
    warn "$class\::ask not implemented";
    return undef;
}

sub interact {
    my $self  = shift;
    my $class = ref $self;
    warn "$class\::interact not implemented";
}

1;
