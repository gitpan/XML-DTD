package XML::DTD::AttList;

use XML::DTD::Component;
use XML::DTD::AttDef;

use 5.008;
use strict;
use warnings;
use Carp;

our @ISA = qw(XML::DTD::Component);

our $VERSION = '0.01';


# Constructor
sub new {
  my $arg = shift;
  my $man = shift;
  my $att = shift;

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
    $self->define('attlist', $att, '<!ATTLIST', '>');
    $self->_parse($man, $att);
  }
  return $self;
}


# Write an XML representation
sub writexml {
  my $self = shift;
  my $xmlw = shift;

  my $ws1 = (defined($self->{'WS1'}) and $self->{'WS1'} ne '')?
    $self->{'WS1'}:undef;
  $xmlw->open('attlist', {'name' => $self->{'NAME'},
			  'ltws' => $self->{'WS0'},
			  'rtws' => $ws1});
  $xmlw->open('attdefs');
  my $c;
  foreach $c ( @{$self->{'ATTNAMES'}} ) {
    $self->{'ATTDEFS'}->{$c}->writexmlelts($xmlw);
  }
  $xmlw->close;
  $xmlw->close;
}


# Return the attribute list name
sub name {
  my $self = shift;

  return $self->{'NAME'};
}


# Return a list of attribute names
sub attribnames {
  my $self = shift;

  return $self->{'ATTNAMES'};
}


# Return the attribute definition object for the named attribute
sub attribute {
  my $self = shift;
  my $name = shift;

  return $self->{'ATTDEFS'}->{$name};
}


# Parse the element declaration
sub _parse {
  my $self = shift;
  my $entman = shift;
  my $attlst = shift;

  if ($attlst =~ /<\!ATTLIST(\s+)([\w\.:\-_]+|%[\w\.:\-_]+;)(\s+.+)>/s) {
    $self->{'WS0'} = $1;
    my $name = $2;
    my $attdefs = $3;
    # Still need to handle name being a peref
    $self->{'NAME'} = $name;
    $attdefs = $entman->entitysubst($attdefs);
    $self->{'ATTNAMES'} = [];
    $self->{'ATTDEFS'} = {};
    my ($aname,$atype,$dflt,$ws0,$ws1,$ws2);
    while ($attdefs =~ /^(\s+)([\w\.:\-_]+)(\s+)([\w\.:\-_]+|\'[^\']+\'|\"[^\"]+\"|\([^\(\)]+\))(\s+)(\#REQUIRED|\#IMPLIED|(?:(?:\#FIXED\s+)(?:[\w\.:\-_]+|\'[^\']+\'|\"[^\"]+\"))|(?:\'[^\']+\'|\"[^\"]+\"))/s) {
      $ws0 = $1;
      $aname = $2;
      $ws1 = $3;
      $atype = $4;
      $ws2 = $5;
      $dflt = $6;
      $attdefs = $';
      push @{$self->{'ATTNAMES'}}, $aname;
      $self->{'ATTDEFS'}->{$aname} =
             XML::DTD::AttDef->new($aname, $atype, $dflt, $ws0, $ws1, $ws2);
    }
    if ($attdefs =~ /^\s*$/) {
      $self->{'WS1'} = $attdefs;
    } else {
      carp 'not all attlist text could be parsed' if ($attdefs !~ /^\w*$/);
      print STDERR ">> REMAIN >>|$attdefs|<<<<\n";
    }
  } else {
    carp 'error parsing attlist name and attdefs';
  }
}


1;
__END__

=head1 NAME

XML::DTD::AttList - Perl module representing an ATTLIST declaration in
an XML DTD.

=head1 SYNOPSIS

  use XML::DTD::AttList;
  my $entman = XML::DTD::EntityManager->new;
  my $att = XML::DTD::AttList::new($entman, '<!ATTLIST a b CDATA #IMPLIED');

=head1 DESCRIPTION

  XML::DTD::AttList is a Perl module representing an ATTLIST
  declaration in an XML DTD. The following methods are provided.

=over 4

=item B<new>

  $entman = XML::DTD::EntityManager->new;
  $attlist = new XML::DTD::AttList($entman, '<!ATTLIST a b CDATA #IMPLIED');

  Constructs a new XML::DTD::AttList object.

=item B<writexml>

  $xo = new XML::Output({'fh' => *STDOUT});
  $attlist->writexml($xo);

Write an XML representation of the attribute list.

=item B<name>

  $eltname = $attlist->name();

Return the name of the element with which the attribute list is associated.

=item B<attribnames>

  $nmlst = $attlist->attribnames;

Return a list of attribute names.

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
