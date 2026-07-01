*&---------------------------------------------------------------------*
*& Report ZGE_MAT_RACK
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zge_mat_rack NO STANDARD PAGE HEADING.

TABLES: godynpro.

CONSTANTS screen_title(50) TYPE c VALUE 'Material Rack Label'.

TYPES: BEGIN OF ty_label_data,
         matnr   TYPE matnr,
         maktx   TYPE maktx,
         gr_date TYPE datum,
         ekinops TYPE string,
         charg   TYPE charg_d,
         menge   TYPE menge_d,
       END OF ty_label_data.

  SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
    PARAMETERS: r_stck   RADIOBUTTON GROUP grp1 USER-COMMAND rb_switch DEFAULT 'X',
                r_matdoc RADIOBUTTON GROUP grp1.
  SELECTION-SCREEN END OF BLOCK b1.

  SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
    PARAMETERS: p_matnr  TYPE matnr MODIF ID md1,
                p_batch  TYPE charg_d MODIF ID md1,
                p_grdate TYPE budat MODIF ID md1,
                p_qty    TYPE menge_d MODIF ID md1.
  SELECTION-SCREEN END OF BLOCK b2.

  SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
    PARAMETERS: p_matdoc TYPE mblnr MODIF ID md2.
    SELECT-OPTIONS: s_item FOR godynpro-detail_zeile MODIF ID md2.
    PARAMETERS: p_docyr TYPE mjahr MODIF ID md2.
  SELECTION-SCREEN END OF BLOCK b3.

  SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME.
    PARAMETERS: p_device TYPE rspopname,
                p_copy   TYPE i DEFAULT 1.
  SELECTION-SCREEN END OF BLOCK b4.


INITIALIZATION.
  SET TITLEBAR 'ABC' WITH screen_title.

AT SELECTION-SCREEN OUTPUT.

  IF r_stck = 'X'.
    LOOP AT SCREEN.
      IF screen-group1 = 'MD2'.
        screen-active = '0'.
        screen-input = '0'.
      ENDIF.
      MODIFY SCREEN.
    ENDLOOP.
  ENDIF.

  IF r_matdoc = 'X'.
    LOOP AT SCREEN.
      IF screen-group1 = 'MD1'.
        screen-active = '0'.
        screen-input = '0'.
      ENDIF.
      MODIFY SCREEN.
    ENDLOOP.
  ENDIF.

  CLEAR sy-ucomm.

*AT SELECTION-SCREEN.
*  IF r_stck = 'X'.
*    IF p_matnr IS INITIAL.
*      MESSAGE 'Material number is required' TYPE 'E'.
*    ENDIF.
*    IF p_qty IS INITIAL OR p_qty <= 0.
*      MESSAGE 'Quantity must be greater than zero' TYPE 'E'.
*    ENDIF.
*  ENDIF.
*  IF r_matdoc = 'X'.
*    IF p_matdoc IS INITIAL.
*      MESSAGE 'Material document number is required' TYPE 'E'.
*    ENDIF.
*    IF p_docyr IS INITIAL.
*      MESSAGE 'Fiscal year is required' TYPE 'E'.
*    ENDIF.
*    IF s_item[] IS INITIAL.
*      MESSAGE 'At least one document item must be specified' TYPE 'E'.
*    ENDIF.
*  ENDIF.

START-OF-SELECTION.

  DATA: ls_data  TYPE ty_label_data,
        lv_error TYPE abap_bool.

  CASE abap_true.
    WHEN r_stck.
      PERFORM build_label_from_stock
        USING p_matnr p_batch p_qty p_grdate
        CHANGING ls_data lv_error.
    WHEN r_matdoc.
      DATA ls_item LIKE LINE OF s_item.
      LOOP AT s_item INTO ls_item WHERE sign = 'I' AND option = 'EQ'.
        CLEAR ls_data.
        lv_error = abap_false.
        PERFORM build_label_from_erp_migo
          USING p_matdoc p_docyr ls_item-low
          CHANGING ls_data lv_error.
        CHECK lv_error = abap_false.
        PERFORM call_rack_label_form
          USING ls_data p_device p_copy.
      ENDLOOP.
      RETURN.
  ENDCASE.

  CHECK lv_error = abap_false.
  PERFORM call_rack_label_form
    USING ls_data p_device p_copy.

END-OF-SELECTION.
*&---------------------------------------------------------------------*
*& Form build_label_from_stock
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> P_MATNR
*&      --> P_BATCH
*&      --> P_QTY
*&      --> P_GRDATE
*&      <-- LS_DATA
*&      <-- LV_ERROR
*&---------------------------------------------------------------------*
FORM build_label_from_stock  USING    iv_matnr TYPE matnr
                                      iv_charg TYPE charg_d
                                      iv_menge TYPE menge_d
                                      iv_grdate TYPE budat
                             CHANGING es_data TYPE ty_label_data
                                      ev_error TYPE abap_bool.
  SELECT SINGLE xchpf FROM marc INTO @DATA(lv_xchpf)
   WHERE matnr = @iv_matnr
     AND werks = '1710'.

  IF lv_xchpf = 'X' AND iv_charg IS INITIAL.
    ev_error = abap_true.
    MESSAGE 'Batch number is mandatory for batch-managed material' TYPE 'E'.
    RETURN.
  ENDIF.

  " GR date: use screen value if provided, else derive from batch
  DATA lv_gr_date TYPE datum.
  IF iv_grdate IS NOT INITIAL.
    lv_gr_date = iv_grdate.
  ELSEIF iv_charg IS NOT INITIAL.
    SELECT SINGLE ersda FROM mch1 INTO @lv_gr_date
      WHERE matnr = @iv_matnr AND charg = @iv_charg.
    IF sy-subrc <> 0.
      SELECT SINGLE ersda FROM mcha INTO @lv_gr_date
        WHERE matnr = @iv_matnr AND charg = @iv_charg.
    ENDIF.
  ENDIF.

  SELECT SINGLE maktx FROM makt INTO @DATA(lv_maktx)
    WHERE matnr = @iv_matnr AND spras = @sy-langu.

  es_data-matnr   = iv_matnr.
  es_data-maktx   = lv_maktx.
  es_data-gr_date = lv_gr_date.
  es_data-charg   = iv_charg.
  es_data-menge   = iv_menge.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form build_label_from_erp_migo
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> P_MATDOC
*&      --> P_DOCYR
*&      --> LS_ITEM_LOW
*&      <-- LS_DATA
*&      <-- LV_ERROR
*&---------------------------------------------------------------------*
FORM build_label_from_erp_migo  USING    iv_mblnr TYPE mblnr
                                         iv_mjahr TYPE mjahr
                                         iv_zeile TYPE mblpo
                                CHANGING es_data TYPE ty_label_data
                                         ev_error TYPE abap_bool.

  SELECT SINGLE bwart, matnr, charg, menge, budat_mkpf
    FROM mseg
    INTO @DATA(ls_mseg)
    WHERE mblnr = @iv_mblnr
      AND mjahr = @iv_mjahr
      AND zeile = @iv_zeile.

  IF sy-subrc <> 0.
    ev_error = abap_true.
    MESSAGE |Document { iv_mblnr } item { iv_zeile } not found| TYPE 'E'.
    RETURN.
  ENDIF.

  IF ls_mseg-bwart <> '101'.
    ev_error = abap_true.
    MESSAGE |Item { iv_zeile }: movement type { ls_mseg-bwart } is not a GR (101)| TYPE 'E'.
    RETURN.
  ENDIF.

  SELECT SINGLE maktx FROM makt INTO @DATA(lv_maktx)
    WHERE matnr = @ls_mseg-matnr AND spras = @sy-langu.

  es_data-matnr   = ls_mseg-matnr.
  es_data-maktx   = lv_maktx.
  es_data-gr_date = ls_mseg-budat_mkpf.
  es_data-charg   = ls_mseg-charg.
  es_data-menge   = ls_mseg-menge.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form call_rack_label_form
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_DATA
*&      --> P_DEVICE
*&      --> P_COPY
*&---------------------------------------------------------------------*
FORM call_rack_label_form  USING    is_data TYPE ty_label_data
                                    iv_device TYPE rspopname
                                    iv_copies TYPE i.

  DATA: ls_docparams       TYPE sfpdocparams,
        ls_outputpar       TYPE sfpoutputparams,
        /1bcdwb/formoutput TYPE fpformoutput,
        e_funcname         TYPE funcname,
        lv_ekinops         TYPE string,
        lv_date_fmt        TYPE string.

  PERFORM compute_ekinops_id
    USING    is_data-matnr is_data-menge is_data-charg
    CHANGING lv_ekinops.

  PERFORM format_gr_date
    USING    is_data-gr_date
    CHANGING lv_date_fmt.

  ls_outputpar-reqnew   = abap_true.
  ls_outputpar-dest     = iv_device.
  ls_outputpar-copies   = iv_copies.
  ls_outputpar-nodialog = abap_false.
  ls_docparams-langu    = sy-langu.

  CALL FUNCTION 'FP_JOB_OPEN'
    CHANGING
      ie_outputparams = ls_outputpar
    EXCEPTIONS
      cancel          = 1
      usage_error     = 2
      system_error    = 3
      internal_error  = 4
      OTHERS          = 5.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

  CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
    EXPORTING
      i_name     = 'ZGE_MAT_LABEL_AF'
    IMPORTING
      e_funcname = e_funcname
*     E_INTERFACE_TYPE           =
*     EV_FUNCNAME_INBOUND        =
    .
  CALL FUNCTION e_funcname        " /1BCDWB/SM00000115
    EXPORTING
      /1bcdwb/docparams  = ls_docparams
      iv_matnr           = is_data-matnr
      iv_maktx           = is_data-maktx
      iv_gr_date         = lv_date_fmt
      iv_ekinops_id      = lv_ekinops
      iv_charg           = is_data-charg
      iv_quantity        = is_data-menge
    IMPORTING
      /1bcdwb/formoutput = /1bcdwb/formoutput
    EXCEPTIONS
      usage_error        = 1
      system_error       = 2
      internal_error     = 3
      OTHERS             = 4.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.


  CALL FUNCTION 'FP_JOB_CLOSE'
*    IMPORTING
*      e_result       =
    EXCEPTIONS
      usage_error    = 1
      system_error   = 2
      internal_error = 3
      OTHERS         = 4.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form compute_ekinops_id
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IS_DATA_MATNR
*&      --> IS_DATA_MENGE
*&      --> IS_DATA_CHARG
*&      <-- LV_EKINOPS
*&---------------------------------------------------------------------*
FORM compute_ekinops_id  USING    iv_matnr TYPE matnr
                                  iv_qty TYPE menge_d
                                  iv_charg TYPE charg_d
                         CHANGING cv_eid TYPE string.

  cv_eid = |P{ iv_matnr }Q{ iv_qty }S{ iv_charg }|.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form format_gr_date
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IS_DATA_GR_DATE
*&      <-- LV_DATE_FMT
*&---------------------------------------------------------------------*
FORM format_gr_date  USING    iv_datum TYPE datum
                     CHANGING cv_date TYPE string.

  DATA: lv_day       TYPE string,
        lv_year      TYPE string,
        lv_month     TYPE i,
        lv_month_str TYPE string,
        lt_months    TYPE TABLE OF string.

  APPEND: 'Jan' TO lt_months, 'Feb' TO lt_months, 'Mar' TO lt_months,
          'Apr' TO lt_months, 'May' TO lt_months, 'Jun' TO lt_months,
          'Jul' TO lt_months, 'Aug' TO lt_months, 'Sep' TO lt_months,
          'Oct' TO lt_months, 'Nov' TO lt_months, 'Dec' TO lt_months.

  lv_month = iv_datum+4(2).
  lv_day   = iv_datum+6(2).
  lv_year  = iv_datum(4).
  SHIFT lv_day LEFT DELETING LEADING '0'.
  READ TABLE lt_months INTO lv_month_str INDEX lv_month.
  cv_date = |{ lv_month_str } { lv_day }, { lv_year }|.

ENDFORM.
