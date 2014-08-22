package Params::Registry::Error;

use 5.010;
use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends 'Throwable::Error';

=head1 NAME

Params::Registry::Error - Structured exceptions for Params::Registry

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';



__PACKAGE__->meta->make_immutable;

1;
