class ZCL_ITS_GEN_SAPUI5_MOBILE definition
  public
  inheriting from CL_ITS_GENERATE_HTML_MOBILE4
  final
  create public .

public section.

  methods CONSTRUCTOR .

  methods IF_ITS_GENERATE_TEMPLATE~DESCRIPTION_TEXT
    redefinition .
protected section.
private section.
ENDCLASS.



CLASS ZCL_ITS_GEN_SAPUI5_MOBILE IMPLEMENTATION.


  METHOD constructor.
    DATA:
        l_theme TYPE _t_theme_for_templates.

    super->constructor( ).

    _html_width_factor_containers = '1.00'.
    _html_width_factor_elements = '0.82'.

    _loop_line_name = 'LOOP_INDEX'.

    l_theme-service = 'ZITSGENSAPUI5'.
    l_theme-theme = '99'.
    INSERT l_theme INTO _themes_for_templates INDEX 1.
  ENDMETHOD.


  METHOD if_its_generate_template~description_text.
*CALL METHOD SUPER->IF_ITS_GENERATE_TEMPLATE~DESCRIPTION_TEXT
*  EXPORTING
*    PI_STYLE       =
*  RECEIVING
*    PE_DESCRIPTION =
*    .
    CASE pi_style.
      WHEN 'MOBILE4'.
        pe_description = 'Mobile Geräte (ohne HTML-Tabellen)'(001).
      WHEN 'MOBILE4_IE'.
        pe_description = 'Mobile Geräte (4), ältere Internet Expl.'(003).
      WHEN 'ZMOBSAPUI5'.
        pe_description = 'For Mobile Responsive Design Style (SAPUI5)'(004).
      WHEN OTHERS.
        pe_description = 'Unbekannter Stil'(002).
    ENDCASE.

  ENDMETHOD.
ENDCLASS.
