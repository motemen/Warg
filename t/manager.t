use strict;
use warnings;
use Test::More;

use_ok 'Warg::Manager';

my $manager = new_ok 'Warg::Manager', [
    downloader_dir => 'downloader'
];

done_testing;
