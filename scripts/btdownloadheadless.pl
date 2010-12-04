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

    my $s = $self->chdir_to_download_dir;

    my $filename;

    # TODO ここは Downloader の API で
    my ($r, $w) = map { unblock $_ } portable_pipe;
    my $cv = run_cmd [ 'btdownloadheadless', $url, '--display_interval', 5, split / /, ($ENV{WARG_BTDOWNLOADHEADLESS_ARGS} || '') ],
        '>'  => sub { $w->print($_[0]) },
        '$$' => \my $pid;

    $self->log(notice => "btdownloadheadless: $pid");

    while (local $_ = $r->readline) {
        $self->log(debug => $_);

        if (/^ERROR:/) {
            die "failed: $_";
        }

        if (/^saving:\s+(.+)/ && !defined $filename) {
            $filename = $1;
            $filename =~ s/\s*\([^\(\)]+?\)$//;
            $self->filename($filename);
        }
        elsif (/^time left:\s+Download Succeeded!/) {
            $self->say("downloaded: $filename");
            $self->sleep(3);
            $self->log(notice => "sending HUP to $pid");
            kill 'HUP', $pid;
            last;
        }
        elsif (/^percent done:\s+(\d+(?:\.\d+))\s*$/) {
            # $self->say($_);
            $self->progress($1 / 100);
        }
    }

    # TODO ここも Downloader の API で
    $cv->cb(rouse_cb);

    return rouse_wait;
};
