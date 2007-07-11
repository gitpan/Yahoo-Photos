#!perl -T
use strict;
use warnings;
use Test::More tests => 2;
use Yahoo::Photos qw();

my $album = Yahoo::Photos::Album->_new(
    id => 'foo',
);

my $other = Yahoo::Photos::Album->_new(
    name => 'bar',
    id => 'baz',
);

$album->_merge($other);

is $album->name, 'bar', 'name field added';
is $album->id, 'foo', 'old id not overwritten';
