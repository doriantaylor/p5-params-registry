package Params::Registry;

use 5.010;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Params::Registry - Housekeeping for sets of named parameters

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Params::Registry;

    my $registry = Params::Registry->new(
        # express sequence with an arrayref
        params => [
            {
                name => 'foo',
            },
        ],
    );

    my $instance = $registry->process(\%params);

    $uri->query($instance->as_string);

=head1 DESCRIPTION

The purpose of this module is to handle a great deal of the
housekeeping around sets of named parameters and their values,
especially as they pertain to web development. Modules like
L<URI::QueryParam> and L<Catalyst> will take a URI query string and
turn it into a HASH reference containing either scalars or ARRAY
references of values, but further processing is almost always needed
to validate the parameters, normalize them, turn them into useful
compound objects, and last but not least, serialize them back into a
canonical string representation. It is likewise important to be able
to encapsulate error reporting around malformed or conflicting input,
at both the syntactical and semantic levels.

While this module was designed with the web in mind, it can be used
wherever a global registry of named parameters is deemed useful.

=over 4

=item Scalar

basically untouched

=item List

basically untouched

=item Tuple

A tuple can be understood as a list of definite length, for which each
position has its own meaning. The contents of a tuple can likewise be
heterogeneous.

=item Set

A standard mathematical set has no duplicate elements and no concept
of sequence.

=item Range

A range can be understood as a span of numbers or number-like objects,
such as L<DateTime> objects.

=item Object

When nothing else will do

=back


=head3 Cascading

There are instances, for example in the case of supporting a legacy
HTML form, when it is useful to combine input parameters. Take for
instance the practice of using drop-down boxes for the year, month and
day of a date in lieu of support for the HTML5 C<datetime> form field,
or access to custom form controls. One would specify C<year>, C<month>
and C<day> parameters, as well as a C<date> parameter which
C<consumes> the former three, C<using> a subroutine reference to do
it. Consumed parameters are deleted from the set.


=head3 Complement

A special parameter, C<complement>, is defined to signal parameters in
the set itself which should be treated as complements to what have
been expressed in the input. This module makes no prescriptions about
how the complement is to be interpreted, with the exception of
parameters whose values are bounded sets or ranges: if a shorter query
string can be achieved by negating the set and removing (or adding)
the parameter's name to the complement, that is what this module will
do.

    # universe of foo = (a .. z)
    foo=a&foo=b&foo=c&complement=foo -> (a .. z) - (a b c)

=head1 METHODS

=head2 foo

=cut

sub foo {
}


=head1 AUTHOR

Dorian Taylor, C<< <dorian at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-params-registry at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Params-Registry>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Params::Registry


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Params-Registry>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Params-Registry>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Params-Registry>

=item * Search CPAN

L<http://search.cpan.org/dist/Params-Registry/>

=back


=head1 SEE ALSO

L<Params::Validate>

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

1; # End of Params::Registry
