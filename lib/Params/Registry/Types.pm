package Params::Registry::Types;

use 5.010;
use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

use MooseX::Types -declare => [
    qw(Type Template TemplateSet)
];

use MooseX::Types::Moose qw(Str ClassName RoleName HashRef);

=head1 NAME

Params::Registry::Types - Types for Params::Registry

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Params::Registry::Types qw(:all);

=head1 TYPES

=head2 Type

This is the type for types. XZibit approved.

=cut

class_type 'MooseX::Types::UndefinedType';
class_type 'MooseX::Types::TypeDecorator';
class_type 'Moose::Meta::TypeConstraint';

subtype Type, as join('|', qw( MooseX::Types::UndefinedType
                               MooseX::Types::TypeDecorator
                               Moose::Meta::TypeConstraint
                               ClassName RoleName Str ));

# yo dawg i herd u liek types so we put a type in yo type so u can
# type whiel u type
coerce Type, from Str, via {
    my $x = shift;
    return find_or_create_type_constraint($x) || class_type($x);
};
# ...that meme will never get old.


=head2 Template


=cut

class_type Template, { class => 'Params::Registry::Template' };
#coerce Template, from HashRef, via { Params::Registry::Template->new(shift) };

#subtype TemplateSet, as HashRef[HashRef];
#coerce TemplateSet,

=head2 

=head1 AUTHOR

Dorian Taylor, C<< <dorian at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Dorian Taylor.

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License.  You may
obtain a copy of the License at
L<http://www.apache.org/licenses/LICENSE-2.0> .

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.

=cut

1; # End of Params::Registry::Types
