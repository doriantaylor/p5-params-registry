package Params::Registry::Template;

use 5.010;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Params::Registry::Template - Template class for an individual parameter

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Params::Registry::Template;

    my $foo = Params::Registry::Template->new();
    ...

=head1 METHODS

=head2 new

All arguments to the constructor are optional unless specified otherwise.

=over 4

=item registry

This back-reference to the registry is the only required parameter. It
is required

=cut

has registry => (
);

=item type

The L<Moose> type of the individual values of the parameter. The
default is C<Str>.

=cut

has type => (
);

=item composite

If this type is present, even single-valued parameters will be coerced
into it via C<ArrayRef[Item]>.

=cut

has composite => (
);

=item format

Either a format string or a subroutine reference depicting how scalar
values ought to be serialized. The default value is C<%s>.

=cut

has format => (
);

=item depends

An C<ARRAY> reference containing a list of parameters which I<must>
accompany this one.

=cut

has depends => (
);

=item conflicts

An C<ARRAY> reference containing a list of parameters which I<must
not> be seen with this one.

=cut

has conflicts => (
);

=item consumes

For cascading parameters, an C<ARRAY> reference containing a list of
subsidiary parameters which are consumed to create it. All consumed
parameters are automatically assumed to be in conflict, i.e., it makes
no sense to have both a subsidiary parameter and one that consumes it
in the input at the same time.

=cut

has consumes => (
);

=item using

For cascading parameters, a C<CODE> reference to operate on the
consumed parameters.

=cut

has using => (
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
);

=item universe

For L</Set> and L</Range> parameters, this is a C<CODE> reference which
produces a universal set.

=cut

has universe => (
);

=item descending

For L</Range> parameters, this bit indicates whether the input values
should be interpreted and/or serialized in descending order. This also
governs the serialization of L</Set> parameters.

=cut

has descending => (
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

1; # End of Params::Registry::Template
