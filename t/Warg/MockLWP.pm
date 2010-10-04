package t::Warg::MockLWP;
use strict;
use warnings;
use Test::More;

require LWP::UserAgent;

no warnings 'redefine';

*LWP::UserAgent::simple_request = sub {
    my ($self, $request) = @_;

    $request = $self->prepare_request($request);

    note $request->method . ' ' . $request->uri;

    my $file = $request->uri;
    $file =~ s<^https?://><>;
    $file =~ s</><\$>g;
    $file = "t/samples/http/$file";

    open my $fh, '<', $file;

    require HTTP::Response;

    my $res = HTTP::Response->parse(do { local $/; <$fh> });
    $res->request($request);

    $self->run_handlers(response_done => $res);

    return $res;
};

1;
