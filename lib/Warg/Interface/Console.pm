package Warg::Interface::Console;
use Any::Moose;

extends 'Warg::Interface';

has show_prompt => (
    is  => 'rw',
    isa => 'Bool',
    default => 1,
);

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

# XXX 外から終了させることができないといけない
sub interact {
    my ($self, $cb) = @_;

    local $| = 1;
    print 'warg> ' if $self->show_prompt;

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

        print 'warg> ' if $self->show_prompt;
    };

    $cv->wait;
}

1;
