package Warg::Interface::Console;
use Any::Moose;

with 'Warg::Role::Interface';

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent;
use Coro;

sub say {
    my ($self, $message) = @_;
    print "$message\n";
}

sub ask {
    my ($self, $prompt) = @_;

    local $| = 1;
    print "\n$prompt: ";

    $self->{cb} = rouse_cb;
    my $ans = rouse_wait;
    delete $self->{cb};
    return $ans;
}

sub interact {
    my ($self, $cb) = @_;

    local $| = 1;
    print 'warg> ';

    my $cv = AE::cv;
    my $w = AE::io *STDIN, 0, sub {
        my $line = <STDIN>;

        if (not defined $line) {
            print "\n";
            $cv->send;
            return;
        }

        chomp $line;
        ($self->{cb} || $cb)->($line);

        print 'warg> ';
    };

    $cv->wait;
}

1;
