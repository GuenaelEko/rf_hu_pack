*&---------------------------------------------------------------------*
*& Report ZST74_TEST_SELECT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zst74_test_select.

PARAMETERS: gv_venum TYPE venum,
            lv_matnr TYPE matnr.

DATA: gv_vemng TYPE vemng,
      gv_uom   TYPE vemeh.


START-OF-SELECTION.

*  SELECT SINGLE vpobj
*      FROM vekp
*      INTO @DATA(lv_vpobj)
*      WHERE exidv = @gv_exidv.

*  SELECT SINGLE *
*      FROM vepo
*      INTO @DATA(ls_vepo)
*      WHERE venum = @gv_venum
*        AND matnr = @lv_matnr.

  SELECT SINGLE vemng, vemeh
    FROM vepo
    INTO (@gv_vemng,@gv_uom)
    WHERE venum = @gv_venum
      AND matnr = @lv_matnr.

  IF sy-subrc <> 0.
    MESSAGE 'Data retrieval error' TYPE 'E'.
  ELSE.
    MESSAGE 'Data retrieval success' TYPE 'I'.
  ENDIF.
