use strict;
use warnings;

# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name            'Yahoo-Photos';
all_from        'lib/Yahoo/Photos.pm';

# abstract 'This distribution does something';
license         'perl';

# Specific dependencies

# core
requires        'Carp'                    => 0;
requires        'File::Spec::Functions'   => 0;
requires        'List::Util'              => 0;

# CPAN
requires        'YAML'                    => 0;
requires        'Readonly'                => 0;
requires        'HTTP::Cookies::Netscape' => 0;
requires        'WWW::Mechanize'          => 0;
requires        'File::HomeDir'           => 0;
requires        'Class::Spiffy'           => 0;
requires        'Perl::Version'           => 0;

build_requires  'Test::More'              => '0.42';
build_requires  'File::Temp'              => 0;
build_requires  'Test::Exception'         => 0;
build_requires  'List::Util'              => 0;
build_requires  'File::Spec::Functions'   => 0;

install_script  'bin/yahoo-photos';

auto_install;
WriteAll;
