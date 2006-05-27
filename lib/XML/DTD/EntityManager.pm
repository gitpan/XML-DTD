package XML::DTD::EntityManager;

use 5.008;
use strict;
use warnings;
use Carp;

our @ISA = qw();

our $VERSION = '0.01';


# Constructor
sub new {
  my $arg = shift;
  my $ent = shift;

  my $cls = ref($arg) || $arg;
  my $obj = ref($arg) && $arg;

  my $self;
  if ($obj) {
    # Called as a copy constructor
    $self = { %$obj };
  } else {
    # Called as the main constructor
    $self = { };
    $self->{'PARAMETER'} = { };
    $self->{'GENERAL'} = { };
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


# Insert an entity
sub insert {
  my $self = shift;
  my $ent = shift;

  if ($ent->isparam) {
    $self->insertpe($ent);
  } else {
    $self->insertge($ent);
  }
}


# Insert a parameter entity declaration
sub insertpe {
  my $self = shift;
  my $pe = shift;

  my $name = $pe->name;
  if (defined($self->{'PARAMETER'}->{$name})) {
    return 0;
  } else {
    $self->{'PARAMETER'}->{$name} = $pe;
    return 1;
  }
}


# Lookup a parameter entity declaration
sub pevalue {
  my $self = shift;
  my $peref = shift;

  $peref = $1 if ($peref =~ /^%(.+);$/);
  my $ent = $self->{'PARAMETER'}->{$peref};
  if (defined $ent) {
    return $ent->value;
  } else {
    return undef;
  }
}


# Insert a general entity declaration
sub insertge {
  my $self = shift;
  my $ge = shift;

  my $name = $ge->name;
  if (defined($self->{'GENERAL'}->{$name})) {
    return 0;
  } else {
    $self->{'GENERAL'}->{$name} = $ge;
    return 1;
  }
}


# Lookup a general entity declaration
sub gevalue {
  my $self = shift;
  my $geref = shift;

  $geref = $1 if ($geref =~ /^\&(.+);$/);
  my $ent = $self->{'GENERAL'}->{$geref};
  if (defined $ent) {
    return $ent->value;
  } else {
    return undef;
  }
}


# Perform entity substitution in text
sub entitysubst {
  my $self = shift;
  my $txt = shift;

  my $entv;
  my $lt = '';
  my $rt = $txt;
  while ($rt =~ /(%|\&)([\w\.:\-_]+);/) {
    $rt = $';
    $lt .= $`;
    if ($1 eq '%') {
      $entv = $self->pevalue($2);
    } else {
      $entv = $self->gevalue($2);
    }
    if (defined $entv) {
      $lt .= $entv;
    } else {
      $lt .= $1.$2.';';
      carp 'undefined entity referenced';
    }
  }
  $lt .= $rt;
  return $lt;
}


1;
__END__

=head1 NAME

XML::DTD::EntityManager - Perl module for managing entity declarations in a DTD

=head1 SYNOPSIS

  use XML::DTD::EntityManager;

  my $em = XML::DTD::EntityManager->new;

=head1 DESCRIPTION

XML::DTD::EntityManager is a Perl module for managing entity
declarations in a DTD. The following methods are provided.

=over 4

=item B<new>

 my $em = XML::DTD::EntityManager->new;

Construct a new XML::DTD::EntityManager object.

=item B<isa>

 if (XML::DTD::EntityManager->isa($obj) {
 ...
 }

Test object type.

=item B<insert>

 my $ent = XML::DTD::Entity->new('<!ENTITY a "b">');
 $em->insert($ent);

Insert an entity declaration.

=item B<insertpe>

 my $ent = XML::DTD::Entity->new('<!ENTITY % a "b">');
 $em->insertpe($ent);

Insert a parameter entity declaration.

=item B<pevalue>

 my $val = $em->pevalue('%a;');

Lookup a parameter entity value.

=item B<insertge>

 my $ent = XML::DTD::Entity->new('<!ENTITY a "b">');
 $em->insertge($ent);

Insert a general entity declaration.

=item B<gevalue>

 my $val = $em->pevalue('&a;');

Lookup a general entity value.

=item B<entitysubst>

 my $txt = $em->entitysubst('abc &a; def');

Perform entity substitution in text.

=back

=head1 SEE ALSO

L<XML::DTD>, L<XML::DTD::Entity>

=head1 AUTHOR

Brendt Wohlberg E<lt>wohl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2006 by Brendt Wohlberg

This library is available under the terms of the GNU General Public
License (GPL), described in the GPL file included in this distribution.

=cut
