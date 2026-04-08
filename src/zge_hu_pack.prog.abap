*&---------------------------------------------------------------------*
*& Report ZGE_HU_PACK
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zge_hu_pack.

TABLES: rlmob, lips.

DATA: ok_code TYPE sy-ucomm,
      save_ok TYPE sy-ucomm.

DATA: lv_delivery TYPE likp-vbeln,
      lv_dlvtype  TYPE likp-lfart,
      pack_status TYPE c,
      packed      TYPE c.
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS-100'.
  SET TITLEBAR 'TITLE-100'.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.
  CASE save_ok.
    WHEN 'BACK'.
      LEAVE PROGRAM.
    WHEN 'NEXT'.
      lv_delivery = |{ rlmob-cvbeln ALPHA = IN }|.

      SELECT SINGLE lfart
        FROM likp
        INTO lv_dlvtype
        WHERE vbeln = lv_delivery.

      IF lv_delivery IS NOT INITIAL AND lv_dlvtype = 'LF'.
        SELECT SINGLE vgbel
          INTO lips-vgbel
          FROM lips
          WHERE vbeln = lv_delivery.

        SELECT COUNT(*)
          INTO rlmob-hucnt
          FROM vepo
          WHERE vbeln = lv_delivery.

        SELECT SINGLE pkstk
          INTO pack_status
          FROM likp
          WHERE vbeln = lv_delivery.

        IF pack_status = 'C'.
          packed = 'X'.
        ENDIF.

        CLEAR save_ok.
        CALL SCREEN '0200'.
      ENDIF.
    WHEN 'CLEAR'.
      CLEAR rlmob-cvbeln.

  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0200 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0200 OUTPUT.
  SET PF-STATUS 'STATUS-200'.
  SET TITLEBAR 'TITLE-200'.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0200  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0200 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    when 'BACK'.
      clear packed.
      call screen '0100'.
    when 'LIST_HU'.
      call screen '0600'.
    when 'NEW_HU'.
      call screen '0300'.
    when 'TO_BE_PACKED'.
      call screen '900'.
  ENDCASE.
ENDMODULE.
