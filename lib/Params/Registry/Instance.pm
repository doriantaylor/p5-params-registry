package Params::Registry::Instance;

use 5.010;
use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

=head1 NAME

Params::Registry::Instance - An instance of registered parameters

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

has _registry => (
    is       => 'ro',
    isa      => 'Params::Registry',
    required => 1,
    weak_ref => 1,
    init_arg => 'registry',
);

has _content => (
    is       => 'ro',
    isa      => 'HashRef',
    traits   => [qw(Hash)],
    lazy     => 1,
    default  => sub { {} },
    handles  => {
        get => 'get',
    },
);

has _other => (
    is       => 'ro',
    isa      => 'HashRef',
    traits   => [qw(Hash)],
    lazy     => 1,
    default  => sub { {} },
    handles  => {
        
    },
);

# sub BUILD {
#     my $self = shift;
# }

sub _process {
    my ($self, $query) = @_;

    if (my $ref = ref $query) {
        Carp::croak("query must be a HASH reference") unless $ref eq 'HASH';
    }
    else {
        # is a string
    }

    my $r = $self->_registry;
    my $c = $self->_content;
    my $o = $self->_other;


    my @seq = $r->sequence;

    my %out;

    # step 1 remove special 'complement' parameter
    #my $com = delete $query->{$r->complement};

    # check if required parameters are present in the input
    # maybe want to do this last after the cascades have been performed?
    for my $k (grep { $r->template($_)->min > 0 } @seq) {
    }

    # have to do depends/conflicts/consumes
    # consumes implies depends and conflicts

    # first we process what we were given as input

    while (my ($k, $v) = each %$query) {
        $v = [$v] unless ref $v;

        if (my $t = $r->template($k)) {
            # XXX this can croak
            $out{$k} = $t->process(@$v);
        }
        else {
            # set 'other' parameters
        }
    }

    #warn Data::Dumper::Dumper(\%out);

    # then we try to figure out if it was any good

    $self;
}

=head1 SYNOPSIS

    use Params::Registry;
    use URI;
    use URI::QueryParam;

    my $registry = Params::Registry->new(%enormous_arg_list);

    my $uri = URI->new($str);

    # The instance is created through Params::Registry, which will
    # raise different exceptions for different types of conflict in
    # the parameters.
    my $instance = eval { $registry->process($uri->query_form_hash) };

    # Contents have already been coerced
    my $thingy = $instance->get($key);

    # This will perform type validation and coercion, so if you aren't
    # certain the input is clean, you'll want to wrap this call in an
    # eval.
    eval { $instance->set($key, $val) };

    # Take a subset of parameters peculiar to a certain application.
    my $group = $instance->group($name);

    # This string is guaranteed to be consistent for a given set of
    # parameters and values.
    $uri->query($instance->as_string);

=head1 METHODS

=head2 get $KEY

=cut

# sub get {
#     my ($self, $key) = @_;
#     return $self->_
# }

=head2 set $KEY, @VALS

Modifies one of the parameters in the instance. Attempts to coerce the
input according to the template. Accepts either a literal, an C<ARRAY>
reference of literals, or the target datatype. Returns the I<old> value

This method will throw an exception if the input can't be reconciled
with the L<Params::Registry::Template> (i.e., if the input falls
outside the lexical or semantic constraints).

=cut

sub set {
    my ($self, $key, @vals) = @_;
    @vals = @{$vals[0]} if @vals == 1 and ref $vals[0] eq 'ARRAY';

    my $content  = $self->_content;
    my $template = $self->_registry->template($key);

    if ($template) {
        # do content
        my $obj = $template->process(@vals);
        $content->{$key} = $obj;
    }
    else {
        my $other = $self->_other;
        my $x = $other->{$key};
        if (@vals == 0 or not defined $vals[0]) {
            delete $other->{$key};
        }
    }
}

=head2 group $KEY

Selects a subset of the instance according to the groups laid out in
the L<Params::Registry> specification, clones them, and returns them
in a C<HASH> reference, suitable for passing into another method.

=cut

sub group {
    my ($self, $key) = @_;

    my %out;
    my @list = @{$self->_registry->_groups->{$key} || []};
    my $c = $self->_content;
    for my $k (@list) {
        # XXX ACTUALLY CLONE THESE (MAYBE)

        # use exists, not defined
        $out{$k} = $c->{$k} if exists $c->{$k};
    }

    \%out;
}

=head2 clone $KEY => $VAL [...] | \%PAIRS

Produces a clone of the instance object, with the supplied parameters
overwritten. Internally, this uses L</set>, so the input must already
be clean, or wrapped in an C<eval>.

=cut

sub clone {
    my $self = shift;
    my %p = ref $_[0] eq 'HASH' ? %{$_[0]} : @_;

    # XXX deep copy?
    my %orig = %{$self->_content};

    my $out = Params::Registry::Instance->new(
        registry => $self->_registry,
        _content => \%orig,
    );

    for my $k (keys %p) {
        $out->set($k, $p{$k});
    }

    $out;
}

=head2 as_string

Generates the canonical URI query string according to the template.

=cut

sub as_string {
    my $self = shift;
    my $r = $self->_registry;
    my @seq = $r->sequence;

    my @out;
    for my $k (@seq) {
        my $t = $r->template($k);
        my $v = $self->get($k);
        warn Data::Dumper::Dumper($v);
        my $obj = $t->unprocess($v);
        next unless defined $obj;
        #warn Data::Dumper::Dumper($obj);
    }
}

=head2 make_uri $URI

Accepts a L<URI> object and returns a clone of that object with its
query string overwritten with the contents of the instance. This is a
convenience method for idioms like:

    my $new_uri = $instance->clone(foo => undef)->make_uri($old_uri);

As expected, this will produce a new instance with the C<foo>
parameter removed, which is then used to generate a URI, suitable for
a link.

=cut

sub make_uri {
    my ($self, $uri) = @_;
}

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

__PACKAGE__->meta->make_immutable;

1; # End of Params::Registry::Instance
