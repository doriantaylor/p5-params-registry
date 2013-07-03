package Params::Registry::Template;

use 5.010;
use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

use Params::Registry::Types qw(Type);
use MooseX::Types::Moose    qw(Maybe Bool Int Str ArrayRef CodeRef);

=head1 NAME

Params::Registry::Template - Template class for an individual parameter

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    my $registry = Params::Registry->new(
        params => [
            # These constructs are passed into
            # the parameter template module.
            {
                # The name is consumed before
                # the object is constructed.
                name       => 'foo',
                # the type of individual values
                type       => 'Num',
                # the composite type with coercion
                composite  => 'NumberRange',
                # format string or sub for individual values
                format     => '%0.2f',
                # do not delete empty values
                empty      => 1,
                universe   => \&_extrema_from_db,
                complement => \&_range_complement,
                unwind     => \&_range_to_arrayref,
            },
            {
                name => 'bar',
                # Lengthy definitions can be reused.
                use  => 'foo',
            },
        ],
    );

=head1 METHODS

=head2 new

All arguments to the constructor are optional unless specified otherwise.

=over 4

=item registry

This back-reference to the registry is the only required
argument. Since the template objects are constructed from a factory
inside L<Params::Registry>, it will be supplied automatically.

=cut

has registry => (
    is       => 'ro',
    isa      => 'Params::Registry',
    required => 1,
    weak_ref => 1,
);

=item type

The L<Moose> type of the individual values of the parameter. The
default is C<Str>.

=cut

has type => (
    is      => 'ro',
    isa     => Type,
    lazy    => 1,
    default => sub { Str },
);

=item composite

A composite type to envelop one or more distinct parameter values. If
a composite type is specified, even single-valued parameters will be
coerced into that composite type as if it was an C<ArrayRef[Item]>. As
such, composite types used in this field should be specified with
coercions that expect C<ArrayRef[Item]>.

=cut

has composite => (
    is      => 'ro',
    isa     => Type,
    lazy    => 1,
    default => sub { Str },
);

=item format

Either a format string or a subroutine reference depicting how scalar
values ought to be serialized. The default value is C<%s>.

=cut

has format => (
    is      => 'ro',
    isa     => Str|CodeRef,
    lazy    => 1,
    default => '%s',
);

=item depends

An C<ARRAY> reference containing a list of parameters which I<must>
accompany this one.

=cut

has depends => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    lazy    => 1,
    default => sub { [] },
);

=item conflicts

An C<ARRAY> reference containing a list of parameters which I<must
not> be seen with this one.

=cut

has conflicts => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    lazy    => 1,
    default => sub { [] },
);

=item consumes

For cascading parameters, an C<ARRAY> reference containing a list of
subsidiary parameters which are consumed to create it. All consumed
parameters are automatically assumed to be in conflict, i.e., it makes
no sense to have both a subsidiary parameter and one that consumes it
in the input at the same time.

=cut

has consumes => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    lazy    => 1,
    default => sub { [] },
);

=item using

For cascading parameters, a C<CODE> reference to operate on the
consumed parameters.

=cut

has using => (
    is  => 'ro',
    isa => CodeRef,
);

=item cardinality

Either a scalar depicting an exact count, or a two-element C<ARRAY>
reference depicting the minimum and maximum number of recognized
values from the point of view of the I<input>. Subsequent values will
either be truncated or L<shifted left|/shift>. The default setting is
C<[0, undef]>, i.e. the parameter must have zero or more values. Set
the minimum cardinality to 1 or higher to make the parameter
I<required>.

=cut

has cardinality => (
    is      => 'ro',
    # this complains if you use MooseX::Types
    isa     => 'ArrayRef[Maybe[Int]]|Int',
    lazy    => 1,
    default => sub { [0, undef] },
);

=item shift

This boolean value determines the behaviour of input parameter values
that exceed the parameter's maximum cardinality. The default behaviour
is to truncate the list of values at the upper bound.  Setting this
bit instead causes the values for the ascribed parameter to be shifted
off the left side of the list. This enables, for instance, dumb web
applications to simply tack additional parameters onto the end of a
query string without having to parse it.

=cut

has shift => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    default => 0,
);

=item empty

If a parameter value is C<undef> or the empty string, the default
behaviour is to act like it didn't exist, thus pruning it from the
resulting data and from the serialization. In the event that an empty
value is I<meaningful>, such as in expressing a range unbounded on one
side, this bit can be set, and the L</default> can be set to either
C<undef> or the empty string (or anything else).

=cut

has empty => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    default => 0,
);

=item default

This C<default> value is passed through to the application only if the
parameter in question is either missing or empty (if C<empty> is
set). Likewise if the final translation of the input value matches the
default, it will not show up in the canonical serialization. Like
L<Moose>, is expected to be a C<CODE> reference.

    default => sub { 1 },

=cut

has default => (
    is  => 'ro',
    isa => CodeRef,
);

=item universe

For L</Set> and L</Range> parameters, this is a C<CODE> reference
which produces a universal set against which the input can be
negated. In parameter serialization, there are often cases wherein a
shorter string can be achieved by presenting the negated set and
adding the parameter's name to the special parameter
L<Params::Registry/complement>. The subroutine can, for instance,
query a database for the full set in question and return a type
compatible with the parameter instance.

=cut

has universe => (
    is  => 'ro',
    isa => CodeRef,
);

=item complement

For L</Set> and L</Range> parameters, this C<CODE> reference will need
to do the right thing to produce the inverse set.

    {
        # ...
        complement => sub {
            # assuming Set::Scalar
            my ($me, $universe) = @_;
            $me->complement($universe); },
        # ...
    }

=cut

has complement => (
    is  => 'ro',
    isa => CodeRef,
);

=item unwind

For composite object parameters, specify a C<CODE> reference to a
subroutine which will turn the object into either a scalar, an
C<ARRAY> reference of scalars, or an I<unblessed> C<HASH> reference
containing valid parameter keys to either scalars or C<ARRAY>
references of scalars. In the case the subroutine returns a C<HASH>
reference, the registry will replace the parameter in context with the
parameters supplied, effectively performing the inverse of the
L</consume> function. To encourage code reuse, this function is
applied before L</reverse> despite the ability to reverse the
resulting list in the function.

    {
        # ...
        # assuming Set::Scalar
        unwind => sub { [sort shift->elements] },
        # ...
    }

=cut

has unwind => (
    is  => 'ro',
    isa => CodeRef,
);

=item reverse

For L</Range> parameters, this bit indicates whether the input values
should be interpreted and/or serialized in reverse order. This also
governs the serialization of L</Set> parameters.

=cut

has reverse => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    default => 0,
);

=back

=cut

=head1 AUTHOR

Dorian Taylor, C<< <dorian at cpan.org> >>

=head1 SEE ALSO

L<Params::Registry>

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

__PACKAGE__->meta->make_immutable;

1; # End of Params::Registry::Template
