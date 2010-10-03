package Warg::Downloader::Interface::Console;
use Any::Moose;
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

1;
