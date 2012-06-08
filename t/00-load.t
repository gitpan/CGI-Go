#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'CGI::Go' ) || print "Bail out!\n";
}

diag( "Testing CGI::Go $CGI::Go::VERSION, Perl $], $^X" );
