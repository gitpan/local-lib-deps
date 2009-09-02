use strict;
use warnings;

use Test::local::lib::deps 'tmp', plan => [ tests => 2 ];

my $CLASS = 'local::lib::deps';
use_ok( $CLASS );

my $tmp = get_tmp();

my $one = $CLASS->new(
    module => 'Fake::Module',
    base_path => $tmp,
    debug => 1,
    cpan_config => cpan_config($tmp),
);

hide_out( $tmp );
$one->force_deps( 'Fake::Module', 'local::lib::deps::testmodule' );
unhide_out;

my $fails = 0;
ok( -e( $tmp . '/Fake/Module/lib/perl5/local/lib/deps/testmodule.pm'), "dummy installed to the correct place." ) || $fails++;
show_fails( $tmp ) if ( $fails );
