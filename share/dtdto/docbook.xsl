<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE xsl:stylesheet [ <!ENTITY nbsp "&#160;"> ]>
<!--
     XSL stylesheet for converting XML representation of a DTD to Docbook
     Brendt Wohlberg     14 May 2006
  -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xlink="http://www.w3.org/1999/xlink"
                exclude-result-prefixes="xlink" version="1.0">



<xsl:output method="xml" indent="yes" encoding="iso-8859-1"/>

<!--
   <xsl:output method="xml" indent="yes"
    doctype-public="-//OASIS//DTD DocBook XML V4.1.2//EN"
    doctype-system="http://www.oasis-open.org/docbook/xml/4.1.2/docbookx.dtd"
    encoding="iso-8859-1" />
-->



<!-- Stylesheet parameter determining whether to expand or display 
     general entity definitions -->
<xsl:param name="expand-general-entities">1</xsl:param>

<!-- Stylesheet parameter determining whether to expand or display 
     parameter entity definitions -->
<xsl:param name="expand-parameter-entities">0</xsl:param>

<!-- Stylesheet parameter setting the document title -->
<xsl:param name="document-title">DTD Description</xsl:param>

<!-- Stylesheet parameter setting an anchor name prefix to avoid name 
     collision when multiple outputs are included in a single document -->
<xsl:param name="anchor-prefix">dtd-</xsl:param>

<!-- Stylesheet parameter setting the top level Docbook element -->
<xsl:param name="enclosing-element">appendix</xsl:param>

<!-- Stylesheet parameter setting the top level Docbook element id
     attribute -->
<xsl:param name="enclosing-element-id"/>



<!-- Template matching the document root -->
<xsl:template match="dtd">
  <xsl:choose>
    <xsl:when test="$enclosing-element != '0'">
      <xsl:element name="{$enclosing-element}">
        <xsl:if test="$enclosing-element-id">
          <xsl:attribute name="id">
            <xsl:value-of select="$enclosing-element-id"/>
          </xsl:attribute>
        </xsl:if>
        <xsl:call-template name="main" select="/dtd"/>
      </xsl:element>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="main" select="/dtd"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>



<!-- Template constructing main content -->
<xsl:template name="main">
  <xsl:if test="$enclosing-element != '0'">
    <title>
      <xsl:value-of select="$document-title"/>
    </title>
  </xsl:if>

  <!-- Include the first comment in the DTD as general DTD information -->
  <para role="dtdtopcmnt">
    <literallayout>
      <xsl:value-of select="comment[position()=1]"/>
    </literallayout>
  </para>

  <!-- Details of general entities -->
  <xsl:if test="$expand-general-entities!=1 and //entity[@type='gen']">
    <section>
      <title>General Entities</title>  
      <xsl:for-each select="entity[@type='gen']">
        <xsl:call-template name="entity"/>
      </xsl:for-each>
    </section>
  </xsl:if>

  <!-- Details of parameter entities -->
  <xsl:if test="$expand-parameter-entities!=1 and //entity[@type='param']">
    <section>
      <title>Parameter Entities</title>
      <xsl:for-each select="entity[@type='param']">
        <xsl:call-template name="entity"/>
      </xsl:for-each>
    </section>
  </xsl:if>
    
  <!-- Details of elements -->
  <section>
    <title>Elements</title>
    <xsl:for-each select="element">
      <xsl:call-template name="element"/>
    </xsl:for-each>
  </section>

</xsl:template>



<!-- Template for processing element declarations -->
<xsl:template match="element" name="element">
  <xsl:variable name="name" select="@name"/>

  <section role="dtdeltsec"> 
    <!-- Section title consisting of element name -->
    <title>
      <emphasis role="dtdelttitle">
        <xsl:value-of select="@name"/>
      </emphasis>
      <anchor>
        <xsl:attribute name="id">
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>elt-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
      </anchor>
    </title>
    <!-- Comment describing the element -->
    <para role="dtdeltdesc">
      <xsl:if test="preceding-sibling::*[@nlf=1 and position()=1 and 
                                         name()='wspace'] and 
                    preceding-sibling::*[position()=2 and name()='comment']">
        <xsl:value-of select="preceding-sibling::comment[position()=1]"/>
      </xsl:if>
    </para>
    <!-- The element definiton -->
    <para role="dtdeltdef">
      <informaltable frame="none">
        <tgroup align="left" cols="4">
          <colspec colnum="2" colname="attriblt"/>
          <colspec colnum="4" colname="attribrt"/>
          <spanspec namest="attriblt" nameend="attribrt" 
                    spanname="eltcontent"/>
          <tbody valign="top">
            <!-- The element content model -->
            <row>
              <entry>Content&nbsp;model</entry>
              <entry spanname="eltcontent">
                <xsl:apply-templates select="child|children"/>
              </entry>
            </row>
            <!-- Details of the element attributes, if any -->
            <xsl:if test="//attlist[@name=$name]">             
              <xsl:apply-templates select="//attlist[@name=$name]"/>
            </xsl:if>
            <!-- The list of possible parent elements -->
            <row>
              <entry>Used&nbsp;inside</entry>
              <entry spanname="eltcontent">
                <xsl:call-template name="usedinside">
                  <xsl:with-param name="name" select="$name"/>
                </xsl:call-template>
              </entry>
            </row>
          </tbody>
        </tgroup>
      </informaltable>
    </para>
  </section>

</xsl:template>



<!-- Template for formatting eltname elements -->
<xsl:template match="eltname">
  <link>
    <xsl:attribute name="linkend">
      <xsl:value-of select="$anchor-prefix"/>
      <xsl:text>elt-</xsl:text>
      <xsl:value-of select="."/>
    </xsl:attribute>
    <emphasis role="dtdeltname">
      <xsl:value-of select="."/>
    </emphasis>
  </link>
</xsl:template>


<!-- Template for formatting the element content model -->
<xsl:template match="children">
  <xsl:text>(</xsl:text>
  <xsl:for-each select="child|children">
    <xsl:apply-templates select="."/>
    <xsl:if test="position() != last()">
      <xsl:if test="../@subop = '|'">
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:value-of select="../@subop"/>
      <xsl:text> </xsl:text>
    </xsl:if>
  </xsl:for-each>
  <xsl:text>)</xsl:text>
  <xsl:value-of select="@occur"/>
</xsl:template>



<!-- Template for formatting the element content model -->
<xsl:template match="child">
  <xsl:choose>
    <xsl:when test="@type">
      <xsl:choose>
        <xsl:when test="@peref">
          <link>
            <xsl:attribute name="linkend">
              <xsl:value-of select="$anchor-prefix"/>
              <xsl:text>pe-</xsl:text>
              <xsl:value-of select="@peref"/>
            </xsl:attribute>
            <xsl:text>%</xsl:text>
            <xsl:value-of select="@peref"/>
            <xsl:text>;</xsl:text>
          </link>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@type"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <link>
        <xsl:attribute name="linkend">
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>elt-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
        <emphasis role="dtdeltname">
          <xsl:value-of select="@name"/>
        </emphasis>
      </link>
      <xsl:value-of select="@occur"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>



<!-- Template for formatting attlist elements -->
<xsl:template match="attlist">
  <xsl:for-each select="attdefs/attdef">
    <row>
      <entry>
        <xsl:if test="position()=1">
          <xsl:text>Attributes</xsl:text>
        </xsl:if>
      </entry>
      <entry>
        <xsl:value-of select="@name"/>
      </entry>
      <entry>
        <xsl:value-of select="atttype"/>
      </entry>
      <entry>
        <xsl:apply-templates select="defaultdecl"/>
      </entry>
    </row>
  </xsl:for-each>
</xsl:template>


<!-- Template for constructing the list of "used inside" elements -->
<xsl:template name="usedinside">
  <xsl:param name="name"/>
  <xsl:for-each select="//element[descendant::child/@name=$name]">
    <link>
      <xsl:attribute name="linkend">
        <xsl:value-of select="$anchor-prefix"/>
        <xsl:text>elt-</xsl:text>
        <xsl:value-of select="@name"/>
      </xsl:attribute>
      <emphasis role="dtdeltname">
        <xsl:value-of select="@name"/>
      </emphasis>
    </link>
    <xsl:if test="position() != last()">
      <xsl:text> | </xsl:text>
    </xsl:if>
  </xsl:for-each>
</xsl:template>


<!-- Template for formatting peref elements -->
<xsl:template match="peref">
  <xsl:choose>
    <xsl:when test="$expand-parameter-entities=1">
      <xsl:variable name="name" select="@name"/>
      <xsl:value-of select="//pedef[@name=$name]"/>
    </xsl:when>
    <xsl:otherwise>
      <link>
        <xsl:attribute name="linkend">
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>pe-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
        <emphasis role="dtdperef">
          <xsl:value-of select="."/>
        </emphasis>
      </link>
    </xsl:otherwise>
  </xsl:choose>  
</xsl:template>



<!-- Template for formatting geref elements -->
<xsl:template match="geref">
  <xsl:choose>
    <xsl:when test="$expand-general-entities=1">
      <xsl:variable name="name" select="@name"/>
      <xsl:value-of select="//gedef[@name=$name]" 
                    disable-output-escaping="yes"/>
    </xsl:when>
    <xsl:otherwise>
      <link>
        <xsl:attribute name="linkend">
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>ge-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
        <emphasis role="dtdgeref">
          <xsl:text>&amp;</xsl:text>
          <xsl:value-of select="@name"/>
          <xsl:text>;</xsl:text>
        </emphasis>
      </link>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<!-- Template for formatting dfltdcl elements -->
<xsl:template match="dfltdcl">
  <xsl:apply-templates/>
</xsl:template>



<!-- Template for processing entity declarations -->
<xsl:template match="entity" name="entity">
  <section>
    <title>
      <emphasis role="entdeftitle">
        <anchor>
          <xsl:attribute name="id">
            <xsl:value-of select="$anchor-prefix"/>
            <xsl:choose>
              <xsl:when test="name(.) = 'gedef'">
                <xsl:text>ge-</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>pe-</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="@name"/>
          </xsl:attribute>
        </anchor>
        <xsl:value-of select="@name"/>
      </emphasis>
    </title>
    <xsl:variable name="name" select="@name"/>
    <!-- A relevant comment precedes the entity definition, separated by a 
         white space with a single linefeed, or directly follows the
         entity definition -->
    <para role="entcmnt">
      <xsl:choose>
        <xsl:when test="preceding-sibling::*[@nlf=1 and position()=1 and 
                                             name()='wspace'] and 
                        preceding-sibling::*[position()=2 and 
                                             name()='comment']">
          <xsl:value-of select="preceding-sibling::comment[position()=1]"/>
        </xsl:when>
        <xsl:when test="following-sibling::*[position()=1 and 
                                             name()='comment'] or 
                        (following-sibling::*[@nlf=0 and position()=1 and 
                                              name()='wspace'] and 
                         following-sibling::*[position()=2 and 
                                              name()='comment'])">
          <xsl:value-of select="following-sibling::comment[position()=1]"/>
        </xsl:when>
      </xsl:choose>
    </para>
    <para role="entdefsec">
      <informaltable frame="none">
        <tgroup align="left" cols="2">
          <tbody valign="top">
            <row>
              <entry>Definition</entry>
              <entry>
                <xsl:choose>
                  <xsl:when test="@type='param' and child::external">
                    <xsl:if test="external/public">
                      <xsl:text>PUBLIC </xsl:text>
                      <xsl:value-of select="external/public/@qchar"/>
                      <xsl:value-of select="external/public"/>
                      <xsl:value-of select="external/public/@qchar"/>
                      <xsl:text> </xsl:text>
                    </xsl:if>
                    <xsl:if test="not(external/public)">
                      <xsl:text>SYSTEM </xsl:text>
                    </xsl:if>
                    <xsl:value-of select="external/system/@qchar"/>
                    <xsl:value-of select="external/system"/>
                    <xsl:value-of select="external/system/@qchar"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="@qchar"/>
                    <xsl:value-of select="."/>
                    <xsl:value-of select="@qchar"/>
                  </xsl:otherwise>
                </xsl:choose>
              </entry>
            </row>
          </tbody>
        </tgroup>
      </informaltable>      
    </para>
  </section>
</xsl:template>
  

</xsl:stylesheet>
