use strict;
use warnings;
use Cwd;

my $DIR;
BEGIN { $DIR = -w 't' ? 't' : -w "/tmp" ? "/tmp" : -w "." ? "." : undef }

use Test::More $DIR ? (tests => 8) : (skip_all => "No writable temp directory!");
use Data::Dumper;
use File::Temp qw/tempdir/;
use File::Copy;

my $CLASS = 'local::lib::deps';

use_ok( $CLASS );

my $tmp = tempdir( 'test-XXXX', DIR => $DIR, CLEANUP => 1 );
$tmp = getcwd() . "/$tmp";

mkdir("$tmp/CPAN");

my $one = $CLASS->new(
    module => 'Fake::Module',
    base_path => $tmp,
    debug => 1,
    cpan_config => {
        cpan_home => "$tmp/CPAN",
        build_dir => "$tmp/CPAN/build",
        build_requires_install_policy => 'yes',
        prerequisites_policy => 'follow',
        urllist => [q[http://cpan.cpantesters.org/]],
        auto_commit => q[0],
        build_dir_reuse => q[0],
        keep_source_where => "$tmp/CPAN/sources",
        makepl_arg => "",
        mbuildpl_arg => "",
    }
);

{
    diag "Hiding output from cpan build... this could take some time.\n";
    diag "In event of error you can check $tmp/build.out for more information.\n";
    no warnings 'once';
    open( COPYSTD, ">&STDOUT" );
    open( COPYERR, ">&STDERR" );
    close( STDOUT );
    close( STDERR );
    open( STDOUT, ">", "$tmp/build.out" );
    open( STDERR, ">&STDOUT" );
}

$one->install_deps( 'Fake::Module', 'local::lib::deps::testmodule' );

close( STDOUT );
close( STDERR );
open( STDOUT, ">&COPYSTD" );
open( STDERR, ">&COPYERR" );

my $fails = 0;

ok( -e( $tmp . '/Fake/Module/lib/perl5/local/lib.pm'), "locallib installed to the correct place." ) || $fails++;
ok( -e( $tmp . '/Fake/Module/lib/perl5/local/lib/deps/testmodule.pm'), "dummy installed to the correct place." ) || $fails++;

if ( $fails ) {
    open( my $LOG, "<", "$tmp/build.out" );
    print STDERR join( "", my @list = <$LOG> );
    close( $LOG );
}

eval 'require local::lib::deps::testmodule';
ok( $@, "Could not use module that is in locallib yet." );
ok( ! $local::lib::deps::testmodule::VERSION, "local::lib::deps::testmodule is not loaded." );

ok( ! ( grep { $_ =~ m,$tmp/Fake/Module/lib/perl5/, } @INC ), "Path not yet in \@INC" );
$one->import( "Fake::Module" );
ok(( grep { $_ =~ m,$tmp/Fake/Module/lib/perl5/, } @INC ), "Path now in \@INC" );

eval 'require local::lib::deps::testmodule';
ok( $local::lib::deps::testmodule::VERSION, 'local::lib::deps::testmodule is loaded.' );
