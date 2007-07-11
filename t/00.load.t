#!perl -T
use Test::More tests => 1;

BEGIN {
use_ok( 'Yahoo::Photos' );
}

diag( "Testing Yahoo::Photos $Yahoo::Photos::VERSION" );
