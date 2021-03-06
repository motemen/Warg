package Warg::Downloader;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

# is
# - downloader, session
# has
# - coderef to execute
# - interface
# - mech
# does
# - download file
# - interact with human via interface

with 'Warg::Role::Log';

has code => (
    is  => 'ro',
    isa => 'CodeRef',
    required => 1
);

our $id = 0;

has id => (
    is  => 'rw',
    isa => 'Int',
    default => sub { ++$id },
);

has mech => (
    is  => 'rw',
    isa => 'Warg::Mech',
    default => sub {
        require Warg::Mech;
        return  Warg::Mech->new(downloader => $_[0]);
    },
);

has interface => (
    is => 'rw',
    default => sub {
        require Warg::Interface::Console;
        return  Warg::Interface::Console->new;
    },
);

has args => (
    is  => 'rw',
    isa => 'Maybe[HashRef]',
);

has download_dir => (
    is  => 'rw',
    isa => 'Path::Class::Dir',
    coerce  => 1,
    default => './downloads',
);

has metadata => (
    is  => 'rw',
    isa => 'Warg::Downloader::Metadata',
);

## status

has url => (
    is  => 'rw',
    isa => 'Str',
);

has coro => (
    is  => 'rw',
    isa => 'Coro',
);

has status => (
    is  => 'rw',
    isa => 'Str',
    default => sub { '' },
);

has started_at => (
    is  => 'ro',
    isa => 'Int',
    default => sub { time },
);

# $self->download($url) を使っている限りは
# $self->filname, bytes_total, bytes_received は勝手に更新される
# そうでない場合は自力で更新する必要あり

has filename => (
    is  => 'rw',
    isa => 'Str',
    trigger => sub {
        my $self = shift;
        $self->say('filename: ' . $self->filename);
    },
);

has bytes_total => (
    is  => 'rw',
    isa => 'Int',
    trigger => sub {
        my ($self, $value) = @_;
        if (defined $self->{bytes_received} && defined $value) {
            $self->progress($self->{bytes_received} / $value);
        }
    }
);

has bytes_received => (
    is  => 'rw',
    isa => 'Int',
    trigger => sub {
        my ($self, $value) = @_;
        if (defined $value && defined $self->{bytes_total}) {
            $self->progress($value / $self->{bytes_total});
        }
    }
);

# bytes_total, bytes_received が分からない場合にこれを更新してもよい

has progress => (
    is  => 'rw',
    isa => 'Num',
);

around log => sub {
    my ($orig, $self, @args) = @_;
    if ($args[0] =~ /^(?:notice|warn|error|crit)$/) {
        $self->status("$args[0]: @args[1..$#args]");
    }
    $self->$orig(@args);
};

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent;
use Coro;
use Coro::LWP;
use Coro::AnyEvent;
use Coro::Timer;
use Guard;
use Cwd qw(getcwd);
use Carp;
use File::Util qw(escape_filename);

{
    # http://limilic.com/entry/n8mqybjxwsu6y3w2
    # Coro::LWP が $ua->timeout を見るようにする

    no warnings 'redefine';
    my $ORIGINAL_send_request = \&LWP::UserAgent::send_request;

    *LWP::UserAgent::send_request = sub {
        my ($self, $req, @args) = @_;

        my $res;
        my $coro; $coro = async {
            my $w; $w = $self->timeout && AE::timer($self->timeout, 0, sub { undef $w; $coro->cancel });
            $res = $self->$ORIGINAL_send_request($req, @args);
        };
        $coro->join;

        return $res || LWP::UserAgent::_new_response($req, 500, 'Coro timeout');
    };
}

sub metadata_class {
    my $class = shift;

    require Warg::Downloader::Metadata;
    return 'Warg::Downloader::Metadata';
}

sub from_script {
    my ($class, $script, %args) = @_;
    my $meta = $class->metadata_class->new(script => $script);
    return $meta->new_downloader(%args);
}

sub work_sync {
    my ($self, $url) = @_;

    croak 'missing url' unless $url;

    $self->url($url);

    my $ret = eval { $self->code->($self, $url) };

    do {
        if (!defined $ret && $@) {
            $self->log(error => $@);
        }

        if (ref $ret eq 'AnyEvent::CondVar') {
            $ret->cb(rouse_cb);
            $ret = rouse_wait;
        }
    } while (ref $ret eq 'AnyEvent::CondVar');

    return $ret;
}

sub work {
    my ($self, $url, $cb) = @_;

    $self->{coro} = async {
        $self->work_sync($url);
        # $self->say('finished');
        $self->log(notice => "finished $url");
        $cb->() if $cb;
    };
}

sub cancel {
    my $self = shift;
    $self->coro->cancel if $self->coro;
}

sub name {
    my $self = shift;
    return sprintf "%s[%d]", $self->metadata->name, $self->id;
}

sub log_name { shift->name };

sub say {
    my ($self, @args) = @_;
    $self->log(notice => @args);
    $self->interface->say($self->name . " @args", $self->args ? $self->args : ());
}

sub ask {
    my ($self, $prompt) = @_;
    return $self->interface->ask($self->name . " $prompt", $self->args ? $self->args : ());
}

sub sleep {
    my ($self, $seconds) = @_;
    $self->say("sleep for $seconds seconds");
    Coro::Timer::sleep $seconds;
}

sub prepare_request {
    my ($self, $req) = @_;
    $self->log(debug => $req->method, $req->uri);
}

sub chdir_to_download_dir {
    my $self = shift;

    my $cwd = getcwd;

    $self->download_dir->mkpath;
    chdir $self->download_dir;

    return guard { chdir $cwd };
}

sub download {
    my ($self, $url, $option) = @_;

    $option ||= {};

    my $guard = $self->chdir_to_download_dir;

    $self->say("start downloading <$url>");
    $self->mech->timeout(0);

    my ($filename, $fh);
    $self->mech->set_my_handler(
        response_data => sub {
            my ($res, $ua, $h, $data) = @_;

            unless (defined $self->bytes_total) {
                my $h = $res->headers;
                $self->bytes_total($h && $h->header('Content-Length') || 0);
            }

            unless (defined $fh) {
                $filename = $res->filename || $url;
                $filename = $option->{prefix} . $filename if defined $option->{prefix};
                $filename = escape_filename $filename;

                $self->filename($filename);

                open $fh, '>', $filename or die $!;
                $self->log(info => "filename: $filename");
            }

            print $fh $data;

            $self->bytes_received(0) unless $self->bytes_received;
            $self->{bytes_received} += length $data;

            return 1;
        }
    );

    my $res = $self->mech->get($url);
    $self->mech->set_my_handler(response_data => undef);
    close $fh if defined $fh;

    if ($res->is_success) {
        $self->say("downloaded $filename");
    } else {
        $self->log(error => 'download failed: ' . $res->message);
    }
}

## status

sub status_string {
    my $self = shift;
    return sprintf '%s %s <%s> %s', 
        map { defined $_ ? $_ : 'N/A' }
            $self->name, $self->filename, $self->url, $self->formatted_progress;
}

sub elapsed { time - $_[0]->started_at }

sub formatted_progress {
    my $self = shift;

    my $total = $self->bytes_total;
    my $received = $self->bytes_received;

    my $status = '';

    my $progress = $self->progress;
    if (defined $received) {
        if (defined $total) {
            $status .= "$received/$total";
            $progress = $received / $total unless defined $progress;
        } else {
            $status .= "$received/?";
        }
    } else {
        $status .= '-';
    }

    $status .= sprintf ' (%.1f%%)', $progress * 100 if defined $progress;

    return $status;
}

sub as_serializable_hash {
    my $self = shift;
    return {
        map {
            $_ => $self->$_
        } qw(id name filename url status bytes_total bytes_received progress formatted_progress)
    };
}

1;
