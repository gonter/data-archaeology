#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'DBF::Unknown1' ) || print "Bail out!\n";
}

diag( "Testing DBF::Unknown1 $DBF::Unknown1::VERSION, Perl $], $^X" );
