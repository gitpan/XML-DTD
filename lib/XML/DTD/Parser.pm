package XML::DTD::Parser;

use XML::DTD::AttList;
use XML::DTD::Comment;
use XML::DTD::Element;
use XML::DTD::Entity;
use XML::DTD::EntityManager;
use XML::DTD::Ignore;
use XML::DTD::Include;
use XML::DTD::Notation;
use XML::DTD::PERef;
use XML::DTD::PI;
use XML::DTD::Text;

use 5.008;
use strict;
use warnings;
use Carp;

our @ISA = qw();

our $VERSION = '0.01';


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
    $self->{'INCFLAG'} = 0;
  }
  bless $self, $cls;
  return $self;
}


# Determine whether object is of this type
sub isa {
  my $cls = shift;
  carp "class method called on an object" if ref $cls;
  my $r = shift;

  if (defined($r) && ref($r) eq $cls) {
    return 1;
  } else {
    return 0;
  }
}


# Parse a DTD file
sub parse {
  my $self = shift;
  my $fh = shift;
  my $rt = shift;

  my ($lt, $dcl, $dcllt, $dclrt);
  # Get first line of input
  $lt = (defined $fh)?<$fh>:''; # Read from file handle if defined
  $lt = $rt . $lt if (defined $rt);
  while ($lt) {

    if ($self->{'INCFLAG'} == 0) {
      # Scan for start of declaration
      ($lt, $dcllt, $rt) = _scanuntil($fh,$lt, '<\!--|<\!\[|<\!|<\?|\%');
    } else {
      # Scan for start of declaration or end of include section
      ($lt, $dcllt, $rt) = _scanuntil($fh,$lt, '<\!--|<\!\[|<\!|<\?|\%|\]\]>');
    }

    # Deal with text before declaration
    push @{$self->{'ALL'}}, XML::DTD::Text->new($lt) if ($lt ne '');
    $lt = '';

    # Terminate loop if no declaration found
    last if ($dcllt eq '');

    # Terminate loop if in include mode and ]]> encountered
    last if ($self->{'INCFLAG'} == 1 and $dcllt eq ']]>');

    # Parse markup declarations
    if ($dcllt eq '<!') { # Declaration
      $rt = $self->_parsedecl($fh, $dcllt.$rt);
    } elsif ($dcllt eq '<![') { # Conditional section
      $rt = $self->_parsecondsec($fh, $dcllt.$rt);
    } elsif ($dcllt eq '<!--') { # Comment
      ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, '-->');
      push @{$self->{'ALL'}}, XML::DTD::Comment->new($dcllt.$dcl.$dclrt);
    } elsif ($dcllt eq '<?') { # Processing instruction
      ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, '\?>');
      push @{$self->{'ALL'}}, XML::DTD::PI->new($dcllt.$dcl.$dclrt);
    } elsif ($dcllt eq '%') { # Parameter entity reference
      ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, ';');
      push @{$self->{'ALL'}}, XML::DTD::PERef->new($self->_entitymanager,
						   $dcllt.$dcl.$dclrt);
    } else {
      #print "X: |$lt| |$dcllt| |$rt|\n";
      carp "unrecognised markup\n";
      return $rt;
    }
    # Copy text after match into unparsed buffer
    $lt = $rt;
    $rt = '';
    # Get another line of text if unparsed buffer is empty
    $lt .= <$fh> if (!$lt and defined $fh);
  }
  #print "RT: |$rt|\n";
  return $rt;
}


# Return the entity manager object
sub _entitymanager {
  my $self = shift;

  return $self->{'ENTMAN'};
}


# Scan string lt for regex re, reading lines from filehandle fh until matched
sub _scanuntil {
  my $fh = shift; # File handle from which to obtain input
  my $lt = shift; # Initial text already read from input
  my $re = shift; # Regular expression to match

  my ($line, $mt, $rt) = ('', '', '');
  if ($lt =~ /$re/s) { # If regex matched, set return values
    $lt = $`;
    $mt = $&;
    $rt = $';
  } else {
    if (defined $fh) { # Ensure that file handle is defined
      while ($line = <$fh>) { # Get lines from input until regex matches
	$lt .= $line;
	if ($lt =~ /$re/) {
	  $lt = $`;
	  $mt = $&;
	  $rt = $';
	  last;
	}
      }
    }
  }
  # Return pre-match, match, and post-match text
  return ($lt, $mt, $rt);
}


# Handle element, attlist, entity, and notation declarations
sub _parsedecl {
  my $self = shift;
  my $fh = shift;
  my $rt = shift;

  my ($dcl, $dclrt, $type, $elt, $atl, $ent);
  ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, '>');
  if ($dcl =~ /^\<\!(\w+)\s+/) {
    $type = $1;
    $dcl .= $dclrt;
    if ($type eq "ELEMENT") {
      $elt = XML::DTD::Element->new($self->_entitymanager, $dcl);
      push @{$self->{'ALL'}}, $elt;
      $self->{'ELEMENTS'}->{$elt->name()} = $elt;
    } elsif ($type eq "ATTLIST") {
      my $atl = XML::DTD::AttList->new($self->_entitymanager, $dcl);
      push @{$self->{'ALL'}}, $atl;
      $self->{'ATTLISTS'}->{$atl->name()} = $atl;
    } elsif ($type eq "ENTITY") {
      $ent = XML::DTD::Entity->new($dcl);
      push @{$self->{'ALL'}}, $ent;
      $self->_entitymanager->insert($ent);
    } elsif ($type eq "NOTATION") {
      push @{$self->{'ALL'}}, XML::DTD::Notation->new($dcl);
    } else {
      carp "unrecognised declaration type\n";
    }	
  }
  return $rt;
}


# Handle conditional sections
sub _parsecondsec {
  my $self = shift;
  my $fh = shift;
  my $rt = shift;

  my ($pre, $lt, $m, $r, $cond);
  # Ensure that the INCLUDE/IGNORE has been read from fh
  ($lt, $m, $rt) = _scanuntil($fh, $rt, '<\!\[\s*(%[\w\.:\-_]+;|\w+)\s*\[');
  $rt = $lt . $m . $rt;

  # Extract the INCLUDE/IGNORE word
  $rt =~ /<\!\[\s*(%[\w\.:\-_]+;|\w+)\s*\[/;
  $cond = $1;
  $m = $&;
  $r = $';

  if ($cond =~ /^%([\w\.:\-_]+);$/) {
    my $peval = $self->_entitymanager->pevalue($1);
    $cond = $peval if (defined $peval);
  }

  if ($cond eq 'IGNORE') { # An IGNORE section
    my $lev = 0;
    my $ltdlm = $m;
    $lt = '';
    # Scan until nested <![ and ]]> delimiters are closed
    do {
      ($pre, $m, $rt) = _scanuntil($fh, $rt, '<\!\[|\]\]>');
      $lt .= $pre . $m;
      if ($m eq '<![') {
	$lev++;
      } else {
	$lev--;
      }
    } while ($lev > 0);
    push @{$self->{'ALL'}}, XML::DTD::Ignore->new($lt, $ltdlm);
  } elsif ($cond eq 'INCLUDE') { # An INCLUDE section
    $rt = $r;
    my $inc = XML::DTD::Include->new($self->_entitymanager, $m);
    $rt = $inc->parse($fh, $rt);
    push @{$self->{'ALL'}}, $inc;
 } else { # A section of unrecognised type
    ($lt, $m, $rt) = _scanuntil($fh, $rt, '\]\]>');
    carp "unrecognised conditional section type $cond\n";
  }
  return $rt;
}


1;
__END__

=head1 NAME

XML::DTD::Parser - Perl module for parsing XML DTDs

=head1 SYNOPSIS

  use XML::DTD::Parser;

  my $dp = new XML::DTD::Parser;

=head1 DESCRIPTION

  XML::DTD::Parser is a support module for top level parsing of an XML
  DTD. The following methods are provided.

=over 4

=item B<new>

 my $dp = new XML::DTD::Parser;

Construct a new XML::DTD::Parser object.

=item B<isa>

if (XML::DTD::Parser->isa($obj) {
 ...
 }

Test object type

=item B<parse>

 open(FH,'<file.dtd');
 my $rt = '';
 $dp->parse(*FH, $rt);

Parse a DTD file.

=back

=head1 SEE ALSO

L<XML::DTD>

=head1 AUTHOR

Brendt Wohlberg E<lt>wohl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2006 by Brendt Wohlberg

This library is available under the terms of the GNU General Public
License (GPL), described in the GPL file included in this distribution.

=cut
