package XML::DTD::ContentModel;

use XML::DTD::Automaton;

use 5.008;
use strict;
use warnings;
use Carp;

our @ISA = qw();

our $VERSION = '0.01';


# Constructor
sub new {
  my $proto = shift; # Class name or object reference
  my $cmstr = shift; # Content model string
  my $entmn = shift; # Reference to EntityManager object

  my $cls = ref($proto) || $proto;
  my $obj = ref($proto) && $proto;

  my $self;
  if ($obj) {
    # Called as a copy constructor
    $self = { %$obj };
    my $child;
    $self->{'chldlst'} = [];
    foreach $child ( @{$obj->{'chldlst'}} ) {
      push @{$self->{'chldlst'}}, $child->new;
    }
    bless $self, $cls;
  } else {
    # Called as the main constructor
    carp "constructor called with undefined content model string"
      if (!defined $cmstr);
    $self = {
	     'chldlst' => [],    # List of child objects
	     'eltname' => undef, # Element name if leaf node of tree
	     'combnop' => undef, # Combine operator (choice or sequence)
	     'occurop' => undef  # Occurrence operator ('?', '*', or '+')
	    };
    bless $self, $cls;
    $self->_parse($cls, $cmstr, $entmn);
  }
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


# Return the list of child objects (subexpressions)
sub children {
  my $self = shift;

  return $self->{'chldlst'}
}


# Return the element name if the object is the leaf node of the tree
sub element {
  my $self = shift;

  return $self->{'eltname'}
}


# Return the combination operator (i.e. "," or "|")
sub combineop {
  my $self = shift;

  return $self->{'combnop'};
}


# Return the occurrence operator (i.e. "?","+", or "*")
sub occurop {
  my $self = shift;

  return $self->{'occurop'};
}


# The object is atomic (i.e. the model consists of a single element,
# ANY, EMPTY, or #PCDATA)
sub isatomic {
  my $self = shift;

  return ((scalar @{$self->{'chldlst'}}) == 0);
}


# Return a list of contained elements
sub childnames {
  my $self = shift;
  my $names = shift;

  my $en;
  $names = {} if (!defined $names);
  if ($self->isatomic) {
    $en = $self->element;
    $names->{$en} = 1 if ($en ne 'ANY' and $en ne 'EMPTY' and
			  $en ne '#PCDATA');
  } else {
    my $child;
    foreach $child (@{$self->children}) {
      $child->childnames($names);
    }
  }
  return [sort keys %$names];
}


# Build a string representation of the content model
sub string {
  my $self = shift;

  my $str = '';
  if ($self->isatomic) {
    $str = $self->element;
  } else {
    my $strlst = [];
    my $child;
    foreach $child ( @{$self->{'chldlst'}} ) {
      push @$strlst, $child->string;
    }
    $str .= '(' . join($self->combineop,@$strlst) . ')';
  }
  $str .= $self->occurop if (defined $self->occurop);
  return $str;
}


# Build a string representing the hierarchical structure of the model
sub treestring {
  my $self = shift;
  my $indent = shift;   # Indentation level
  my $showrefs = shift; # Flag selecting display of object references

  $indent = 0 if (!defined $indent);
  my $pre = '  ' x $indent;
  $pre .= "$self\t" if ($showrefs);
  my $cop = (defined $self->combineop)?$self->combineop:'';
  my $oop = (defined $self->occurop)?$self->occurop:'';
  my $cms = $self->string;
  my $str = sprintf("%-30s\t%s\t%s\n", $pre.$cms, $cop, $oop);
  my $child;
  foreach $child ( @{$self->{'chldlst'}} ) {
      $str .= $child->treestring($indent + 1, $showrefs);
  }
  return $str;
}


# Write component-specific part of the XML representation
sub writexmlelts {
  my $self = shift;
  my $xmlw = shift; # XML output object

  my $occur = (defined $self->{'occurop'} and $self->{'occurop'} ne '')?
    $self->{'occurop'}:undef;
  my $subop = (defined $self->{'combnop'} and $self->{'combnop'} ne '')?
    $self->{'combnop'}:undef;
  my $peref = (defined $self->{'peref'})?$self->{'peref'}:undef;
  if ($self->isatomic) {
    my $name = $self->element;
    my $label;
    if ($name eq '#PCDATA' or $name eq 'EMPTY' or $name eq 'ANY') {
      $label = 'type';
    } else {
      $label = 'name';
    }
    $xmlw->empty('child', {$label => $name, 'occur' => $occur,
			   'peref' => $peref});
  } else {
    $xmlw->open('children', {'occur' => $occur, 'subop' => $subop,
			     'peref' => $peref});
    my $c;
    foreach $c ( @{$self->{'chldlst'}} ) {
      $c->writexmlelts($xmlw);
    }
    $xmlw->close;
  }
}


# Determine the content specification type (empty, any, mixed, or element)
sub type {
  my $self = shift;

  if ($self->isatomic) {
    if ($self->element eq 'EMPTY') {
      return 'empty';
    } elsif ($self->element eq 'ANY') {
      return 'any';
    } elsif ($self->element eq '#PCDATA') {
      return 'mixed';
    } else {
      return 'element';
    }
  } else {
    my $oop = (defined $self->occurop)?$self->occurop:'';
    if ($self->combineop eq '|' and ($oop eq '' or $oop eq '*')) {
      my $chld = $self->children;
      my $c;
      foreach $c (@$chld) {
	return 'element' if (!$c->isatomic);
      }
      return 'element' if ($chld->[0]->element ne '#PCDATA');
      return 'mixed';
    } else {
      return 'element';
    }
  }
}


# Construct a DFA to validate the content model
sub dfa {
  my $self = shift;

  # The approach is to use Thompson's construction of an NDFA from a
  # regular expression, and then convert to Glushkov form via epsilon
  # state elimination. Since SGML/XML content models are constrained
  # to be unambiguous (or deterministic), the resulting automaton
  # should be deterministic. For background details see:
  # * Anne Brüggemann-Klein and Derick Wood, The Validation of SGML
  #   Content Models, Mathematical and Computer Modelling, 25, 73-84,
  #   1997
  #   (http://www11.informatik.tu-muenchen.de/~brueggem/papers/podpJournal.ps)
  # * Dora Giammarresi, Jean-Luc Ponty, and Derick Wood, Glushkov and
  #   Thompson Constructions: A Synthesis. Tech. Report 98-17. Università
  #   Ca' Foscari di Venezia.
  #   (http://www.mat.uniroma2.it/~giammarr/Research/Papers/gluth.ps.Z)

  # Construct an initial FSA object
  my $fsa = XML::DTD::Automaton->new;
  # Initial left index points to initial state
  my $ltn = 0;
  # Construct final state and set initial right index to its index
  my $rtn = $fsa->mkstate('Final', 1);
  # Call recursive FSA construction function
  $self->_buildfsa($fsa, $ltn, $rtn);
  # Eliminate epsilon transitions
  $fsa->epselim;
  # Remove unreachable states
  $fsa->rmunreach;
  # Ensure FSA is a DFA
  warn "FSA is not deterministic\n" if (!$fsa->isdeterministic);
  return $fsa;
}


# Parse content model string
sub _parse {
  my $self = shift;
  my $class = shift; # Class identity for calling new method
  my $cmstr = shift; # Content model string
  my $entmn = shift; # Entity manager

  # Remove spaces
  $cmstr =~ s/\s+//g;

  # Substitute entity values for references
  if (defined $entmn and
      $cmstr =~ /^%([\w\.:\-_]+);$|^\(%([\w\.:\-_]+);\)$/) {
    $self->{'peref'} = defined($1)?$1:$2;
    $cmstr = $entmn->pevalue($self->{'peref'});
  }

  # Temporary
  $self->{'cmstr'} = $cmstr;

  # Check whether model is a single element
  if ($cmstr =~ /^([A-Za-z_:][A-Za-z0-9-_:\.]*|#PCDATA)(\?|\+|\*)?$/ or
      $cmstr =~ /^\(([A-Za-z_:][A-Za-z0-9-_:\.]*|#PCDATA)(\?|\+|\*)?\)$/ or
      $cmstr =~ /^\(([A-Za-z_:][A-Za-z0-9-_:\.]*|#PCDATA)\)(\?|\+|\*)?$/) {
    # Just need to set element name and (optional) occurence operator
    $self->{'eltname'} = $1;
    $self->{'occurop'} = $2;
    #print "ATOMIC: |$cmstr|$1|".((defined $2)?$2:'')."\n";
    # Check whether model is a choice or sequence
  } elsif ($cmstr =~ /^\((.+)\)(\?|\+|\*)?$/) {
    # Set working string to content of parentheses and note occurence operator
    $cmstr = $1;
    $self->{'occurop'} = $2;
    ##print "EXPR0: |$cmstr|\n";
    # Deal with first sequence/choice child expression
    my $expr;
    # Check whether string has no parentheses preceding the first
    # sequence or choice character
    if ($cmstr =~ /^([^\(\)\,\|]*)(\,|\|)/) { # Combine operator first
      $expr = $1;
      $self->{'combnop'} = $2;
      #print "CMBNOP: $2   $cmstr\n";
      $cmstr = $';
      push @{$self->{'chldlst'}}, $class->new($expr, $entmn);
    } else { # Parenthesis first
      my ($mat, $pst) = _parenmatch($cmstr);
      # Check whether parenthesis post-match consists of an optional
      # occurence operator followed by a combine operator
      if ($pst =~ /^(\?|\+|\*)?(\,|\|)/) {
	$expr = $mat.(defined($1)?$1:'');
	$self->{'combnop'} = $2;
	#print "CMBNOP: $2   $cmstr\n";
	$cmstr = $';
	push @{$self->{'chldlst'}}, $class->new($expr, $entmn);
      } else {
	warn "invalid content model: $cmstr\n";
	return;
      }
    }

    # Work through remaining sequence/choice child expressions
    while ($cmstr ne '') {
      ##print "EXPRn: |$cmstr|\n";
      # Check whether string has no parentheses preceding the first
      # sequence or choice character
      if ($cmstr =~ /^([^\(\)\,\|]*)(\,|\||$)/) { # Combine operator first
	$expr = $1;
	# Should check that combine op $2 is correct
	$cmstr = $';
	push @{$self->{'chldlst'}}, $class->new($expr, $entmn);
      } else { # Parenthesis first
	my ($mat, $pst) = _parenmatch($cmstr);
	# Check whether parenthesis post-match consists of an optional
	# occurence operator followed by a combine operator
	if ($pst =~ /^(\?|\+|\*)?(\,|\||$)/) {
	  $expr = $mat.(defined($1)?$1:'');
	  # Should check that combine op $2 is correct
	  $cmstr = $';
	  push @{$self->{'chldlst'}}, $class->new($expr, $entmn);
	} else {
	  warn "invalid content model: $cmstr\n";
	  return;
	}
      }
    }
  } else {
    warn "invalid content model: $cmstr\n";
    return;
  }
}


# Find closing parenthesis matching first opening parenthesis in a
# string, and return a list consisting of the substrings including and
# after that closing parenthesis.
sub _parenmatch {
  my $str = shift;

  if ($str =~ /^([^\(\)]*)$/) { # String contains no parentheses
    return ('',$str);
  } elsif ($str =~ /^([^\(\)]*\()/) { # String contains an opening parenthesis
    # Set pre-match string to substring up to opening parenthesis
    my $pre = $1;
    # Call recursive part of function on substring after opening parenthesis
    my ($m, $p) = _parenrecurse($');
    if (defined $m) {
      return ($pre.$m, $p);
    } else {
      return undef;
    }
  } else {
    warn "Parenthesis matching error in $str\n";
    return undef;
  }
}


# Recursive part of function for parenthesis matching
sub _parenrecurse {
  my $str = shift;

  # Initialise match string
  my $mat = '';
  # Initialise post-match string
  my $pst = $str;
  if ($str =~ /^([^\(\)]*\()/) { # String contains an opening parenthesis
    # Set pre-match string to substring up to opening parenthesis
    my $pre = $1;
    # Do recursive call on substring after opening parenthesis
    my ($m, $p) = _parenrecurse($');
    # Append pre-match string and new matching component to match string
    $mat .= $pre.$m;
    # Set post-match string to new post-match component
    $pst = $p;
  }
  if ($pst =~ /^([^\(\)]*\))/) { # Post-match contains a closing parenthesis
    # Append substring up to closing parenthesis to match string
    $mat .= $1;
    # Set post-match to subtrstring after closing parenthesis
    $pst = $';
    return ($mat, $pst);
  } else {
    warn "Parenthesis matching error in $str\n";
    return undef;
  }
}


# Recursive part of function to build an FSA
sub _buildfsa {
  my $self = shift;
  my $fsa = shift; # FSA object
  my $ltn = shift; # Left (inbound) state index
  my $rtn = shift; # Right (outbound) state index

  # Content model expression is processed by building an FSA with
  # entry via state index $ltn and exit via state index $rtn. For each
  # subexpression, epsilon transitions are made to new entry and exit
  # states which are processed via a recursive call.

  if (defined $self->occurop and
      $self->occurop ne '') { # Need to deal with occurrence operator
    # Construct copy of this content model expression
    my $subexp = $self->new;
    # Remove occurrence operator from copy
    $subexp->{'occurop'} = undef;
    # Construct new left and right states labelled by the copied
    # content model expression
    my $ltn0 = $fsa->mkstate($subexp->string . '_lt');
    my $rtn0 = $fsa->mkstate($subexp->string . '_rt');
    if ($self->occurop eq '?') { # Occurrence operator is '?'
      # Construct relevant epsilon transitions
      $fsa->mktrans($ltn, $ltn0, '');
      $fsa->mktrans($rtn0, $rtn, '');
      $fsa->mktrans($ltn, $rtn, '');
    } elsif ($self->occurop eq '*') {  # Occurrence operator is '*'
      # Construct relevant epsilon transitions
      $fsa->mktrans($ltn, $ltn0, '');
      $fsa->mktrans($rtn0, $rtn, '');
      $fsa->mktrans($ltn, $rtn, '');
      $fsa->mktrans($rtn, $ltn0, '');
    } else {  # Occurrence operator is '+'
      # Construct relevant epsilon transitions
      $fsa->mktrans($ltn, $ltn0, '');
      $fsa->mktrans($rtn0, $rtn, '');
      $fsa->mktrans($rtn, $ltn0, '');
    }
    # Recursive call to deal with occurrence operator-free subexpression
    $subexp->_buildfsa($fsa, $ltn0, $rtn0);
  } else { # No occurrence operator
    if (defined $self->combineop and
	$self->combineop ne '') { # Need to deal with combine operator
      my ($chld, $ltn0, $rtn0);
      # Loop over each subexpression
      foreach $chld ( @{$self->{'chldlst'}} ) {
	# Construct new left and right states labelled by the current
	# content model subexpression
	$ltn0 = $fsa->mkstate($chld->string . '_lt');
	$rtn0 = $fsa->mkstate($chld->string . '_rt');
	if ($self->combineop eq ',') { # Combine operator is ','
	  # Construct epsilon transition from current left state to
	  # left state for current subexpression
	  $fsa->mktrans($ltn, $ltn0, '');
	  # Set current left state to right state for current subexpression
	  $ltn = $rtn0;
	} else { # Combine operator is '|'
	  # Construct epsilon transition from current left state to
	  # left state for current subexpression
	  $fsa->mktrans($ltn, $ltn0, '');
	  # Construct epsilon transition from current right state to
	  # right state for current subexpression
	  $fsa->mktrans($rtn0, $rtn, '');
	}
	# Recursive call to deal with current subexpression
	$chld->_buildfsa($fsa, $ltn0, $rtn0);
      }
      # If combine operator is ',', construct epsilon transition from
      # current right state to right state for current subexpression
      $fsa->mktrans($rtn0, $rtn, '') if ($self->combineop eq ',');
    } else { # No combine operator
      if ($self->isatomic) {
	# Expression is atomic, without occurrence operator
	$fsa->mktrans($ltn, $rtn, $self->element);
      } else {
	# Should never reach here
	carp "Error converting expression ".$self->string." to an FSA\n";
      }
    }
  }
}


1;

__END__

=head1 NAME

XML::DTD::ContentModel - Perl module representing an element content
model in an XML DTD

=head1 SYNOPSIS

  use XML::DTD::ContentModel;

  my $cm = XML::DTD::ContentModel->new('(a,b*,(c|d)+)');
  print $cm->treestring;

=head1 DESCRIPTION

XML::DTD::ContentModel is a Perl module representing an element content
model in an XML DTD. The following methods are provided.

=over 4

=item B<new>

 my $cm = XML::DTD::ContentModel->new('(a,b*,(c|d)+)');

 Construct a new XML::DTD::ContentModel object.

=item B<isa>

 if (XML::DTD::ContentModel->isa($obj) {
 ...
 }

Test object type.

=item B<children>

 my $objlst = $cm->children;

Return the list of child objects (subexpressions).

=item B<element>

 my $name = $cm->element;

Return the element name if the object has no subexpressions.

=item B<combineop>

 my $op = $cm->combineop;

Return the combination operator ("," or "|").

=item B<occurop>

 my $op = $cm->occurop;

Return the occurrence operator ("?","+", or "*").

=item B<isatomic>

 if ($cm->isatomic) {
 ...
 }

Determine whether the object is atomic (i.e. the model consists of a
single element, ANY, EMPTY, or #PCDATA).

=item B<childnames>

 my $nmlst = $cm->childnames;

 Return a list of contained elements.

=item B<string>

 print $cm->string;

Return a string representation of the content model.

=item B<treestring>

 print $cm->treestring;

Return a string representing the hierarchical structure of the model.

=item B<writexmlelts>

 open(FH,'>file.xml');
 my $xo = new XML::Output({'fh' => *FH});
 $cm->writexmlelts($xo);

Write a component-specific part of the XML representation.

=item B<type>

 my $typstr = $cm->type;

Determine the content specification type ('empty', 'any', 'mixed', or
'element').

=item B<dfa>

 my $dfa = $cm->dfa;

Construct a Deterministic Finite Automaton to validate the content model.

=back

=head1 SEE ALSO

L<XML::DTD>, L<XML::DTD::Element>, L<XML::DTD::Automaton>

=head1 AUTHOR

Brendt Wohlberg E<lt>wohl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Brendt Wohlberg

This library is available under the terms of the GNU General Public
License (GPL), described in the GPL file included in this distribution.

=cut
