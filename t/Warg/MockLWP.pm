package t::Warg::MockLWP;
use strict;
use warnings;
use Test::More;
use Path::Class;

our $Root = file(__FILE__)->dir->parent->parent->absolute;

require LWP::UserAgent;

no warnings 'redefine';

*LWP::UserAgent::simple_request = sub {
    my ($self, $request, $content_cb) = @_;

    $request = $self->prepare_request($request);

    note '[MockLWP] ' . $request->method . ' ' . $request->uri;

    my $base = $request->uri;
    $base =~ s<^https?://><>;
    $base =~ s</><\$>g;
    $base =~ s<\?><\$>g;

    my $file = $Root->file(qw(t samples http), $request->method . '_' . $base);
    if (!-r $file) {
        $file = $Root->file(qw(t samples http), $base);
    }

    my $fh = $file->openr;
    # open my $fh, '<', $file or die "open $file: $!";

    require HTTP::Response;

    my $res = HTTP::Response->parse(do { local $/; <$fh> });
    $res->request($request);

    if (ref $content_cb eq 'CODE') {
        $content_cb->($res->content, $res, undef); # XXX no protocol
    }

    $self->run_handlers(response_done => $res);

    return $res;
};

1;
