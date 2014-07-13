use inc::Module::Install;

name        'Params-Registry';
readme_from 'lib/Params/Registry.pm';
all_from    'lib/Params/Registry.pm';
author      q{Dorian Taylor <dorian@cpan.org>};
license     'apache';

build_requires 'Test::More';

auto_install;

WriteAll;

