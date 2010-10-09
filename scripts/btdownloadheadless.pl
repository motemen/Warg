use strict;
use warnings;
use AnyEvent::Util;
use Coro;
use Coro::Handle;

use HTTP::Config;

our $Config = HTTP::Config->new;
$Config->add(m_media_type => 'application/x-bittorrent');
$Config->add(m_path_match => qr/\.torrent$/);

sub {
    my ($self, $url) = @_;

    my $filename;

    my ($r, $w) = map { unblock $_ } portable_pipe;
    my $cv = run_cmd [ 'btdownloadheadless', $url, '--display_interval', 10 ],
        '>'  => sub { $w->print($_[0]) },
        '$$' => \my $pid;

    while (local $_ = $r->readline) {
        if (/^ERROR:/) {
            die "failed: $_";
        }

        if (/^saving:\s+(.+)/ && !defined $filename) {
            $filename = $1;
        }
        elsif (/^time left:\s+Download Succeeded!/) {
            $self->say("downloaded: $filename");
            $self->sleep(3);
            kill 'HUP', $pid;
            last;
        }
        elsif (/^percent done:\s+(\d+(?:\.\d+))\s*$/) {
            $self->say($_);
        }
    };

    $cv->cb(rouse_cb);

    return rouse_wait;
};
