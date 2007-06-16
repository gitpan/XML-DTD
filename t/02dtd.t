# -*- cperl -*-
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 02dtd.t'

#########################

use Test::More tests => 1 + 2*10;
BEGIN { use_ok('XML::DTD') };

#########################

my ($txt, $dtd);

$txt = <<EOF;
<!-- Comment -->
<!ELEMENT a (#PCDATA)>
<!ATTLIST a b CDATA #IMPLIED>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!ENTITY % c "   ">
<!NOTATION e PUBLIC "+//F//G//EN">
<?h i?>
%c;
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<![ IGNORE [
               ignored text
  <![[ IGNORE
  ]]>
]]>
<!-- A comment -->
<![ INCLUDE [
  <!-- Comment inside include -->
  <!ELEMENT j (#PCDATA)>
]]>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!-- Another comment -->
<!ENTITY % cond 'INCLUDE'>
<![ %cond; [
  <!-- Comment inside include -->
  <!ELEMENT k (#PCDATA)>
]]>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!ENTITY deg "&#176;">
<!ELEMENT temp (#PCDATA)>
<!ATTLIST temp units CDATA '&deg;C'>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!ENTITY % xml-lang-attribute "xml:lang NMTOKEN #IMPLIED" >
<!ELEMENT a (b+)>
<!ELEMENT b (#PCDATA)>
<!ATTLIST b %xml-lang-attribute;>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!ENTITY % x "c">
<!ELEMENT a (a|b|%x;|d)>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!ENTITY % class1 "a|b|c">
<!ENTITY % class2 "d|e|f">
<!ELEMENT g (#PCDATA | %class1; | %class2;)*>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!ENTITY % class "a | b | c | d
                  e | f">
<!ELEMENT g (#PCDATA | %class;)*>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);



$txt = <<EOF;
<!ENTITY % x "c|d">
<!ENTITY % y "%x;|e">
<!ELEMENT a (a|b|%y;|f)>
EOF
$dtd = new XML::DTD;
ok($dtd->sread($txt));
is($dtd->swrite(), $txt);


