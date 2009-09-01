package local::lib::deps;
use warnings;
use strict;
use Cwd;
use Config;
use Data::Dumper;

=pod

=head1 NAME

local::lib::deps - Maintain a module specific lib path for that modules dependencies.

=head1 DESCRIPTION

Maintaining perl module dependencies through a distributions package manager
can be a real pain. This module helps by making it easier to simply bundle all
your applications dependencies into one lib path specific to the module. It
also makes it easy to tell your application where to look for modules.

=head1 SYNOPSYS

Bootstrap your modules dependency area in the default location:

    use local::lib::deps;
    $local::lib::deps->install_deps( 'My::Module', 'Dep::One', 'Dep::Two' );

Bootstrap your modules dependency area in a custom location:

    use local::lib::deps;
    $moduledeps = local::lib::deps->new(
        base_path => '/path/to/dep/storage',
    );
    $moduledeps->install_deps( 'My::Module', 'Dep::One', 'Dep::Two', ... );

This will create a directory specifically for the My::Module namespace and
install the specified dependencies (and local::lib) there.

To use those deps in your app:

    use local::lib::deps qw/ My::Module My::ModuleTwo/;
    use Dep::One;

or

    use local::lib::deps;
    BEGIN {
        $moduledeps = local::lib::deps->new(
            base_path => '/path/to/dep/storage',
        );
        $moduledeps->add_paths( qw/ My::Module My::ModuleTwo/ );
    }
    use Dep::One;


To initiate local::lib with the destination directory of your module:

    use local::lib::deps -locallib => 'My::Module';

or

    use local::lib::deps;
    $moduledeps = local::lib::deps->new(
        module => 'My::Module',
        base_path => '/path/to/dep/storage',
    );
    $moduledeps->locallib;

=head1 USE CASES

The primary use case for this module is installing dependencies for an
application that would conflict in some way with the systems perl or module
configuration. It is also useful for applications that have a lot of
dependancies for which no distribution specific packages exist. This becomes
even more critical when you have a sysadmin that abhors using cpan instead of
distro packages.

Using this module as an end user is not very effective. You could potentially
rig your application to install all the dependencies necessary to the users
home directory every time it is run. This is a bad idea, each user would have
their own copy fo the dependencies, and every run it will try to update all the
deps.

A better idea is to use this module in your build scripts (Module::Build, or
Module::Install). The idea would be to have your 'make' or 'build' task
bootstrap the deps folder. Then when the application installs the deps will
install as well, but in a way that does not interfer with the rest of the
system.

This is even more useful when you are building a package as you can bundle the
dependences in your package.

=head1 PUBLIC METHODS

=over 4

=cut

our $VERSION = 0.08;
our %PATHS_ADDED;
our $START_PATH = getcwd();

sub import {
    my ( $package, @params ) = @_;
    my @modules = grep { $_ !~ m/^-/ } @params;
                      # Copy $_ so we don't change @params
    my %flags = map { my $i = $_; $i =~ s/^-//g; $i => 1 } grep { $_ =~ m/^-/ } @params;
    unless ( @modules ) {
        my ($module) = caller;
        @modules = ( $module );
    }
    if ( $flags{locallib} ) {
        die( "Can only specify one module to use with the -locallib flag.\n" ) if @modules > 1;
        $package->locallib( @modules );
        return;
    }
    $package->add_paths( @modules );
}

=item new( module => 'My::Module', base_path => 'path/to/module/libs', cpan_config => {...}, debug => 0 )

Create a new local::lib::deps object.

=cut

sub new {
    my ( $class, %params ) = @_;
    $class = ref $class || $class;
    return bless( { %params }, $class );
}

=item add_paths( qw/ Module::One Module::Two /)

Add the local::lib path for the specified module to @INC;

=cut

sub add_paths {
    my $self = shift;
    my  @modules = @_;
    $self->_add_path( $_ ) for @modules;
}

=item locallib( $module )

Will get local::lib setup against the local::lib::deps dir. If called as a
class method $module is manditory, if called as an object method $module is
ignored.

This is different from add_paths in that any module you install after this will
be installed to the specified modules local-lib dir.

=cut

sub locallib {
    my ( $self, $module ) = @_;
    $module = $self->module if $self->is_object;
    my $mpath = __absolute_path( $self->_full_module_path( $module ));
    $self->_add_path( $module );
    eval "use local::lib '$mpath'";
    die( $@ ) if $@;
}

=item install_deps( $module, @deps )

This will bootstrap local::lib into a local::lib::deps folder for the specified
module, it will then continue to install (or update) all the dependency
modules.

=cut

sub install_deps {
    my ( $self, $pkg, @deps) = @_;
    print "Forking child process to run cpan...\n";
    if ( my $pid = fork ) {
        waitpid( $pid, 0 );
    }
    else {
        $self->_install_deps( $pkg, @deps );
        exit;
    }
}

=item is_object()

Used internally, documented for completeness. Determines if $self is an object,
or the package.

=cut

sub is_object {
    my $self = shift;
    return unless ref $self;
    return UNIVERSAL::isa( $self, 'UNIVERSAL' );
}

=back

=head1 ACCESSOR METHODS

=over 4

=item module()

=cut

sub module {
    my $self = shift;
    return unless $self->is_object;
    return $self->{ module };
}

=item base_path()

Returns the base path that contains the module dependancy areas. This is
documented because you may wish to override this in an application specific
subclass.

=cut

sub base_path {
    my $self = shift;
    my $class = $self;
    if ( $self->is_object ) {
        return $self->{ base_path } if $self->{ base_path };
        $class = ref $self;
    }

#    my $llpath = __FILE__;
#    $llpath =~ s,/[^/]*$,,ig;
#    $llpath .= '/deps';

    my $file = $INC{ join("/", split('::', $class)) . ".pm" } || __FILE__;
    my $path = $file;
    $path =~ s,/[^/]*$,,ig;
    $path .= '/deps';

    $self->{ base_path } = $path if ( $self->is_object );

    return $path;
}

=item cpan_config

Get the cpan_config hashref.

=cut

sub cpan_config {
    my $self = shift;
    return $self->{ cpan_config };
}

=head1 OTHER METHODS

=over 4

=cut

sub _module_path {
    my $self = shift;
    my ( $module ) = @_;
    my $mpath = $module;
    $mpath =~ s,::,/,g;
    return $mpath;
}

sub _full_module_path {
    my $self = shift;
    return join( "/", $self->base_path(), $self->_module_path( @_ ));
}

sub _add_path {
    my $self = shift;
    my ( $module ) = @_;

    for my $path ( $self->_path( $module ), $self->_arch_path( $module )) {
        $path = __absolute_path( $path );
        next if $PATHS_ADDED{ $path }++;
        unshift @INC, $path;
    }
    #Shamelessly copied from local::lib;
    $ENV{PERL5LIB} = join( $Config{path_sep}, @INC );
}

sub _path {
    my $self = shift;
    return join( "/", $self->_full_module_path( @_ ), "lib/perl5" );
}

sub _arch_path {
    my $self = shift;
    return join( "/", $self->_path( @_ ), $Config{archname});
}

sub __absolute_path {
    my ( $dir ) = @_;
    if ( $dir !~ m,^/, ) {
        return "$START_PATH/$dir";
    }
    return $dir;
}

sub _install_deps {
    my $self = shift;
    my ($pkg, @deps) = @_;
    my $origin = getcwd();

    require CPAN;
    CPAN::HandleConfig->load();
    $CPAN::Config = {
        %{ $CPAN::Config },
        %{ $self->cpan_config },
    };
    CPAN::Shell::setup_output();
    CPAN::Index->reload();
    {
        local $CPAN::Config->{makepl_arg} = '--bootstrap=' . __absolute_path( $self->_full_module_path( $pkg ));
        CPAN::Shell->install( 'local::lib' );
    }

    # We want to install to the locallib.
    chdir( $origin );
    $self->locallib( $pkg );
    if ( $self->{ debug } ) {
        require Data::Dumper;
        Data::Dumper->import;
        print Dumper({ INC => \@INC, ENV => \%ENV, Config => $CPAN::Config });
    }

    foreach my $dep ( @deps ) {
        CPAN::Shell->install( $dep );
    }

    # Be kind rewind.
    chdir( $origin );
}

1;

__END__

=back

=head1 AUTHORS

=over 4

=item Chad Granum L<chad@opensourcery.com>

=back

=head1 COPYRIGHT

Copyright (C) 2009 OpenSourcery, LLC

local-lib-deps is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option) any
later version.

local-lib-deps is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
Street, Fifth Floor, Boston, MA 02110-1301 USA.

local-lib-deps is packaged with a copy of the GNU General Public License.
Please see docs/COPYING in this distribution.
