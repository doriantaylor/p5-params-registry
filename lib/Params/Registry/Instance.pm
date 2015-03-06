package Params::Registry::Instance;

use 5.010;
use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

with 'Throwable';

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
        exists => 'exists',
        get    => 'get',
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

=head2 set \%PARAMS | $KEY, $VAL [, $KEY2, \@VALS2 ...]

Modifies one or more of the parameters in the instance. Attempts to
coerce the input according to the template. Accepts, as values, either
a literal, an C<ARRAY> reference of literals, or the target datatype.
If a <Params::Registry::Template/composite> is specified for a given
key, C<ARRAY> references will be coerced into the appropriate
composite datatype.

Syntax, semantics, cardinality, dependencies and conflicts are all
observed, but cascading is I<not>. This method will throw an exception
if the input can't be reconciled with the L<Params::Registry> that
generated the instance.

=cut

# it isn't clear why '_process' should not admit already-parsed
# values, and why 'set' should not do cascading. they are essentially
# identical. in fact, we may be able to just get rid of '_process'
# altogether in favour of 'set'.

# the difference between 'set' and '_process' is that '_process' runs
# defaults while 'set' does not, and 'set' compares depends/conflicts
# with existing content while '_process' has nothing to compare it to.

# * parameters handed to 'set' may already be parsed, or partially
#   parsed (as in an arrayref of 'type' but not 'composite')

# * dependencies, conflicts, and precursor 'consumes' parameters may
#   be present in the existing data structure

# * dependencies/conflicts can be cleared by passing in 'undef'; to
#   deal with 'empty' parameters, pass in an empty arrayref or
#   arrayref containing only undefs.

# although if the parameters are ranked and inserted ,

sub set {
    my $self = shift;

    # deal with parameters and metaparameters
    my (%p, %meta);
    if (ref $_[0]) {
        $self->throw('If the first argument is a ref, it has to be a HASH ref')
            unless ref $_[0] eq 'HASH';
        # params are their own hashref
        %p = %{$_[0]};

        if (ref $_[1]) {
            $self->throw('If the first and second arguments are refs, ' .
                             'they both have to be HASH refs')
                unless ref $_[1] eq 'HASH';

            # metaparams are their own hashref
            %meta = %{$_[1]};
        }
        else {
            $self->throw('Expected even number of args for metaparameters')
                unless @_ % 2 == 1; # note: even is actually odd here

            # metaparams are everything after the hashref
            %meta = @_[1..$#_];
        }
    }
    else {
        $self->throw('Expected even number of args for metaparameters')
            unless @_ % 2 == 0; # note: even is actually even here

        # arguments = params
        %p = @_;

        # pull metaparams out of ordinary params
        %meta = map { $_ => delete $p{$_} } qw(-defaults);
    }

    # grab the parent object that stores all the configuration data
    my $r = $self->_registry;

    # create a map of params to complement/negate
    my %neg;
    if (my $c = delete $p{$r->complement}) {
        my $x = ref $c;
        $self->throw('If complement is a ref, it must be an ARRAY ref')
            if $x and $x ne 'ARRAY';
        map { $neg{$_} = 1 } @{$x ? $c : [$c]};
    }

    # and now for the product
    my %out = %{$self->_content};
    my %del;
    # the registry has already ranked groups of parameters by order of
    # depends/consumes
    for my $list (@{$r->_ranked}) {
        # each rank has a list of parameters which are roughly in the
        # original sequence provided to the registry
        for my $p (@$list) {
            # retrieve the appropriate template object
            my $t = $r->template($p);

            if (exists $p{$p}) {
                # retrieve, condition and process a new piece of input
                my $v  = $p{$p};
                my $rv = ref $v;
                $v = [$v] if !$rv || $rv ne 'ARRAY';

                $out{$p} = $t->process(@$v);

                # any 'consumed' subparameters are necessarily
                # overridden by the presence of this input data
                map { $del{$_} = 1 } $t->consumes;

                # deal with conflicts
                my @x = grep { $out{$_} && !$del{$_} } $t->conflicts;
                $self->throw(sprintf '%s conflicts with %s', $p, join ', ', @x)
                    if @x;
            }
            elsif ($t->consumes > 0) {
                # we will only try to 'consume' if all the precursor
                # parameters are present
                next unless
                    $t->consumes == grep { exists $out{$_} } $t->consumes;

                # run the consumer code
                $out{$p} = $t->consumer->(@out{$t->consumes});

                # add the params we just consumed to the delete list
                map { $del{$_} = 1 } $t->consumes;

                # deal with any conflicts that arose
                my @x = grep { $out{$_} && !$del{$_} } $t->conflicts;
                $self->throw(sprintf '%s conflicts with %s', $p, join ', ', @x)
                    if @x;
            }
            elsif ($meta{-defaults} and my $d = $t->default) {
                # add a default value unless there are conflicts
                my @x = grep { $out{$_} && !$del{$_} } $t->conflicts;
                $out{$p} = $d->() unless @x;
            }
            else {
                # noop
            }

            # now handle the complement
            if ($neg{$p} and $t->has_complement) {
                $out{$p} = $t->complement($out{$p});
            }
        }
    }

    # we waited to delete the contents all at once in case there were
    # dependencies
    map { delete $out{$_} } keys %del;

    # now we replace the content all in one shot
    %{$self->_content} = %out;

    # not sure what else to return
    return $self;
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

    $out->set(\%p);

    $out;
}

=head2 as_string

Generates the canonical URI query string according to the template.

=cut

sub as_string {
    my $self = shift;
    my $r = $self->_registry;

    # this just creates [key => \@values], ...
    my @seq = $r->sequence;
    my @out;
    for my $k (@seq) {
        # skip unless the parameter is present. this gets around
        # 'empty'-marked params that we don't actually have.
        next unless $self->exists($k);

        my $t = $r->template($k);
        my $v = $self->get($k);
        #warn Data::Dumper::Dumper($v);
        my $obj = $t->unprocess($v);
        next unless defined $obj;
        #warn Data::Dumper::Dumper($obj);
        push @out, [$k, $obj];
    }

    # XXX we have to handle complements here

    # for sets/composites, check if displaying '&complement=key' is
    # shorter than just displaying the contents of the set
    # (e.g. &key=val&key=val&key=val... it almost certainly will be).

    return join '&', map { my $x = $_->[0]; map { "$x=$_" } @{$_->[1]} } @out;
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
    $uri = $uri->clone->canonical;
    $uri->query($self->as_string);
    $uri;
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
