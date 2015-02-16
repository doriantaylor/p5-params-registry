package Params::Registry::Template;

use 5.010;
use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

use Params::Registry::Types qw(Type Dependency Format);
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

                # For sets and ranges:
                # fetch range extrema or universal set
                universe   => \&_extrema_from_db,

                # supply an operation that complements the given
                # set/range against the extrema/universe
                complement => \&_range_complement,

                # supply a serialization function
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

This constructor is invoked by a factory method in
L<Params::Registry>. All arguments are optional unless specified
otherwise.

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

Specifies a composite type to envelop one or more distinct parameter
values. If a composite type is specified, even single-valued
parameters will be coerced into that composite type as if it was an
C<ArrayRef>. As such, composite types used in this field should
be specified with coercions that expect C<ArrayRef>, like so:

    coerce FooBar => from ArrayRef => via { Foo::Bar->new(@{$_[0]}) };

    # ...
    {
        name      => 'foo',
        type      => 'Str',
        composite => 'FooBar',
        # ...
    },
    # ...


=cut

has composite => (
    is      => 'ro',
    isa     => Type,
    lazy    => 1,
    default => sub { ArrayRef },
);

=item format

Either a format string or a subroutine reference depicting how scalar
values ought to be serialized. The default value is C<%s>.

=cut

has format => (
    is      => 'ro',
    isa     => Format,
    lazy    => 1,
    coerce  => 1,
    default => sub { sub { sprintf '%s', shift } },
);

=item depends

An C<ARRAY> reference containing a list of parameters which I<must>
accompany this one.

=cut

# I know it says ARRAY but the value is more useful as hash keys, so
# these two attributes get coerced into hashrefs.

has depends => (
    is      => 'ro',
    isa     => Dependency,
    traits  => [qw(Hash)],
    coerce  => 1,
    lazy    => 1,
    default => sub { {} },
    handles => {
        depends_on => 'get',
    },
);

=item conflicts

An C<ARRAY> reference containing a list of parameters which I<must
not> be seen with this one.

=cut

has conflicts => (
    is      => 'ro',
    isa     => Dependency,
    traits  => [qw(Hash)],
    coerce  => 1,
    lazy    => 1,
    default => sub { {} },
    handles => {
        conflicts_with => 'get',
        # make these symmetric in the constructor
        _add_conflict  => 'set',
    },
);

=item consumes

For cascading parameters, an C<ARRAY> reference containing a list of
subsidiary parameters which are consumed to create it. All consumed
parameters are automatically assumed to be in conflict, i.e., it makes
no sense to have both a subsidiary parameter and one that consumes it
in the input at the same time.

=cut

has _consumes => (
    is       => 'ro',
    isa      => ArrayRef[Str],
    traits   => [qw(Array)],
    lazy     => 1,
    init_arg => 'consumes',
    default  => sub { [] },
    handles  => {
        consumes => 'elements',
    },
);

=item consumer

For cascading parameters, a C<CODE> reference to operate on the
consumed parameters in order to produce the desired I<atomic> value.
To produce a I<composite> parameter value from multiple existing
I<values>, define a coercion from C<ArrayRef> to the type supplied
to the L</composite> property.

The default consumer function, therefore, simply returns an C<ARRAY>
reference that collates the values from the parameters defined in
the L</consumes> property.

Once again, this functionality exists primarily for the purpose of
interfacing with HTML forms that lack the latest features. Consider
the following example:

    # ...
    {
        name => 'year',
        type => 'Int',
        max  => 1,
    },
    {
        name => 'month',
        type => 'Int',
        max  => 1,
    },
    {
        name => 'day',
        type => 'Int',
        max  => 1,
    },
    {
        name => 'date',

        # this would be defined elsewhere with coercion from a
        # string that matches 'YYYY-MM-DD', for direct input.
        type => 'MyDateTimeType',

        # we don't want multiple values for this parameter.
        max  => 1,

        # in lieu of being explicitly defined in the input, this
        # parameter will be constructed from the following:
        consumes => [qw(year month day)],

        # and this is how it will happen:
        consumer => sub {
            DateTime->new(
                year  => $_[0],
                month => $_[1],
                day   => $_[2],
            );
        },
    },
    # ...

Here, we may have a form which contains a C<date> field for the newest
browsers that support the new form control, or otherwise generated via
JavaScript. As a fallback mechanism (e.g. for an older browser, robot,
or paranoid person), form fields for the C<year>, C<month>, and C<day>
can also be specified in the markup, and used to generate C<date>.

=cut

sub _default_consume {
    [@_];
}

has consumer => (
    is      => 'ro',
    isa     => CodeRef,
    lazy    => 1,
    default => sub { \&_default_consume },
);

# =item cardinality

# Either a scalar depicting an exact count, or a two-element C<ARRAY>
# reference depicting the minimum and maximum number of recognized
# values from the point of view of the I<input>. Subsequent values will
# either be truncated or L<shifted left|/shift>. The default setting is
# C<[0, undef]>, i.e. the parameter must have zero or more values. Set
# the minimum cardinality to 1 or higher to make the parameter
# I<required>.

# =cut

# has cardinality => (
#     is      => 'ro',
#     # this complains if you use MooseX::Types
#     isa     => 'ArrayRef[Maybe[Int]]|Int',
#     lazy    => 1,
#     default => sub { [0, undef] },
# );

=item min

The minimum number of values I<required> for the given parameter. Set
to 1 or higher to signal that the parameter is required. The default
value is 0, meaning that the parameter is optional.

=cut

has min => (
    is      => 'ro',
    isa     => Int,
    lazy    => 1,
    default => 0,
);

=item max

The maximum number of values I<acknowledged> for the given parameter.
Subsequent values will either be truncated to the right or shifted to
the left, depending on the value of the L</shift> property. Setting
this property to 1 will force parameters to be scalar. The default is
C<undef>, which accepts an unbounded list of values.

=cut

has max => (
    is      => 'ro',
    isa     => Maybe[Int],
    lazy    => 1,
    default => sub { undef },
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
behaviour is to act like it didn't exist in the input, thus pruning it
from the resulting data and from the serialization. In the event that
an empty value for a given parameter is I<meaningful>, such as in
expressing a range unbounded on one side, this bit can be set, and the
L</default> can be set to either C<undef> or the empty string (or
anything else).

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

# this is the cache for whatever gets generated by the universe function
has _unicache => (
    is  => 'rw',
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

has _complement => (
    is       => 'ro',
    isa      => CodeRef,
    init_arg => 'complement',
);

sub complement {
    my ($self, $set) = @_;
    if (my $c = $self->_complement) {
        $c->($set, $self->_unicache);
    }
}

=item unwind

For composite object parameters, specify a C<CODE> reference to a
subroutine which will turn the object into either a scalar, an
C<ARRAY> reference of scalars, or an I<unblessed> C<HASH> reference
containing valid parameter keys to either scalars or C<ARRAY>
references of scalars. In the case the subroutine returns a C<HASH>
reference, the registry will replace the parameter in context with the
parameters supplied, effectively performing the inverse of a composite
type coercion function. To encourage code reuse, this function is
applied before L</reverse> despite the ability to reverse the
resulting list in the function.

The first argument to the subroutine is the template object itself,
and the second is the value to be unwound. If you don't need any state
data from the template, consider the following idiom:

    {
        # ...
        # assuming Set::Scalar
        unwind => sub { [sort $_[1]->elements] },
        # ...
    }

An optional second return value can be used to indicate that the
special L<complement|Params::Registry/complement> parameter should be
set for this parameter. This is applicable, for instance, to the
complement of a range, which would otherwise be impossible to
serialize into a string.

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

sub BUILD {
    my $self = shift;

    $self->refresh;
    #warn $self->type->name;
}

=back

=head2 process

Validate a set of individual parameter values and (optionally)
construct a composite value.

=cut

sub process {
    my ($self, @values) = @_;

    my $t = $self->type;

    # deal with cardinality
    my $max = $self->max;
    if (defined $max and @values > $max) {
        if ($self->shift) {
            splice @values, -$max, $max;
        }
        else {
            splice @values, 0, $max;
        }
    }

    # coerce atomic type
    my $e  = $self->empty;
    my $ac = $t->coercion;
    for my $i (0..$#values) {

        if ($e && (!defined $values[$i] or $values[$i] eq '')) {
            undef $values[$i];
            next;
        }

        if ($ac) {
            # coerce
            #warn defined $values[$i];
            $values[$i] = $ac->coerce($values[$i]) if defined $values[$i];
        }

        # XXX proper error
        if (defined $values[$i]) {
            Carp::croak('lol fail') unless $t->check($values[$i]);
        }
    }

    if (my $c = $self->composite) {
        # try to coerce into composite
        if (my $cc = $c->coercion) {
            return $cc->coerce(\@values);
        }
    }

    return $values[0] if defined $max && $max == 1;

    return wantarray ? @values : \@values;
}


=head2 unprocess

Apply L</unwind> to get an arrayref, then L</format> to get strings.
In list context it will also return the flag from L</unwind>
indicating that the L<complement|Params::Registry/complement>
parameter should be set.

=cut

sub unprocess {
    my ($self, $obj) = @_;

    # take care of empty property
    unless (defined $obj) {
        if ($self->empty) {
            my $max = $self->max;
            return [''] if defined $max && $max == 1;
            return [] if !defined $max or $max > 1;
        }
        return;
    }

    # i dunno, should we check these types on the way out?

    my $complement;
    if ($self->composite) {
        if (my $u = $self->unwind) {
            ($obj, $complement) = $u->($self, $obj);
        }
    }

    $obj = [$obj] unless ref $obj eq 'ARRAY';

    # format values
    my $fmt = $self->format;
    # XXX this should really be done once 
    #unless (ref $fmt eq 'CODE') {
    #    my $x = $fmt;
    #    $fmt = sub { sprintf $x, shift };
    #}

    my @out = map { defined $_ ? $fmt->($_) : '' } @$obj;
    return wantarray ? (\@out, $complement) : \@out;
}

=head2 refresh

Refreshes stateful information like the universal set, if present.

=cut

sub refresh {
    my $self = shift;
    if (my $u = $self->universe) {
        $self->_unicache($u->());
    }

    1;
}

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
