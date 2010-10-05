package t::Warg::MockLWP;
use strict;
use warnings;
use Test::More;

require LWP::UserAgent;

no warnings 'redefine';

*LWP::UserAgent::simple_request = sub {
    my ($self, $request, $content_cb) = @_;

    $request = $self->prepare_request($request);

    note '[MockLWP] ' . $request->method . ' ' . $request->uri;

    my $file = $request->uri;
    $file =~ s<^https?://><>;
    $file =~ s</><\$>g;
    $file = "t/samples/http/$file";

    open my $fh, '<', $file;

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
