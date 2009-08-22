use strict;
use warnings;
use Cwd;

use Test::More tests => 22;
use Data::Dumper;
use File::Temp qw/tempdir/;
use Config;
use vars qw/ $tmp /;


my $CLASS = 'local::lib::deps';

use_ok( $CLASS );

ok( ! $CLASS->is_object, "is_object si false when using as a class method." );
is( $CLASS->module, undef, "module is undef when using as class method." );
my $mpath = $INC{ 'local/lib/deps.pm' };
$mpath =~ s|/[^/]*$||ig;
is( $CLASS->base_path, "$mpath/deps", "Base path is correct" );

ok( my $one = $CLASS->new( module => 'Fake::Module', base_path => '/tmp' ), "Create a new instance of the class" );
ok( $one->is_object, "is_object returns true on an actual object." );
is( $one->module, "Fake::Module", "Correct module." );
is( $one->base_path, "/tmp", "Base path is correct" );

ok( $one = $CLASS->new(), "Create a new instance of the class" );
is( $one->base_path, $CLASS->base_path, "Default base_path is the class base_path." );

# {{{ BOTH ARE SAME
for my $item ( $CLASS, $one ) {
    my $type = $item->is_object ? 'Object' : 'Class';

    is( $item->_module_path( 'My::Module' ), 'My/Module', "Correct path for modules ($type)" );
    is(
        $item->_full_module_path( 'My::Module' ),
        $item->base_path . "/" . $item->_module_path( 'My::Module' ),
        "Currect full path. ($type)",
    );
    is(
        $item->_path( 'My::Module' ),
        $item->_full_module_path( 'My::Module' ) . "/lib/perl5",
        "Correct lib path ($type)",
    );
    is(
        $item->_arch_path( 'My::Module' ),
        $item->_path( 'My::Module' ) . "/" . $Config{archname},
        "Correct arch path ($type)",
    );
}
#}}}

my $path = $CLASS->_path( 'Fake::Module' );
my $archpath = $CLASS->_arch_path( 'Fake::Module' );

ok( ! ( grep { $_ =~ m,$path, } @INC ), "Path not yet in \@INC" );
ok( ! ( grep { $_ =~ m,$archpath, } @INC ), "Path not yet in \@INC" );
$CLASS->_add_path( "Fake::Module" );
ok(( grep { $_ =~ m,$path, } @INC ), "Path now in \@INC" );
ok(( grep { $_ =~ m,$archpath, } @INC ), "Path now in \@INC" );
