package Warg::Interface::Console;
use Any::Moose;

with 'Warg::Role::Interface';

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent;
use Coro::AnyEvent;

sub say {
}

sub ask {
    my ($self, $prompt) = @_;

    local $| = 1;
    print "$prompt: ";

    Coro::AnyEvent::readable *STDIN;

    chomp (my $res = <STDIN>);
    return $res;
}

sub interact {
    my ($self, $cb) = @_;

    local $| = 1;
    while () {
        print 'warg> ';

        Coro::AnyEvent::readable *STDIN;
        my $line = <STDIN>;
        last unless defined $line;

        chomp $line;
        $cb->($line);
    }
}

1;
