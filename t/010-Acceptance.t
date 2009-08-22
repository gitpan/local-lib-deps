use strict;
use warnings;
use Cwd;

use Test::More 'no_plan';
use Data::Dumper;
use File::Temp qw/tempdir/;

my $CLASS = 'local::lib::deps';

use_ok( $CLASS );

my $tmp = tempdir( 'test-XXXX', DIR => 't', CLEANUP => 1 );
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
        keep_source_where => q[/home/exodist/.cpan/sources],
        makepl_arg => "",
        mbuildpl_arg => "",
    }
);
my $origin = getcwd();

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

chdir( getcwd() . "/t/res/local-lib-deps-testmodule" );
$one->install_deps( 'Fake::Module', '.' );
chdir( $origin );

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

ok( ! ( grep { $_ =~ m,$tmp/Fake/Module/lib/perl5/, } @INC ), "Path not yet in \@INC" );
$one->import( "Fake::Module" );
ok(( grep { $_ =~ m,$tmp/Fake/Module/lib/perl5/, } @INC ), "Path now in \@INC" );


#eval 'use CPAN::Test::Dummy::Perl5::Build';
#ok( $@, "Could not use module that is in locallib yet." );


#eval 'use CPAN::Test::Dummy::Perl5::Build';
#ok( ! $@, "Can now use the module" );
