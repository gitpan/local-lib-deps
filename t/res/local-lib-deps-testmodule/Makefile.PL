#!/usr/bin/env perl
use strict;
use warnings;
use inc::Module::Install;

name 'local-lib-deps-testmodule';
license 'gpl';
abstract 'This module is for testing lib-local-deps';
author 'Chad Granum <chad@opensourcery.com>';
perl_version '5.006';
version_from 'lib/local/lib/deps/testmodule.pm';

WriteAll;
