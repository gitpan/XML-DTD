package XML::DTD;

use XML::Output;
use XML::DTD::Parser;
use XML::DTD::AttList;
use XML::DTD::Comment;
use XML::DTD::Element;
use XML::DTD::Entity;
use XML::DTD::Ignore;
use XML::DTD::Notation;
use XML::DTD::PERef;
use XML::DTD::PI;
use XML::DTD::Text;

use 5.008;
use strict;
use warnings;
use Carp;

our @ISA = qw(XML::DTD::Parser);

our $VERSION = '0.02';

# Constructor
sub new {
  my $arg = shift;

  my $cls = ref($arg) || $arg;
  my $obj = ref($arg) && $arg;

  my $self;
  if ($obj) {
    # Called as a copy constructor
    $self = { %$obj };
  } else {
    # Called as the main constructor
    $self = { };
    $self->{'ALL'} = [];
    $self->{'ELEMENTS'} = {};
    $self->{'ATTLISTS'} = {};
    $self->{'ENTMAN'} = XML::DTD::EntityManager->new;
    $self->{'INCFLAG'} = 0;
  }
  bless $self, $cls;
  return $self;
}


# Read the DTD from a file
sub fread {
  my $self = shift;
  my $fh = shift;

  my $r = $self->parse($fh);
  return ($r eq '')?1:0;
}


# Read the DTD from a string
sub sread {
  my $self = shift;
  my $str = shift;

  my $r = $self->parse(undef, $str);
  return ($r eq '')?1:0;
}


# Write the DTD to a file
sub fwrite {
  my $self = shift;
  my $fh = shift;

  my $c;
  foreach $c ( @{$self->{'ALL'}} ) {
    $c->fwrite($fh);
  }
}


# Write the DTD to a string
sub swrite {
  my $self = shift;

  my $str = '';
  my $c;
  foreach $c ( @{$self->{'ALL'}} ) {
    $str .= $c->swrite();
  }
  return $str;
}


# Write an XML representation of the DTD to a file
sub fwritexml {
  my $self = shift;
  my $fh = shift;

  my $xmlw = new XML::Output({'fh' => $fh});
  $self->_writexml($xmlw);
}


# Write an XML representation of the DTD to a string
sub swritexml {
  my $self = shift;

  my $xmlw = new XML::Output;
  $self->_writexml($xmlw);
  return $xmlw->xmlstr();
}


# Return a list of element names
sub elementlist {
  my $self = shift;

  return [sort keys %{$self->{'ELEMENTS'}}];
}


# Return the element object associated with the specified name
sub element {
  my $self = shift;
  my $name = shift;

  return $self->{'ELEMENTS'}->{$name};
}


# Return the attribute list object associated with the specified name
sub attlist {
  my $self = shift;
  my $name = shift;

  return $self->{'ATTLISTS'}->{$name};
}


# Internal common XML writing function
sub _writexml {
  my $self = shift;
  my $xmlw = shift;

  $xmlw->open('dtd');
  my $c;
  foreach $c ( @{$self->{'ALL'}} ) {
    $c->writexml($xmlw);
  }
  $xmlw->close;
}


1;
__END__

=head1 NAME

XML::DTD - Perl module for parsing XML DTDs

=head1 SYNOPSIS

  use XML::DTD;

  my $dtd = new XML::DTD;
  open(FH,'<file.dtd');
  $dtd->fread(*FH);
  close(FH);
  $dtd->fwrite(*STDOUT);

=head1 ABSTRACT

  XML::DTD is a Perl module for parsing XML DTD files.

=head1 DESCRIPTION

  XML::DTD is a Perl module for parsing XML DTDs. The following
  methods are provided.

=over 4

=item B<new>

  $dtd = new XML::DTD;

Constructs a new XML::DTD object.

=item B<fread>

  $dtd->fread(*FILEHANDLE);

Parse a DTD file.

=item B<sread>

  $dtd->sread($string);

Parse DTD text in a string.

=item B<fwrite>

  $dtd->fwrite(*FILEHANDLE);

Write the DTD to a file.

=item B<swrite>

  $string = $dtd->swrite();

Return the DTD text as a string.

=item B<fwritexml>

  $dtd->fwritexml(*FILEHANDLE);

Write an XML representation of the DTD to a file.

=item B<swritexml>

  $string = $dtd->swritexml();

Return an XML representation of the DTD text as a string.

=item B<elementlist>

  $elts = $dtd->elementlist;

Return a list of element names.

=item B<element>

  $eltobj = $dtd->element('elementname');

Return element object associated with the specified name.

=item B<attlist>

  $attlistobj = $dtd->attlist('elementname');

Return atribute list object associated with the specified name.

=back

=head1 SEE ALSO

L<XML::DTD::Parse>, The XML 1.0 W3C Recommendation at
http://www.w3.org/TR/REC-xml/

=head1 AUTHOR

Brendt Wohlberg E<lt>wohl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2006 by Brendt Wohlberg

This library is available under the terms of the GNU General Public
License (GPL), described in the GPL file included in this distribution.

=cut
