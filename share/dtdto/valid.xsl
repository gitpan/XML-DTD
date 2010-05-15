<?xml version="1.0"?>
<!--
     XSL stylesheet for generating a DTD validation XSL stylesheet
     Brendt Wohlberg     21 October 2009
  -->

<xslt:stylesheet xmlns:xslt="http://www.w3.org/1999/XSL/Transform"
                 xmlns:fnct="http://exslt.org/functions"
                 xmlns:xsl="xsl.aliased.namespace"
                 xmlns:func="func.aliased.namespace"
                 xmlns:vldt="http://search.cpan.org/~wohl/XML-DTD/validate"
                 exclude-result-prefixes="fnct" version="1.0">

<xslt:output method="xml" indent="yes"/>
<xslt:namespace-alias stylesheet-prefix="xsl" result-prefix="xslt"/>
<xslt:namespace-alias stylesheet-prefix="func" result-prefix="fnct"/> 

<xslt:template match="/">
  <xsl:stylesheet version="1.0" extension-element-prefixes="func">
    
    <xslt:comment/>

    <xslt:comment> This DTD validation XSL stylesheet generated by dtdto,
     distributed with the XML::DTD Perl module available
     from http://search.cpan.org/~wohl/XML-DTD/. </xslt:comment>

    <xslt:comment/>

    <xsl:output method="text"/>
    
    <xslt:comment/>

    <!-- Match root node. -->
    <xsl:template match="/">

      <!-- Variable $result contains result of xsl:apply-templates to
           all element children of the root node. -->
      <xsl:variable name="result">
        <xsl:for-each select="*">
          <xsl:apply-templates select=".">
            <xsl:with-param name="p" select="concat('/',name(.))"/>
          </xsl:apply-templates>
        </xsl:for-each>
      </xsl:variable>
    
      <!-- Return string 'valid' if $return is empty, otherwise return
           the 'invalid' message from $return. -->
      <xsl:choose>
        <xsl:when test="$result=''">
          <xsl:text>valid</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$result"/>
        </xsl:otherwise>
      </xsl:choose>

    </xsl:template>

    <xslt:comment/>

    <!-- Match all elements. Parameter $p is a string containing the
         absolute path up to the current node. -->
    <xsl:template match="*">
      <xsl:param name="p" select="''"/>
    
      <xsl:choose>
        <!-- If the current element is valid, apply templates for each
             of its child elements. -->
        <xsl:when test="vldt:valid(.)">
          <xsl:for-each select="*">
            <!-- Define variables $presib and $folsib representing the
                 number of preceding and following siblings with the
                 same name as the current element. -->
            <xsl:variable name="presib" 
              select="count(preceding-sibling::*[name(.)=name(current())])"/>
            <xsl:variable name="folsib" 
              select="count(following-sibling::*[name(.)=name(current())])"/>
            <!-- Define variable $posstr to be the empty string if the
                 current element has no siblings with the same name,
                 or the path position of the current element if it does. -->
            <xsl:variable name="posstr">
              <xsl:if test="$presib + $folsib &gt; 0">
                <xsl:value-of select="concat('[',$presib+1,']')"/>
              </xsl:if>
            </xsl:variable>
            <xsl:apply-templates select=".">
              <xsl:with-param name="p" 
                              select="concat($p,'/',name(.),$posstr)"/>
            </xsl:apply-templates>
          </xsl:for-each>
        </xsl:when>
        <!-- If the current element is invalid, return 'invalid' and
             the path to the current element. -->
        <xsl:otherwise>
          <xsl:value-of select="concat('invalid ',$p)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xslt:comment/>

    <!-- Validate the subtree in parameter $x. -->
    <func:function name="vldt:valid">
      <xsl:param name="x" select="/.."/>
      
      <!-- Define variable $eltdef to be the DTD-derived content model
           definition for the root element of the subtree in $x. -->
      <xsl:variable name="eltdef"
        select="document('')//vldt:dtdvalidate/element[@name=name($x)]"/>
 
      <!-- Define variable $result containing function return value. -->
      <xsl:variable name="result">
        <xsl:choose>
          <!-- If the element content is 'ANY', it is always valid. -->
          <xsl:when test="$eltdef/@type='any'">
            <xsl:value-of select="true()"/>
          </xsl:when>
          <!-- If the element content is 'EMPTY', it is valid if it
               contains no element or text children. -->
          <xsl:when test="$eltdef/@type='empty'">
            <xsl:choose>
              <xsl:when test='*|text()'>
                <xsl:value-of select="false()"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="true()"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <!-- If the element content has mixed content, pass $x and
               the relevant mixed content specification to function
               vldt:validmixed. -->
          <xsl:when test="$eltdef/@type='mixed'">
            <xsl:value-of select="vldt:validmixed($x,$eltdef/mixed)"/>
          </xsl:when>
          <!-- If the element has element content, pass $x and the
               relevant validation automaton to function
               vldt:validelement. -->
          <xsl:when test="$eltdef/@type='element'">
            <xsl:value-of select="vldt:validelement($x,$eltdef/fsa)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="false()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
    
      <func:result select="$result='true'"/>

    </func:function>
         
    <xslt:comment/>

    <!-- Validate the subtree in parameter $x using the mixed content
         model specification in $y. -->
    <func:function name="vldt:validmixed">
      <xsl:param name="x" select="/.."/>
      <xsl:param name="y" select="/.."/>

      <!-- Define variable $chldmatch to contain a '1' character for
           every element child in $x that does not have a
           correspondingly named entry in the mixed content
           specification $y. -->
      <xsl:variable name="chldmatch">
        <xsl:for-each select="$x/*">
          <xsl:if test="not($y/child[@name=name(current())])">
            <xsl:text>1</xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
    
      <!-- Result is valid if $chldmatch is the empty string. -->
      <func:result select="$chldmatch=''"/>
    </func:function>

    <xslt:comment/>

    <!-- Validate the subtree in parameter $x according to the
         content model corresponding to the automaton specified in
         $y. Parameter $n is the position of the current $x child
         element, and $s is the current automaton state index. -->
    <func:function name="vldt:validelement">
      <xsl:param name="x" select="/.."/>
      <xsl:param name="y" select="/.."/>
      <xsl:param name="n" select="1"/>
      <xsl:param name="s" select="0"/>

      <!-- Define variable $state to be the state indexed by $s. -->
      <xsl:variable name="state" select="$y/state[@index=$s]"/>
      <!-- Define variable $trans to be the transition with symbol
           corresponding to the current $x child element, indexed 
           by $n. -->
      <xsl:variable name="trans" 
        select="$state/transition[@symbol=name($x/*[$n])]"/>

      <!-- Define variable $result containing function return value. -->
      <xsl:variable name="result">
        <xsl:choose>
          <!-- If $n is greater than the index of the last subtree
               child, the subtree (root element) is valid if the
               current state is marked as a final state. -->
          <xsl:when test="$n &gt; count($x/*)">
            <xsl:value-of select="$state/@final=1"/>
          </xsl:when>
          <!-- If the current state of the automaton has a transition
               with symbol corresponding to the name of the current
               subtree child element, do a recursive call to
               vldt:validelement, moving the current subtree child
               element along one position, and moving the current
               state to the destination state of this transition. -->
          <xsl:when test="$trans">
            <xsl:value-of select="vldt:validelement($x, $y, $n+1, 
                                    number($trans/@destination))"/>
          </xsl:when>
          <!-- The subtree (root element) is invalid if neither of the
               previous conditions is satisfied. -->
          <xsl:otherwise>
            <xsl:value-of select="false()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
    
      <func:result select="$result='true'"/>
    </func:function>

    <xslt:comment/>
    
    <vldt:dtdvalidate>
      <xslt:copy-of select="dtdvalidate/*"/>
    </vldt:dtdvalidate>
    
    <xslt:comment/>
    
  </xsl:stylesheet>
  
</xslt:template>

</xslt:stylesheet>
