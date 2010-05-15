use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'XML::DTD',
    'VERSION_FROM'      => 'lib/XML/DTD.pm',
    'ABSTRACT_FROM'     => 'lib/XML/DTD.pm',
    'AUTHOR'            => 'Brendt Wohlberg <wohl@cpan.org>',
    'EXE_FILES'         => ['bin/dtdto'],
    'PREREQ_PM'         => {Getopt::Long => 0,
			    File::Temp => 0,
			    URI::file => 0,
			    LWP::Simple => 0,
			    Error => 0},
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
    $inherited =~ s/\s+$//s;
    return "$inherited\n\t\$(NOECHO) \$(MKPATH) \$(INST_SHAREDIR)
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
    chomp $insert0;
    $inherited =~ s/(pure_[a-z]+_install\s+::.*)/$1\n\t$insert0/g;
    my $insert1 = "\$(INST_SHAREDIR) \$(DESTINSTALLSHAREDIR)";
    $inherited =~ s/(\$\(INST_MAN3DIR\)[^\)]+\))/$1 \\\n\t\t$insert1/g;
    return $inherited;
}
