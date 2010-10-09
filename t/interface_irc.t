use strict;
use warnings;
use Test::More;

use_ok 'Warg::Interface::IRC';

my $i = new_ok 'Warg::Interface::IRC', [
    server   => 'localhost:6667',
];

ok $i->channel_is_to_work_in('#foo');
ok $i->channel_is_to_work_in('#bar');

$i->channels(['#foo']);

ok $i->channel_is_to_work_in('#foo');
ok not $i->channel_is_to_work_in('#bar');

done_testing;
