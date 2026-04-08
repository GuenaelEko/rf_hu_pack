*&---------------------------------------------------------------------*
*& Report ZGE_HU_PACK
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zge_hu_pack.

TABLES: rlmob, lips, vekp, mara.

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
    WHEN 'BACK'.
      CLEAR packed.
      CALL SCREEN '0100'.
    WHEN 'LIST_HU'.
      CALL SCREEN '0600'.
    WHEN 'NEW_HU'.
      CALL SCREEN '0300'.
    WHEN 'TO_BE_PACKED'.
      CALL SCREEN '900'.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0300  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0300 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'SAVE'.

      DATA: ls_hdr_prop TYPE bapihuhdrproposal,
            ls_hu_hdr   TYPE bapihuheader,
            lv_hukey    TYPE bapihukey-hu_exid,
            ls_messages TYPE TABLE OF bapiret2.

      ls_hdr_prop-pack_mat = 'CARTON'.

      CALL FUNCTION 'BAPI_HU_CREATE'
        EXPORTING
          headerproposal = ls_hdr_prop
        IMPORTING
          huheader       = ls_hu_hdr
          hukey          = lv_hukey
        TABLES
*         ITEMSPROPOSAL  =
*         ITEMSSERIALNO  =
          return         = ls_messages
*         HUITEM         =
*         CWM_ITEMSPROPOSAL       =
*         CWM_HUITEM     =
        .

      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = ' '
*        IMPORTING
*         return = ls_messages.
        .

      IF sy-subrc <> 0.

      ELSE.
        SELECT SINGLE vrkme
          INTO rlmob-chuuom
          FROM lips
          WHERE vbeln = lv_delivery.

        vekp-exidv = lv_hukey.
      ENDIF.

      CALL SCREEN '0400'.
    WHEN 'CLEAR'.
      CLEAR vekp-exidv2.
    WHEN 'BACK'.
      CLEAR vekp-exidv2.
      CALL SCREEN '0200'.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0400  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0400 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'HOME'.
      CALL SCREEN '0200'.
    WHEN 'BACK'.
      CALL SCREEN '0300'.
    WHEN 'CLEAR'.
      CLEAR: rlmob-chumat, rlmob-csernr, mara-mfrpn, rlmob-chuqty, rlmob-chuuom.
    WHEN 'SAVE'.
    WHEN 'PACK'.
  ENDCASE.

ENDMODULE.
