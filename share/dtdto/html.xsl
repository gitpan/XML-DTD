<?xml version="1.0" encoding="iso-8859-1"?>
<!--
     XSL stylesheet for converting XML representation of a DTD to HTML
     Brendt Wohlberg     14 May 2006
  -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xlink="http://www.w3.org/1999/xlink"
                exclude-result-prefixes="xlink" version="1.0">

<xsl:output method="xml" indent="yes"
	    doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
            doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
	    encoding="iso-8859-1" />


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



<!-- Template matching the document root -->
<xsl:template match="dtd">
 <html>
    <head>
      <title>
        <xsl:value-of select="$document-title"/>
      </title>
      <xsl:call-template name="style"/>
    </head>

    <body>

      <!-- Include the first comment in the DTD as general DTD information -->
      <div class="dtdheadcmnt">
        <pre>
          <xsl:value-of select="comment[position()=1]"/>
        </pre>
      </div>

      <div class="spacing"></div>

      <!-- Details of general entities -->
      <xsl:if test="$expand-general-entities!=1 and //entity[@type='gen']">
        <h2>General Entities</h2>

        <xsl:for-each select="entity[@type='gen']">
          <xsl:call-template name="entity"/>
        </xsl:for-each>
        
        <div class="spacing"></div>
      </xsl:if>

      <!-- Details of parameter entities -->
      <xsl:if test="$expand-parameter-entities!=1 and //entity[@type='param']">
        <h2>Parameter Entities</h2>
        
        <xsl:for-each select="entity[@type='param']">
          <xsl:call-template name="entity"/>
        </xsl:for-each>
        
        <div class="spacing"></div>
      </xsl:if>
      
      <!-- Details of elements -->
      <h2>Elements</h2>

      <xsl:for-each select="element">
        <xsl:call-template name="element"/>
      </xsl:for-each>
      
    </body>
  </html>
</xsl:template>



<!-- Template for processing element declarations -->
<xsl:template match="element" name="element">
  <div class="eltdef">
    <hr style="size:4;width:100%;align:left;noshade:noshade"/>
    <!-- Create title with anchor for the element name -->
    <span class="eltdeftitle">
      <a>
        <xsl:attribute name="name">
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>elt-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
      </a>
      <xsl:value-of select="@name"/>
    </span>
    <xsl:variable name="name" select="@name"/>
    <!-- A comment is an element description if it precedes that element 
         declaration and is only seperated from the element declaration by 
         white space with a single linefeed -->
    <div class="eltcmnt">
      <xsl:if test="preceding-sibling::*[@nlf=1 and position()=1 and 
                                         name()='wspace'] and 
                    preceding-sibling::*[position()=2 and name()='comment']">
        <xsl:value-of select="preceding-sibling::comment[position()=1]"/>
      </xsl:if>
    </div>
    <!-- Details of the element content model -->
    <div class="eltdefsec">
      <span class="eltdefsectitle">
        <xsl:text>Content model </xsl:text>
      </span>
      <div class="eltdefsecbody">
        <xsl:apply-templates select="child|children"/>
      </div>
    </div>
    <!-- Details of the elements attributes, if any -->
    <xsl:if test="//attlist[@name=$name]">
      <div class="eltdefsec">
        <hr style="size:2;width:100%;align:left;noshade:noshade"/>
        <span class="eltdefsectitle">
          <xsl:text>Attributes </xsl:text>
        </span>
        <div class="eltdefsecbody">
          <xsl:apply-templates select="//attlist[@name=$name]"/>
        </div>
      </div>
    </xsl:if>
    <!-- Details of the valid parent elements of this element -->
    <div class="eltdefsec">
      <hr style="size:2;width:100%;align:left;noshade:noshade"/>
      <span class="eltdefsectitle">
        <xsl:text>Used inside </xsl:text>
      </span>
      <div class="eltdefsecbody">
        <xsl:for-each select="//element[descendant::child/@name=$name]">
          <a>
            <xsl:attribute name="href">
              <xsl:text>#</xsl:text>
              <xsl:value-of select="$anchor-prefix"/>
              <xsl:text>elt-</xsl:text>
              <xsl:value-of select="@name"/>
            </xsl:attribute>
            <xsl:value-of select="@name"/>
          </a>
          <xsl:if test="position() != last()">
            <xsl:text> | </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </div>
    </div>
  </div>
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
          <a>
            <xsl:attribute name="href">
              <xsl:text>#</xsl:text>
              <xsl:value-of select="$anchor-prefix"/>
              <xsl:text>pe-</xsl:text>
              <xsl:value-of select="@peref"/>
            </xsl:attribute>
            <xsl:text>%</xsl:text>
            <xsl:value-of select="@peref"/>
            <xsl:text>;</xsl:text>
          </a>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@type"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <a>
        <xsl:attribute name="href">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>elt-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
        <xsl:value-of select="@name"/>
      </a>
      <xsl:value-of select="@occur"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>



<!-- Template for formatting peref elements -->
<xsl:template match="peref">
  <xsl:choose>
    <xsl:when test="$expand-parameter-entities=1">
      <xsl:variable name="name" select="@name"/>
      <xsl:value-of select="//pedef[@name=$name]"/>
    </xsl:when>
    <xsl:otherwise>
      <a>
        <xsl:attribute name="href">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>pe-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
        <em><xsl:value-of select="."/></em>
      </a>
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
      <a>
        <xsl:attribute name="href">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:text>ge-</xsl:text>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
        <em>
          <xsl:text>&amp;</xsl:text>
          <xsl:value-of select="@name"/>
          <xsl:text>;</xsl:text>
        </em>
      </a>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>



<!-- Template for formatting attlist elements -->
<xsl:template match="attlist">
  <xsl:if test="attdefs">
    <table>
      <tbody>
        <xsl:for-each select="attdefs/attdef">
          <tr>
            <td class="attrow">
              <xsl:value-of select="@name"/>
            </td>
            <td class="attrow">
              <xsl:value-of select="atttype"/>
            </td>
            <td class="attrow">
              <xsl:apply-templates select="defaultdecl"/>
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:if>
</xsl:template>



<!-- Template for formatting dfltdcl elements -->
<xsl:template match="dfltdcl">
  <xsl:apply-templates/>
</xsl:template>



<!-- Template for processing entity declarations -->
<xsl:template match="entity" name="entity">
  <div class="entdef">
    <hr style="size:5;width:100%;align:left;noshade:noshade"/>
    <span class="entdeftitle">
      <a>
        <xsl:attribute name="name">
          <xsl:value-of select="$anchor-prefix"/>
          <xsl:choose>
            <xsl:when test="./@type = 'gen'">
              <xsl:text>ge-</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>pe-</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:value-of select="@name"/>
        </xsl:attribute>
      </a>
      <xsl:value-of select="@name"/>
    </span>
    <xsl:variable name="name" select="@name"/>
    <!-- A relevant comment precedes the entity definition, separated by a 
         white space with a single linefeed, or directly follows the
         entity definition -->
    <div class="entcmnt">
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
    </div>
    <div class="entdefsec">
      <span class="entdefsectitle">
        <xsl:text>Definition </xsl:text>
      </span>
      <div class="entdefsecbody">
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
      </div>
    </div>
  </div>
</xsl:template>



<!-- Named template to insert CSS stylesheet into documents -->
<xsl:template name="style">
  <style type="text/css">
    body  {
    margin-left: 3%;
    margin-right: 3%;
    margin-top: 1%;
    margin-bottom: 5%;
    font-family: Verdana, Helvetica, sans-serif;
    font-size: 11pt;
    color: black;
    background-color: white;
    }
    h1 {
    text-align: center;
    }
    .spacing {
    margin-bottom: 5em;
    }
    .dtdheadcmnt {
    padding-bottom: 2em;
    margin-left: 6%;
    margin-right: 6%;
    }
    .eltdef {
    padding-top: 2em;
    padding-bottom: 2em;
    clear: both;
    }
    .eltdeftitle {
    text-align: left;
    font-size: 140%;
    font-style : normal;
    font-weight : bold;
    color: #a80000;
    }
    .eltcmnt {
    margin-left: 6%;
    margin-right: 6%;
    margin-top: 0.5em;
    margin-bottom: 0.5em;
    text-align: justify;
    }
    .eltdefsec {
    clear: both;
    margin-top: 1.5em;
    margin-bottom: 1.5em;
    font-size: 90%;
    }
    .eltdefsectitle {
    font-weight: bold;
    float: left;
    }
    .eltdefsecbody {
    float: right;
    text-align: left;
    width: 80%;
    margin-left: 1em;
    margin-right: 1em;
    }
    .entdef {
    padding-top: 2em;
    padding-bottom: 2em;
    clear: both;
    }
    .entdeftitle {
    text-align: left;
    font-size: 140%;
    font-style : normal;
    font-weight : bold;
    color: #a80000;
    }
    .entcmnt {
    margin-left: 6%;
    margin-right: 6%;
    margin-top: 0.5em;
    margin-bottom: 0.5em;
    text-align: justify;
    }
    .entdefsec {
    clear: both;
    margin-top: 0.8em;
    margin-bottom: 0.8em;
    font-size: 90%;
    }
    .entdefsectitle {
    font-weight: bold;
    float: left;
    }
    .entdefsecbody {
    float: right;
    text-align: left;
    width: 80%;
    margin-left: 1em;
    margin-right: 1em;
    }
    .attrow {
    width: 10em;
    }
  </style>
</xsl:template>


</xsl:stylesheet>
