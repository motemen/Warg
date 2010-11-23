use strict;
use warnings;

use HTTP::Config;
use AnyEvent;

our $Config = HTTP::Config->new;
if ($ENV{WARG_DEVEL}) {
    $Config->add(m_host => 'localhost');
}

my @alnum = ('a'..'z','A'..'Z','0'..'9');

sub _random_string ($) {
    my $len = shift;
    return join '', map { $alnum[ int rand scalar @alnum ] } (1 .. $len);
}

sub {
    my ($self, $url) = @_;
    $self->filename(_random_string(8) . '.' . _random_string(3));
    $self->bytes_total(int rand 10_000);
    $self->bytes_received(int $self->bytes_total * rand);

    return AE::cv;
};
