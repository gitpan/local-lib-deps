package Test::local::lib::deps;
use strict;
use warnings;
use File::Temp qw/tempdir/;
use Cwd;

our $DIR;
BEGIN { $DIR = -w 't' ? 't' : -w "/tmp" ? "/tmp" : -w "." ? "." : undef }

use base 'Test::More';
use Test::More;

our @EXPORT = qw/ get_tmp hide_out unhide_out cpan_config /;

sub import {
    my ( $package, @params ) = @_;
    my ($module) = caller;
    my $tmp = grep { /^tmp$/ } @params;
    my %params = grep { $_ !~ /^tmp$/ } @params;
    my $import = delete $params{ 'import' };
    my $plan = delete $params{ 'plan' };

    {
        eval <<EOT;
        package $module;
        use Exporter;
        use Test::More ( \$tmp && !\$DIR ) ? ( skip_all => "No writable temp directory!" )
                                           : \@\$plan;
        \$import ? Exporter\::import( \$package, \@\$import )
                 : Exporter\::import( \$package, \@EXPORT );

EOT
        die( $@ ) if $@;
    }
}

sub get_tmp {
    my $tmp = tempdir( 'test-XXXX', DIR => $DIR, CLEANUP => 1 );
    $tmp = getcwd() . "/$tmp";

    mkdir("$tmp/CPAN");

    return $tmp;
}

sub hide_out {
    my ( $tmp ) = @_;
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

sub unhide_out {
    close( STDOUT );
    close( STDERR );
    open( STDOUT, ">&COPYSTD" );
    open( STDERR, ">&COPYERR" );
}

sub cpan_config {
    my ( $tmp ) = @_;
    return {
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
}

sub show_fails {
    my ( $tmp ) = @_;
    open( my $LOG, "<", "$tmp/build.out" );
    print STDERR join( "", my @list = <$LOG> );
    close( $LOG );
}
