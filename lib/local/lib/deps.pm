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
also makes it easy to tell your applicatin where to look for modules.

=head1 SYNOPSYS

Bootstrap your modules dependency area:

TODO

This will create a directory specifically for the My::Module namespace and
install the specified dependencies (and local::lib) there.

To use those deps in your app:

    use local::lib::deps qw/ My::Module /;
    use Dep::One;

To initiate local::lib with the destination directory of your module:

TODO

=head1 USE CASES

=head1 PUBLIC METHODS

=over 4

=cut

our $VERSION = 0.03;
our %PATHS_ADDED;

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
    $package->_add_path( $_ ) for @modules;
}

=item new( module => 'My::Module', base_path => 'path/to/module/libs' )

Create a new local::lib::deps object.

=cut

sub new {
    my ( $class, %params ) = @_;
    $class = ref $class || $class;
    return bless( { %params }, $class );
}

=item locallib( $module )

Will get local::lib setup against the local::lib::deps dir. If called as a
class method $module is manditory, if called as an object method $module is
ignored.

=cut

sub locallib {
    my ( $self, $module ) = @_;
    $module = $self->module if $self->is_object;
    my $mpath = $self->_full_module_path( $module );
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

sub is_object {
    my $self = shift;
    return ref $self ? 1 : 0;
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
    if ( $self->is_object ) {
        return $self->{ base_path } if $self->{ base_path };
    }

    my $llpath = __FILE__;
    $llpath =~ s,/[^/]*$,,ig;
    $llpath .= '/deps';

    $self->{ base_path } = $llpath if ( $self->is_object );

    return $llpath;
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
        next if $PATHS_ADDED{ $path }++;
        unshift @INC, $path;
    }
}

sub _path {
    my $self = shift;
    return join( "/", $self->_full_module_path( @_ ), "lib/perl5" );
}

sub _arch_path {
    my $self = shift;
    return join( "/", $self->_path( @_ ), $Config{archname});
}

sub _install_deps {
    my $self = shift;
    my ($pkg, @deps) = @_;
    my $origin = getcwd();

    require CPAN;
    CPAN::HandleConfig->load();
    CPAN::Shell::setup_output();
    CPAN::Index->reload();
    local $CPAN::Config->{build_requires_install_policy} = 'yes';
    {
        local $CPAN::Config->{makepl_arg} = '--bootstrap=' . $self->_full_module_path( $pkg );
        CPAN::Shell->install( 'local::lib' );
    }

    # We want to install to the locallib.
    $self->locallib( $pkg );

    foreach my $dep ( @deps ) {
        print "****** $dep *******\n";
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
