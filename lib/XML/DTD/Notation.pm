package XML::DTD::Notation;

use XML::DTD::Component;

use 5.008;
use strict;
use warnings;
use Carp;

our @ISA = qw(XML::DTD::Component);

our $VERSION = '0.01';


# Constructor
sub new {
  my $arg = shift;
  my $not = shift;

  my $cls = ref($arg) || $arg;
  my $obj = ref($arg) && $arg;

  my $self;
  if ($obj) {
    # Called as a copy constructor
    $self = { %$obj };
    bless $self, $cls;
  } else {
    # Called as the main constructor
    $self = { };
    bless $self, $cls;
    $self->define('notation', $not, '<!NOTATION', '>');
  }
  return $self;
}


1;
__END__

=head1 NAME

XML::DTD::Notation - Perl module representing a notation declaration in a DTD

=head1 SYNOPSIS

  use XML::DTD::Notation;

  my $not = XML::DTD::Notation->new('!NOTATION e PUBLIC "+//F//G//EN">');

=head1 DESCRIPTION

XML::DTD::Notation is a Perl module representing a notation
declaration in a DTD. The following methods are provided.

=over 4

=item B<new>

 my $not = XML::DTD::Notation->new('<!NOTATION e PUBLIC "+//F//G//EN">');

Construct a new XML::DTD::Notation object.

=back

=head1 SEE ALSO

L<XML::DTD>, L<XML::DTD::Component>

=head1 AUTHOR

Brendt Wohlberg E<lt>wohl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2006 by Brendt Wohlberg

This library is available under the terms of the GNU General Public
License (GPL), described in the GPL file included in this distribution.

=cut
