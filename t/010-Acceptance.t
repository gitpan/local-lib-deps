use strict;
use warnings;

use Test::local::lib::deps 'tmp', plan => [ tests => 8 ];

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
$one->install_deps( 'Fake::Module', 'local::lib::deps::testmodule' );
unhide_out;

my $fails = 0;
ok( -e( $tmp . '/Fake/Module/lib/perl5/local/lib.pm'), "locallib installed to the correct place." ) || $fails++;
ok( -e( $tmp . '/Fake/Module/lib/perl5/local/lib/deps/testmodule.pm'), "dummy installed to the correct place." ) || $fails++;
show_fails( $tmp ) if ( $fails );

eval 'require local::lib::deps::testmodule';
ok( $@, "Could not use module that is in locallib yet." );
ok( ! $local::lib::deps::testmodule::VERSION, "local::lib::deps::testmodule is not loaded." );

ok( ! ( grep { $_ =~ m,$tmp/Fake/Module/lib/perl5/, } @INC ), "Path not yet in \@INC" );
$one->import( "Fake::Module" );
ok(( grep { $_ =~ m,$tmp/Fake/Module/lib/perl5/, } @INC ), "Path now in \@INC" );

eval 'require local::lib::deps::testmodule';
ok( $local::lib::deps::testmodule::VERSION, 'local::lib::deps::testmodule is loaded.' );
