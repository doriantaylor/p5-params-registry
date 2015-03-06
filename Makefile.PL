use inc::Module::Install;

name        'Params-Registry';
readme_from 'lib/Params/Registry.pm';
all_from    'lib/Params/Registry.pm';
author      q{Dorian Taylor <dorian@cpan.org>};
license     'apache';

requires 'Moose'                    => '2.0604';
requires 'namespace::autoclean'     => '0.20';
requires 'MooseX::Types'            => '0.35';
requires 'MooseX::Params::Validate' => '0.18';
requires 'Throwable'                => '0.200008';
requires 'URI'                      => '1.60';

build_requires 'Test::More';

auto_install;

WriteAll;

