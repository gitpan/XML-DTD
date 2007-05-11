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

use URI::file;

use 5.008;
use strict;
use warnings;
use Carp;

our @ISA = qw();

our $VERSION = '0.02';


# Constructor
sub new {
  my $arg = shift;
  my $val = shift; # Parser is validating

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
    $self->{'VALIDATING'} = $val;
    $self->{'EXPANDINGPE'} = 0;
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
  my $fh   = shift;
  my $rt   = shift;
  my $uri  = shift; # The URI of the entity being parsed, if known

  # If the URI is relative (has no scheme), then interpret it as a file:
  # URI relative to the current working directory.  The test for the
  # presence of a scheme is strictly incorrect, to to avoid interpreting
  # DOS drive numbers as schemes, so that c:\x\y\z.dtd is interpreted as
  # a file name, and translated to the URI file:///c:/x/y/z.dtd, not taken
  # as being a URI with scheme c: and containing the unwise character '\'.

  $uri = URI::file->new_abs($uri)->as_string
    if (defined $uri && $uri !~ /^[a-zA-Z][a-zA-Z0-9+\-.]+:/);

#  print "DTD::Parser:: parse URI: $uri\n" if (defined $uri);

  my ($lt, $dcl, $dcllt, $dclrt);
  # Get first line of input
  $lt = (defined $fh)?<$fh>:''; # Read from file handle if defined
  $lt = $rt . $lt if (defined $rt);
  while ($lt) {

    if ($self->{'INCFLAG'} == 0) {
      # Scan for start of declaration
      ($lt, $dcllt, $rt) = _scanuntil($fh,$lt, '<\!--|<\!\[|<\!|<\?|\%', 0);
    } else {
      # Scan for start of declaration or end of include section
      ($lt, $dcllt, $rt) = _scanuntil($fh,$lt,
				      '<\!--|<\!\[|<\!|<\?|\%|\]\]>', 0);
    }

    # Deal with text before declaration
    push @{$self->{'ALL'}}, XML::DTD::Text->new($lt)
      if ($lt ne '' and !$self->{'EXPANDINGPE'});
    $lt = '';

    # Terminate loop if no declaration found
    last if ($dcllt eq '');

    # Terminate loop if in include mode and ]]> encountered
    last if ($self->{'INCFLAG'} == 1 and $dcllt eq ']]>');

    # Parse markup declarations
    if ($dcllt eq '<!') { # Declaration
      $rt = $self->_parsedecl($fh, $dcllt.$rt, $uri);
    } elsif ($dcllt eq '<![') { # Conditional section
      $rt = $self->_parsecondsec($fh, $dcllt.$rt);
    } elsif ($dcllt eq '<!--') { # Comment
      ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, '-->', 0);
      push @{$self->{'ALL'}}, XML::DTD::Comment->new($dcllt.$dcl.$dclrt)
        if (!$self->{'EXPANDINGPE'});
    } elsif ($dcllt eq '<?') { # Processing instruction
      ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, '\?>', 0);
      push @{$self->{'ALL'}}, XML::DTD::PI->new($dcllt.$dcl.$dclrt)
        if (!$self->{'EXPANDINGPE'});
    } elsif ($dcllt eq '%') { # Parameter entity reference
      ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, ';', 0);
      push @{$self->{'ALL'}}, XML::DTD::PERef->new($self->_entitymanager, $dcl)
        if (!$self->{'EXPANDINGPE'});
      if ($self->{'VALIDATING'}) {
	my $expanding = $self->{'EXPANDINGPE'};
	$self->{'EXPANDINGPE'} = 1;
	$self->parse(undef,
		     $self->_entitymanager->peexpand($dcl),
		     $self->_entitymanager->peuri($dcl));
	$self->{'EXPANDINGPE'} = $expanding;
      }
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


# Scan string lt for regex $re, reading lines from filehandle fh until matched
# Ignores quoted matches of $re if $quo is passed and is non-zero.
sub _scanuntil {
  my $fh  = shift; # File handle from which to obtain input
  my $buf = shift; # Initial text already read from input
  my $re  = shift; # Regular expression to match
  my $quo = shift; # True if re is to be ignored if quoted

  $re = "($re)|['\"]" if ($quo);
  my $quoted = '';
  my ($left, $match, $right) = ('');
  while(!defined $match) {
    if ($buf =~ /$re/s) {
      my ($lt, $mt, $rt) = ($`, $&, $');
      my $isquote = !$quoted && ($mt eq '"' || $mt eq "'")
		    || $mt eq $quoted;
      if ($isquote or $quoted) {
	$quoted = $quoted ? '' : $mt if ($isquote);
	$left .= $lt.$mt;
	$buf = $rt;
      } elsif (!$quoted) {
	$left .= $lt;
	($match, $right) = ($mt, $rt);
      }
    } else {
      my $line;
      if (defined $fh and $line = <$fh>) {
	$buf .= $line;
      } else {
        $left = $match = $right = '';
      }
    }
  }
  return ($left, $match, $right);
}


# Handle element, attlist, entity, and notation declarations
sub _parsedecl {
  my $self = shift;
  my $fh = shift;
  my $rt = shift;
  my $uri = shift;

  my ($dcl, $dclrt, $type, $elt, $atl, $ent);
  ($dcl, $dclrt, $rt) = _scanuntil($fh, $rt, '>', 1);
  if ($dcl =~ /^\<\!(\w+)\s+/) {
    $type = $1;
    $dcl .= $dclrt;
    if ($type eq "ELEMENT") {
      $elt = XML::DTD::Element->new($self->_entitymanager, $dcl);
      if (!exists $self->{'ELEMENTS'}->{$elt->name()}) {
	push @{$self->{'ALL'}}, $elt
	  if (!$self->{'EXPANDINGPE'});
	$self->{'ELEMENTS'}->{$elt->name()} = $elt;
      } else {
        carp "element redefined\n";
      }
    } elsif ($type eq "ATTLIST") {
      my $atl = XML::DTD::AttList->new($self->_entitymanager, $dcl);
      push @{$self->{'ALL'}}, $atl
        if (!$self->{'EXPANDINGPE'});
      if (!exists $self->{'ATTLISTS'}->{$atl->name()}) {
	$self->{'ATTLISTS'}->{$atl->name()} = $atl;
      } else {
	$self->{'ATTLISTS'}->{$atl->name()}->merge($atl);
      }
    } elsif ($type eq "ENTITY") {
      $ent = XML::DTD::Entity->new($dcl, $self->{'VALIDATING'}, $uri);
      push @{$self->{'ALL'}}, $ent
        if (!$self->{'EXPANDINGPE'});
      $self->_entitymanager->insert($ent);
    } elsif ($type eq "NOTATION") {
      push @{$self->{'ALL'}}, XML::DTD::Notation->new($dcl)
        if (!$self->{'EXPANDINGPE'});
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
  ($lt, $m, $rt) = _scanuntil($fh, $rt, '<\!\[\s*(%[\w\.:\-_]+;|\w+)\s*\[', 0);
  $rt = $lt . $m . $rt;

  # Extract the INCLUDE/IGNORE word
  $rt =~ /<\!\[\s*(%[\w\.:\-_]+;|\w+)\s*\[/;
  $cond = $1;
  $m = $&;
  $r = $';

  $cond = $self->_entitymanager->peexpend($cond)
    if ($cond =~ /^%([\w\.:\-_]+);$/);

  if ($cond eq 'IGNORE') { # An IGNORE section
    my $lev = 0;
    my $ltdlm = $m;
    $lt = '';
    # Scan until nested <![ and ]]> delimiters are closed
    do {
      ($pre, $m, $rt) = _scanuntil($fh, $rt, '<\!\[|\]\]>', 0);
      $lt .= $pre . $m;
      if ($m eq '<![') {
	$lev++;
      } else {
	$lev--;
      }
    } while ($lev > 0);
    push @{$self->{'ALL'}}, XML::DTD::Ignore->new($lt, $ltdlm)
      if (!$self->{'EXPANDINGPE'});
  } elsif ($cond eq 'INCLUDE') { # An INCLUDE section
    $rt = $r;
    my $inc = XML::DTD::Include->new($self->_entitymanager, $m);
    $rt = $inc->parse($fh, $rt);
    push @{$self->{'ALL'}}, $inc
      if (!$self->{'EXPANDINGPE'});
 } else { # A section of unrecognised type
    ($lt, $m, $rt) = _scanuntil($fh, $rt, '\]\]>', 0);
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

  my $dp = new XML::DTD::Parser [ ($val) ];

=head1 DESCRIPTION

  XML::DTD::Parser is a support module for top level parsing of an XML
  DTD. The following methods are provided.

=over 4

=item B<new>

 my $dp = new XML::DTD::Parser [ ($val) ];

Construct a new XML::DTD::Parser object.

The parser will be validating, and hence will make parameter and character
entity substitutions, if the argument C<$val> is present and non-zero.

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

 my $dtduri = 'http://nonesuch.com/MyDTD.dtd'
 my $dtd = LWP::Simple::get($dtduri);
 $dp->parse(undef, $dtd, $dtduri);

Parse a DTD from a URL.

If the parser is validating, the URI of the document containing the DTD
should be passed. If it isn't, it is arbitrarily given the relative
URI C<unknown.dtd>.

 my $dp = DML::DTD::Parser->new(1);
 my $file = 'file.dtd'
 open(FH,"<$file");
 my $rt = '';
 $dp->parse(*FH, $rt, $file);

For a correct validating parse of a file.

If the URI isn't absolute, then it is converted into an absolute C<file:>
URI relative to the current working directory. The test for this assumes
that the URI scheme is more than one character long, so that a DOS drive
number isn't used as a scheme.

Since the default URI is relative, any relative
URIs in external entity declarations will be interpreted relative to a
(probably non-existent) file in the parser's current working directory.
In this case it's probably safest not to use relative URIs in the DTD
being parsed.

The order of parsing of C<$rt> and C<$file> is such that the internal subset
can be passed in C<$rt>, and the external subset in C<$file>, however, if
any of the output methods of subclass L<DTD|../DTD.pm> is called, the result
will be the merger of the internal and external subsets.

=back

=head1 SEE ALSO

L<XML::DTD>

=head1 AUTHOR

Brendt Wohlberg E<lt>wohl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2006 by Brendt Wohlberg

This library is available under the terms of the GNU General Public
License (GPL), described in the GPL file included in this distribution.

=head1 ACKNOWLEDGMENTS

Peter Lamb E<lt>Peter.Lamb@csiro.auE<gt> added fetching of external
entities, improved entity substitution, and implemented more robust
parsing of some classes of declaration.

=cut
