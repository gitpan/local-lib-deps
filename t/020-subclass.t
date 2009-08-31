use strict;
use warnings;

use Test::local::lib::deps 'tmp', plan => [ tests => 4 ];

my $tmp = get_tmp;

my $buildup = "$tmp";
for my $new (qw{ lib Fake Module }) {
    $buildup .= "/$new";
    mkdir( $buildup ) || die( "Could not create $buildup: $!\n" );
}

unshift @INC => "$tmp/lib";

open( my $depsmodule, ">", "$buildup/deps.pm" ) || die( "Could not create deps.pm: $!\n" );
print $depsmodule <<'EOT';
package Fake::Module::deps;
use strict;
use warnings;
use base 'local::lib::deps';

sub _full_module_path {
    my $self = shift;
    return $self->base_path();
}

1;
EOT
close( $depsmodule );

require Fake::Module::deps;

is( Fake::Module::deps->base_path, "$tmp/lib/Fake/Module/deps" );

mkdir("$tmp/CPAN");
my $one = Fake::Module::deps->new(
    module => 'Fake::Module',
    debug => 1,
    cpan_config => cpan_config( $tmp ),
);

is( $one->base_path, "$tmp/lib/Fake/Module/deps" );

hide_out( $tmp );
$one->install_deps( 'Fake::Module', 'local::lib::deps::testmodule' );
unhide_out();

my $fails = 0;
ok( -e( $tmp . '/lib/Fake/Module/deps/lib/perl5/local/lib.pm'), "locallib installed to the correct place." ) || $fails++;
ok( -e( $tmp . '/lib/Fake/Module/deps/lib/perl5/local/lib/deps/testmodule.pm'), "dummy installed to the correct place." ) || $fails++;
show_fails($tmp) if ( $fails );
