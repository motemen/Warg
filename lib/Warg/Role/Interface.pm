package Warg::Role::Interface;
use Any::Moose '::Role';

requires qw(say ask interact);

with any_moose 'X::Getopt::Strict';

1;
