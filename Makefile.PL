use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'XML::DTD',
    'VERSION'           => '0.02',
#   'VERSION_FROM'	=> 'lib/XML/DTD.pm',
    'ABSTRACT_FROM'     => 'lib/XML/DTD.pm',
    'AUTHOR'            => 'Brendt Wohlberg <wohl@cpan.org>',
    'EXE_FILES'         => ['bin/dtdto'],
    'PREREQ_PM'         => {Getopt::Long => 0,
			    File::Temp => 0,
			    Carp => 0},
    'NO_META'           => 1
);


package MY;

sub MY::constants
{
    my $inherited = shift->SUPER::constants(@_);
    return "
$inherited
INST_SHAREDIR = blib/share
INSTALLSHAREDIR = \$(SITEPREFIX)/share
DESTINSTALLSHAREDIR = \$(DESTDIR)\$(INSTALLSHAREDIR)
";
}

sub MY::installbin
{
    my $inherited = shift->SUPER::installbin(@_);
    return "$inherited\t\$(NOECHO) \$(MKPATH) \$(INST_SHAREDIR)
\t\$(NOECHO) \$(MKPATH) \$(INST_SHAREDIR)/dtdto
\t\$(NOECHO) \$(CP) share/dtdto/*.xsl \$(INST_SHAREDIR)/dtdto
";
}

sub MY::install
{
    my $inherited = shift->SUPER::install(@_);
    my $insert0 = <<EOF;
\$(NOECHO) \$(MV) \$(INST_SCRIPT)/dtdto /tmp/dtdto.tmp; \\
\t\tsed -e 's+^use FindBin;.*++' -e 's+^my \$\$share =[^;]*+my \$\$share = \\"\${INSTALLSHAREDIR}\\"+' /tmp/dtdto.tmp > \$(INST_SCRIPT)/dtdto; \\
\t\t\$(CHMOD) \$(PERM_RWX) \$(INST_SCRIPT)/dtdto
EOF
    $inherited =~ s/\$\(NOECHO\) \$\(MOD_INSTALL\) \\/$insert0\t\$\(NOECHO\) \$\(MOD_INSTALL\) \\/g;
    my $insert1 = "\$(INST_SHAREDIR) \$(DESTINSTALLSHAREDIR)";
    $inherited =~ s/(\$\(INST_MAN3DIR\)[^\)]+\))/$1 \\\n\t\t$insert1/g;
    return $inherited;
}

