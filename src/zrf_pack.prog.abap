*&---------------------------------------------------------------------*
*& Module Pool      ZRF_PACK
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
PROGRAM zrf_pack.

TABLES: rlmob,
        likp,     " Delivery Header
        lips,     " Delivery Item
        vekp,     " HU Header
        vepo,     " HU Item (Contents)
        mara,     " Material General Data
        marc,     " Material Plant Data
        makt.     " Material Descriptions

*----------------------------------------------------------------------*
* TYPES
*----------------------------------------------------------------------*
TYPES:
  " ----- Delivery Item -----
  BEGIN OF ty_delivery_item,
    vbeln  TYPE lips-vbeln,
    posnr  TYPE lips-posnr,
    matnr  TYPE lips-matnr,
    arktx  TYPE lips-arktx,
    lfimg  TYPE lips-lfimg,
    vrkme  TYPE lips-vrkme,
    lgort  TYPE lips-lgort,
    charg  TYPE lips-charg,
    sernr  TYPE c,           " X = serialized material
    packed TYPE p DECIMALS 3,
    open   TYPE p DECIMALS 3,
  END OF ty_delivery_item,

  " ----- HU Header -----
*  BEGIN OF ty_hu,
*    venum  TYPE vekp-venum,
*    exidv  TYPE vekp-exidv,
*    exidv2 TYPE vekp-exidv2,
*    vhilm  TYPE vekp-vhilm,
*    brgew  TYPE vekp-brgew,
*    gewei  TYPE vekp-gewei,
*    tarag  TYPE vekp-tarag,
*    status TYPE vekp-status,
*  END OF ty_hu,

  " ----- HU Content Item -----
  BEGIN OF ty_hu_item,
    venum TYPE vepo-venum,
    vepos TYPE vepo-posnr,
    posnr TYPE vepo-posnr,
    vemng TYPE vepo-vemng,
    vemeh TYPE vepo-vemeh,
    matnr TYPE vepo-matnr,
    werks TYPE vepo-werks,
    lgort TYPE vepo-lgort,
    anzsn TYPE vepo-anzsn,
  END OF ty_hu_item,

  " ----- Serial Number -----
*  BEGIN OF ty_serial,
*    sernr    TYPE equi-gernr,
*    matnr    TYPE equi-matnr,
*    selected TYPE c,
*  END OF ty_serial,

  " ----- Packing Buffer (unsaved) -----
  BEGIN OF ty_pack_buffer,
    matnr     TYPE lips-matnr,
    mpn       TYPE mara-mfrpn,         " Manufacturer Part Number
    sernr     TYPE equi-sernr,
    vemng     TYPE vepo-vemng,
    vemeh     TYPE vepo-vemeh,
    posnr     TYPE lips-posnr,
    sernr_mat TYPE c,            " X = serialized
  END OF ty_pack_buffer,

*  " ----- Packaging Material -----
*  BEGIN OF ty_pack_mat,
*    matnr    TYPE mara-matnr,
*    maktx    TYPE makt-maktx,
*    selected TYPE c,
*  END OF ty_pack_mat,

  " ----- HUs List Steploop Structure -----
  BEGIN OF ty_hu_list,
    sel_idx TYPE c,
    exidv   TYPE vekp-exidv,
    exidv2  TYPE vekp-exidv2,
  END OF ty_hu_list,

  BEGIN OF ty_material_list,
    item_sel_idx TYPE c,
    matnr        TYPE mara-matnr,
    vemng        TYPE vepo-vemng,
    vepos        TYPE vepo-vepos,
    venum        TYPE vepo-venum,
  END OF ty_material_list,

  " ---- To Be Packed Steploop Structure ----
  BEGIN OF ty_to_be_packed,
    matnr TYPE vepo-matnr,
    open  TYPE vepo-vemng,  " Qty left to be packed for the item
    vrkme TYPE vepo-vemeh,
  END OF ty_to_be_packed,

  " --- HU Item Details Steploop Structure ---
  BEGIN OF ty_serial,
    sn_sel_idx TYPE c,
    sernr      TYPE  equi-gernr,
  END OF ty_serial.

*----------------------------------------------------------------------*
* GLOBAL DATA
*----------------------------------------------------------------------*
DATA:
  " === Delivery ===
  gv_vbeln           TYPE likp-vbeln,
  gv_vstel           TYPE likp-vstel,
  gv_vgbel           TYPE lips-vgbel,       " Sales order
  gt_del_items       TYPE TABLE OF ty_delivery_item,
  gs_del_item        TYPE ty_delivery_item,

  " === HU ===
  gv_venum           TYPE venum,        " Current HU (internal)
  gv_exidv           TYPE vekp-exidv,        " Current HU (external)
  gv_exidv2          TYPE vekp-exidv2,       " EKINOPS ID
  gv_vhilm           TYPE vekp-vhilm,        " Packaging material
  gv_vepos           TYPE vepo-vepos,        " Handling Unit Item Number
*  gv_werks           TYPE vekp-werks,
*  gv_lgort           TYPE vekp-lgort,
*  gt_hu_list         TYPE TABLE OF ty_hu,
*  gs_hu              TYPE ty_hu,
  gt_hu_items        TYPE TABLE OF ty_hu_item,
  gs_hu_item         TYPE ty_hu_item,
  gv_hu_count        TYPE i,                 " Total HUs for delivery
  gv_pack_complete   TYPE c,               " X = all items packed

  " === QR Code / Scan ===
  gv_matnr           TYPE lips-matnr,        " Parsed material
  gv_mpn             TYPE char40,            " Parsed MPN
  gv_sernr           TYPE equi-gernr,       " Parsed serial number
  gv_qty             TYPE vepo-vemng,        " Quantity (manual or auto)
  gv_uom             TYPE lips-vrkme,        " UoM from delivery
  gv_sn_count        TYPE i,                 " SN/QTY counter
  gv_is_serial       TYPE c,                 " X = serialized material

  " === Packing Buffer (unsaved) ===
  gt_pack_buffer     TYPE TABLE OF ty_pack_buffer,
  gs_pack_buf        TYPE ty_pack_buffer,

  " === Serial Numbers ===
*  gt_serials         TYPE TABLE OF ty_serial,
*  gs_serial          TYPE ty_serial,

  " === Packaging Material selection ===
*  gt_pack_mat        TYPE TABLE OF ty_pack_mat,
*  gs_pack_mat        TYPE ty_pack_mat,

  " === Pagination ===
*  gv_list_offset     TYPE i,                 " Current list page offset
*  gc_page_size       TYPE i VALUE 5,         " Rows per page on RF screen

  " === Selected item index ===
  gv_sel_index       TYPE i,                 " Selected list index
  gv_sel_hu_idx      TYPE i,                 " Selected HU index (for 1100)

  " === Screen flow ===
  gv_okcode          TYPE sy-ucomm,
  gv_prev_scrn       TYPE sy-dynnr,
  gv_return_scrn     TYPE sy-dynnr,          " Where to return after msg

  " === Messages ===
*  gv_msg_text        TYPE string,
*  gv_msg_type        TYPE c,                 " S/E/W/I
*  gv_confirm         TYPE c,                 " X = confirmation pending

  " === Open items summary ===
  gt_open_items      TYPE TABLE OF ty_delivery_item,

  " === Steploop variables for HUs list ===
  lt_hu_list         TYPE TABLE OF ty_hu_list WITH HEADER LINE,
  ls_hu_list         TYPE ty_hu_list,
  index              TYPE i,
  lines_steploop     TYPE i,
  lines_lt_hu_list   TYPE i,
  line               TYPE i VALUE 0,
*  save_ok            TYPE sy-ucomm,

  " === Steploop variables for Material list ===
  lt_item_list       TYPE TABLE OF ty_material_list WITH HEADER LINE,
  ls_item_list       TYPE ty_material_list,
  lines_lt_item_list TYPE i,
  line_item          TYPE i,

  " === Steploop variables for To Be Packed ===
  lt_to_pack_list    TYPE TABLE OF ty_to_be_packed WITH HEADER LINE,
  ls_to_pack_list    TYPE ty_to_be_packed,
  lines_to_be_packed TYPE i,                   " Number of lines in LT_TO_PACK_LIST
  line_pack          TYPE i,                   " Line increment for navigating the steploop
  cursor             TYPE i,
  num_of_stepl_lines TYPE i,

  " === Steploop variables for HU Item Details ===
  lt_serials         TYPE TABLE OF ty_serial WITH HEADER LINE,
  ls_serial          TYPE ty_serial,
  sn_count           TYPE i,
  sn_line            TYPE i,
  num_of_lines       TYPE i,

  " === Create HU through BAPI ===
  ls_huhdr_prop      TYPE bapihuhdrproposal,
  ls_hu_created      TYPE bapihuheader,
  lv_hu_exidv        TYPE bapihukey-hu_exid,
  lt_return          TYPE TABLE OF bapiret2,

  " === Variables for FM WS_DELIVERY_UPDATE ===
  lt_verko           TYPE TABLE OF verko,
  ls_verko           TYPE verko,
  lt_verpo           TYPE TABLE OF verpo,
  ls_verpo           TYPE verpo,
  lt_hvbpok          TYPE TABLE OF vbpok,
  ls_hvbpok          TYPE vbpok,
  ls_vbkok           TYPE vbkok,
  lt_prot            TYPE TABLE OF prott,
*  lt_sernr           TYPE TABLE OF hum_verpo_sernr,

  answer             TYPE c,
  cursor_line        TYPE i,
  sel_line           TYPE i,
  lv_relative        TYPE i,
  lv_removed_qty     TYPE vepo-vemng,
  selected_line      TYPE i,
  sn_sel_line        TYPE i,

  gv_init_0800       TYPE c,
  gv_init_qty        TYPE vepo-vemng.

DATA: lv_matnr                 TYPE matnr,
      lv_vemng                 TYPE vemng,
      gv_vemng                 TYPE vemng,
      lt_sernr                 TYPE TABLE OF hum_verpo_sernr,
      ls_sernr                 TYPE hum_verpo_sernr,
      lt_deleted_serials       TYPE TABLE OF ty_serial,
      ls_deleted_serial        TYPE ty_serial,
      lw_ef_error_any          TYPE xfeld VALUE 'X',
      lw_ef_error_sernr_update TYPE xfeld VALUE 'X'.

*----------------------------------------------------------------------*
* CONSTANTS
*----------------------------------------------------------------------*
CONSTANTS:
  gc_vpobj_od  TYPE vekp-vpobj    VALUE '01',   " Outbound Delivery
  gc_verp_type TYPE mara-mtart    VALUE 'VERP', " Packaging mat type
  gc_x         TYPE c             VALUE 'X',
  gc_space     TYPE c             VALUE ' '.

START-OF-SELECTION.
  CALL SCREEN '0100'.

*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'S0100'.
  SET TITLEBAR 'T0100'.
  CLEAR: gv_vbeln.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.
  CASE gv_okcode.
    WHEN 'NEXT'.
      IF gv_vbeln IS INITIAL.
        CALL SCREEN '0100'.
      ELSE.
        PERFORM validate_delivery.
        IF sy-subrc = 0.
          PERFORM init_delivery_data.
          CALL SCREEN '0200'.
        ENDIF.
      ENDIF.
    WHEN 'CLEAR'.
      CLEAR gv_vbeln.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form validate_delivery
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_delivery .
  DATA msg_var TYPE symsgv.

  msg_var = gv_vbeln.

  SELECT SINGLE vbeln, lfart, kunnr, vstel, wadat_ist
  FROM likp
  INTO @DATA(ls_likp)
  WHERE vbeln = @gv_vbeln.

  IF sy-subrc <> 0.
    CALL FUNCTION 'CALL_MESSAGE_SCREEN'
      EXPORTING
        i_msgid         = 'LF'
        i_lang          = sy-langu
        i_msgno         = '267'
        i_msgv1         = msg_var
        i_non_lmob_envt = 'X'.

*    CALL SCREEN '0100'.
  ELSE.
    IF ls_likp-lfart <> 'LF' AND ls_likp-lfart <> 'LO'.
      CALL SCREEN '0100'.
    ENDIF.

    IF ls_likp-wadat_ist IS NOT INITIAL.
      CALL FUNCTION 'CALL_MESSAGE_SCREEN'
        EXPORTING
          i_msgid         = 'LF'
          i_lang          = sy-langu
          i_msgno         = '273'
          i_msgv1         = msg_var
          i_non_lmob_envt = 'X'.

*    CALL SCREEN '0100'.
    ENDIF.
  ENDIF.

  gv_vstel = ls_likp-vstel.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form init_delivery_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM init_delivery_data .
  CLEAR: gt_del_items, gv_vgbel, gt_hu_items.

  " Get sales order
*  SELECT SINGLE vgbel
*    INTO gv_vgbel
*    FROM lips
*    WHERE vbeln = gv_vbeln.

  " Load delivery items
  SELECT vgbel, posnr, matnr, arktx, lfimg, vrkme, lgort, charg, vbeln
   INTO TABLE @DATA(lt_lips)
   FROM lips
   WHERE vbeln = @gv_vbeln.

  IF sy-subrc <> 0.
    MESSAGE 'Error in init_delivery_data' TYPE 'I'.
  ELSE.
    gv_vgbel = lt_lips[ 1 ]-vgbel.

    SELECT matnr, SUM( vemng ) AS packed
    FROM vepo
    INTO TABLE @DATA(lt_packed)
    WHERE vbeln = @gv_vbeln
    GROUP BY matnr.

    LOOP AT lt_lips INTO DATA(ls_lips).
      MOVE-CORRESPONDING ls_lips TO gs_del_item.

      " Packed quantity
      READ TABLE lt_packed INTO DATA(ls_packed) WITH KEY matnr = ls_lips-matnr.
      gs_del_item-packed = COND #( WHEN sy-subrc = 0
                                   THEN ls_packed-packed
                                   ELSE 0 ).
      gs_del_item-open = ls_lips-lfimg - gs_del_item-packed.

      APPEND gs_del_item TO gt_del_items.
      CLEAR gs_del_item.
    ENDLOOP.


    " Load Handling Unit items
    SELECT venum, vepos, posnr, vemng, vemeh, matnr, werks, lgort, anzsn
      INTO TABLE @DATA(lt_vepo)
      FROM vepo
      WHERE vbeln = @gv_vbeln.

    LOOP AT lt_vepo INTO DATA(ls_vepo).
      MOVE-CORRESPONDING ls_vepo TO gs_hu_item.
      APPEND gs_hu_item TO gt_hu_items.
    ENDLOOP.
  ENDIF.

*  LOOP AT lt_lips INTO DATA(ls_lips).
*    gs_del_item-vbeln  = ls_lips-vbeln.
*    gs_del_item-posnr  = ls_lips-posnr.
*    gs_del_item-matnr  = ls_lips-matnr.
*    gs_del_item-arktx  = ls_lips-arktx.
*    gs_del_item-lfimg  = ls_lips-lfimg.
*    gs_del_item-vrkme  = ls_lips-vrkme.
*    gs_del_item-lgort  = ls_lips-lgort.
*    gs_del_item-charg  = ls_lips-charg.
*
*    " Check if material is serialized (has SN profile)
**    SELECT SINGLE sernp
**      INTO @DATA(lv_sernp)
**      FROM marc
**      WHERE matnr = @ls_lips-matnr AND werks = @gv_vstel.
**    gs_del_item-sernr = COND #( WHEN lv_sernp IS NOT INITIAL THEN gc_x
**                                ELSE gc_space ).
*
*    " Packed quantity
*    SELECT SUM( vemng )
*      INTO @gs_del_item-packed
*      FROM vepo
*      WHERE vbeln = @gv_vbeln
*        AND matnr = @ls_lips-matnr.
*
*    gs_del_item-open = ls_lips-lfimg - gs_del_item-packed.
*    APPEND gs_del_item TO gt_del_items.
*    CLEAR gs_del_item.
*  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0200 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0200 OUTPUT.
  SET PF-STATUS 'S0200'.
  SET TITLEBAR 'T0200'.
  PERFORM refresh_hu_summary.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0200  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0200 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.

  CASE gv_okcode.
    WHEN 'NEWHU'.
      PERFORM init_new_hu.
      CALL SCREEN '0300'.
    WHEN 'LISTHU'.
      IF gv_hu_count = 0.
        CALL SCREEN '0200'.
      ELSE.
        CALL SCREEN '0600'.
      ENDIF.
    WHEN 'TOPACK'.
      CALL SCREEN '0900'.
    WHEN 'BACK'.
      CLEAR: gv_vbeln, gt_del_items.
      LEAVE TO SCREEN '0100'.
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Form refresh_hu_summary
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM refresh_hu_summary .

  line = 0.

  SELECT COUNT( * )
    FROM vekp
    WHERE vpobj = @gc_vpobj_od
      AND vpobjkey = @gv_vbeln
    INTO @gv_hu_count.


  SELECT SINGLE pkstk
    FROM likp
    INTO @DATA(packing_status)
    WHERE vbeln = @gv_vbeln.

  IF packing_status = 'C'.
    gv_pack_complete = gc_x.
  ELSE.
    gv_pack_complete = gc_space.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form init_new_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM init_new_hu .
  CLEAR: gv_venum, gv_exidv, gv_exidv2, gt_pack_buffer.
  gv_vhilm  = 'CARTON'.
*  gv_sn_count = 0.
ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0300 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0300 OUTPUT.
  SET PF-STATUS 'S0300'.
  SET TITLEBAR 'T0300'.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0300  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0300 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.
  CASE gv_okcode.
    WHEN 'SAVE'.
      PERFORM create_hu.
      CLEAR gt_pack_buffer.
*      gv_sn_count = 0.
      CALL SCREEN '0400'.
    WHEN 'CLEAR'.
      CLEAR gv_exidv2.
    WHEN 'BACK'.
      CLEAR gv_exidv2.
      LEAVE TO SCREEN '0200'.
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form create_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM create_hu .

  ls_huhdr_prop-pack_mat = gv_vhilm.
  ls_huhdr_prop-ext_id_hu_2 = gv_exidv2.

  CALL FUNCTION 'BAPI_HU_CREATE'
    EXPORTING
      headerproposal = ls_huhdr_prop
    IMPORTING
      huheader       = ls_hu_created
      hukey          = lv_hu_exidv
    TABLES
      return         = lt_return.

  ls_hu_created-pack_mat_object = '01'.
  ls_hu_created-pack_mat_obj_key = gv_vbeln.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.

  gv_venum = ls_hu_created-hu_id.
  gv_exidv = ls_hu_created-hu_exid.

*  READ TABLE gt_del_items INTO DATA(ls_first_item) INDEX 1.
  gv_uom = gt_del_items[ 1 ]-vrkme.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0400 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0400 OUTPUT.
  SET PF-STATUS 'S0400'.
  SET TITLEBAR 'T0400'.

*  PERFORM clear_fields.

  IF ls_hu_list IS NOT INITIAL.
    gv_exidv = ls_hu_list-exidv.
    gv_exidv2 = ls_hu_list-exidv2.
*  READ TABLE gt_del_items INTO DATA(ls_first_item) INDEX 1.
    gv_uom = gt_del_items[ 1 ]-vrkme.
  ENDIF.

  CLEAR ls_hu_list.

  " Contrôle des champs selon sérialisation
  LOOP AT SCREEN.
    IF screen-name = 'GV_SERNR'.
      IF gv_is_serial = gc_x.
        screen-input     = '1'.
        screen-invisible = '0'.
      ELSE.
        screen-input     = '0'.
*        screen-invisible = '1'.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
    IF screen-name = 'GV_QTY'.
      IF gv_is_serial = gc_x.
        screen-input = '0'.    " Quantité bloquée à 1
      ELSE.
        screen-input = '1'.    " Quantité saisissable
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0400  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0400 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.
  CASE gv_okcode.
    WHEN 'PACK'.
      PERFORM validate_pack_entry.
      PERFORM add_to_pack_buffer.
      PERFORM clear_fields.
    WHEN 'SAVE'.
      PERFORM validate_pack_entry.
      PERFORM add_to_pack_buffer.
      PERFORM commit_pack_buffer.
      PERFORM clear_fields.
    WHEN 'CLEAR'.
      PERFORM clear_fields.
    WHEN 'HOME'.
      PERFORM clear_fields.
      PERFORM popup_confirm.
    WHEN 'BACK'.
      PERFORM clear_fields.
      PERFORM popup_confirm.
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form validate_pack_entry
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM validate_pack_entry .

  READ TABLE gt_del_items INTO DATA(ls_it)
    WITH KEY matnr = gv_matnr.

  IF sy-subrc = 0.
    " Sum already in buffer
    DATA lv_buf_total TYPE p DECIMALS 3.
    LOOP AT gt_pack_buffer INTO DATA(ls_b) WHERE matnr = gv_matnr.
      lv_buf_total = lv_buf_total + ls_b-vemng.
    ENDLOOP.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form add_to_pack_buffer
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM add_to_pack_buffer .

  CLEAR gs_pack_buf.

  IF gv_matnr IS NOT INITIAL.
    gs_pack_buf-matnr    = gv_matnr.
    gs_pack_buf-mpn      = gv_mpn.
    gs_pack_buf-sernr    = gv_sernr.
    gs_pack_buf-vemng    = gv_qty.
    gs_pack_buf-vemeh    = gv_uom.
    gs_pack_buf-sernr_mat = gv_is_serial.

    " Link to delivery item
    READ TABLE gt_del_items INTO DATA(ls_it)
      WITH KEY matnr = gv_matnr.
    IF sy-subrc = 0.
      gs_pack_buf-posnr = ls_it-posnr.
    ENDIF.

    APPEND gs_pack_buf TO gt_pack_buffer.
  ENDIF.

*  DESCRIBE TABLE gt_pack_buffer LINES gv_sn_count.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form clear_fields
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM clear_fields .
  CLEAR: gv_matnr, gv_mpn, gv_sernr, gv_qty, gv_is_serial.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form commit_pack_buffer
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM commit_pack_buffer .

*  DATA: lt_sernr_update          TYPE shp_sernr_update_t,
*        ls_sernr_update          TYPE shp_sernr_update_t WITH HEADER LINE,

  CLEAR: lt_sernr. "lt_sernr_update.

  gv_exidv = |{ gv_exidv ALPHA = IN }|.

*  lv_is_vepo-venum = gv_venum.

  SELECT SINGLE vpobj
    FROM vekp
    INTO @DATA(lv_vpobj)
    WHERE exidv = @gv_exidv.

  IF sy-subrc <> 0.
    MESSAGE 'Error in commit_pack_buffer, at select vpobj' TYPE 'I'.
  ELSE.
    IF gt_pack_buffer IS INITIAL.
      RETURN.   " Nothing to commit
    ENDIF.

    ls_vbkok-vbeln_vl = gv_vbeln.
    ls_verko-exidv = |{ gv_exidv ALPHA = IN }|.

    APPEND ls_verko TO lt_verko.

    LOOP AT gt_pack_buffer INTO gs_pack_buf.
      ls_hvbpok-vbeln_vl = gv_vbeln.
      ls_hvbpok-posnr_vl = gs_pack_buf-posnr.
      ls_hvbpok-posnn    = gs_pack_buf-posnr.
      ls_hvbpok-vbeln    = gv_vbeln.
      ls_hvbpok-vbtyp_n  = 'Q'.
      ls_hvbpok-pikmg    = gs_pack_buf-vemng.
      ls_hvbpok-lfimg    = gs_pack_buf-vemng.
      ls_hvbpok-lgmng    = gs_pack_buf-vemng.
      ls_hvbpok-meins    = gs_pack_buf-vemeh.
      ls_hvbpok-ndifm    = 0.
      ls_hvbpok-taqui    = 'X'.
      ls_hvbpok-matnr    = gs_pack_buf-matnr.

      APPEND ls_hvbpok TO lt_hvbpok.
    ENDLOOP.

    LOOP AT gt_pack_buffer INTO DATA(ls_buf).
      CLEAR ls_verpo.

      ls_verpo-exidv_ob = |{ gv_exidv ALPHA = IN }|.
      ls_verpo-exidv = |{ gv_exidv ALPHA = IN }|.
      ls_verpo-velin = '1'.
      ls_verpo-tmeng = ls_buf-vemng.
      ls_verpo-matnr = ls_buf-matnr.

      ls_sernr-exidv_ob = |{ gv_exidv ALPHA = IN }|.
      ls_sernr-belnr = gv_vbeln.
      ls_sernr-posnr = ls_buf-posnr.
      ls_sernr-sernr = ls_buf-sernr.

*      ls_sernr_update-rfbel = gv_vbeln.
*      ls_sernr_update-rfpos = ls_buf-posnr.
*      ls_sernr_update-sernr = ls_buf-sernr.

      APPEND ls_verpo TO lt_verpo.
      APPEND ls_sernr TO lt_sernr.
*      APPEND ls_sernr_update TO lt_sernr_update.
    ENDLOOP.

    IF lv_vpobj = gc_vpobj_od.

      CALL FUNCTION 'WS_DELIVERY_UPDATE'
        EXPORTING
          vbkok_wa                 = ls_vbkok
          synchron                 = 'X'
          commit                   = 'X'
          delivery                 = gv_vbeln
          update_picking           = 'X'
          nicht_sperren            = 'X'
          if_database_update       = '1'
          if_error_messages_send_0 = 'X'
*         it_sernr_update          = lt_sernr_update
        IMPORTING
          ef_error_any_0           = lw_ef_error_any
          ef_error_sernr_update    = lw_ef_error_sernr_update
        TABLES
          vbpok_tab                = lt_hvbpok
          prot                     = lt_prot
          verko_tab                = lt_verko
          verpo_tab                = lt_verpo
          it_verpo_sernr           = lt_sernr.
    ELSE.

      CALL FUNCTION 'BAPI_HU_CHANGE_HEADER'
        EXPORTING
          hukey     = lv_hu_exidv
          huchanged = ls_hu_created
        IMPORTING
          huheader  = ls_hu_created
        TABLES
          return    = lt_return.

      COMMIT WORK AND WAIT.

      CALL FUNCTION 'WS_DELIVERY_UPDATE'
        EXPORTING
          vbkok_wa                 = ls_vbkok
          synchron                 = 'X'
          commit                   = 'X'
          delivery                 = gv_vbeln
          update_picking           = 'X'
          nicht_sperren            = 'X'
          if_database_update       = '1'
          if_error_messages_send_0 = 'X'
*         it_sernr_update          = lt_sernr_update
        IMPORTING
          ef_error_any_0           = lw_ef_error_any
          ef_error_sernr_update    = lw_ef_error_sernr_update
        TABLES
          vbpok_tab                = lt_hvbpok
          prot                     = lt_prot
          verko_tab                = lt_verko
          verpo_tab                = lt_verpo
          it_verpo_sernr           = lt_sernr.
    ENDIF.

    IF sy-subrc <> 0.
      PERFORM clear_fields.
      READ TABLE lt_prot INTO DATA(ls_prot) WITH KEY msgty = 'E'.
    ENDIF.

  ENDIF.

  CLEAR: gt_pack_buffer.


*  " Serial numbers: post via SER01 assignment if serialized
*  LOOP AT gt_pack_buffer INTO DATA(ls_sb) WHERE sernr_mat = gc_x.
*    IF ls_sb-sernr IS NOT INITIAL.
*      PERFORM post_serial_number USING ls_sb-matnr ls_sb-sernr.
*    ENDIF.
*  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0600 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0600 OUTPUT.
  SET PF-STATUS 'S0600'.
  SET TITLEBAR 'T0600'.

  SELECT exidv, exidv2
    FROM vekp
    INTO CORRESPONDING FIELDS OF TABLE @lt_hu_list
    WHERE vpobj = @gc_vpobj_od
      AND vpobjkey = @gv_vbeln.

  lines_lt_hu_list = lines( lt_hu_list ).

  IF sel_line < line + 1 OR sel_line > line + lines_steploop.
    sel_line = line + 1.
  ENDIF.

  lv_relative = sel_line - line.
  SET CURSOR FIELD 'LS_HU_LIST-SEL_IDX' LINE lv_relative.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0600  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0600 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.
  CASE gv_okcode.
    WHEN 'HUDTL'.
      LOOP AT lt_hu_list INTO ls_hu_list.
        IF ls_hu_list-sel_idx = gc_x.
          CLEAR: selected_line, line_item.
          selected_line = 1.
          CALL SCREEN '0700'.
        ENDIF.
      ENDLOOP.
    WHEN 'DELHU'.
      LOOP AT lt_hu_list INTO ls_hu_list.
        IF ls_hu_list-sel_idx = gc_x.
          PERFORM confirm_delete_hu.
        ENDIF.
      ENDLOOP.
    WHEN 'USEHU'.
      LOOP AT lt_hu_list INTO ls_hu_list.
        IF ls_hu_list-sel_idx = gc_x.
          CALL SCREEN '0400'.
        ENDIF.
      ENDLOOP.
    WHEN 'BACK'.
      LEAVE TO SCREEN '0200'.
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
    WHEN 'PREV'.
      line = line - lines_steploop.
      IF line < 0.
        line = 0.
      ENDIF.
    WHEN 'NEXT'.
      line = line + lines_steploop.
      IF line > lines_lt_hu_list - lines_steploop.
        line = lines_lt_hu_list - lines_steploop.
      ENDIF.
    WHEN 'UP'.
      IF sel_line > 1.
        sel_line = sel_line - 1.
      ENDIF.
    WHEN 'DOWN'.
      IF sel_line < line + lines_steploop AND sel_line < lines_lt_hu_list.
        sel_line = sel_line + 1.
      ENDIF.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module DISPLAY OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE display OUTPUT.

  DATA(lv_index) = sy-stepl + line.

  SORT lt_hu_list BY exidv ASCENDING.
  READ TABLE lt_hu_list INTO ls_hu_list INDEX lv_index.

*  IF sy-stepl = 1.
*    ls_hu_list-sel_idx = gc_x.
*  ENDIF.

  IF lv_index = sel_line.
    ls_hu_list-sel_idx = gc_x.
  ELSE.
    CLEAR ls_hu_list-sel_idx.
  ENDIF.

  ls_hu_list-exidv = |{ ls_hu_list-exidv ALPHA = OUT }|.

*  IF lv_index = gv_selected_line.
*    gv_sel_idx = 'X'.
*  ELSE.
*    CLEAR gv_sel_idx.
*  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form popup_confirm
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM popup_confirm .

  CALL FUNCTION 'CALL_MESSAGE_SCREEN'
    EXPORTING
      i_msgid          = 'LTR2_UI'
      i_lang           = sy-langu
      i_msgno          = '000'
      i_message_screen = '0998'
      i_non_lmob_envt  = gc_x
    IMPORTING
      o_answer         = answer.

  IF sy-subrc <> 0.
* Implement suitable error handling here
  ELSE.
    IF answer = gc_space.
      IF gv_okcode = 'BACK'.
        LEAVE TO SCREEN '0300'.
      ELSEIF gv_okcode = 'HOME'.
        LEAVE TO SCREEN '0200'.
      ENDIF.
    ELSE.
      IF gt_pack_buffer IS NOT INITIAL.
        PERFORM commit_pack_buffer.
      ENDIF.
      IF gv_okcode = 'BACK'.
        LEAVE TO SCREEN '0300'.
      ELSEIF gv_okcode = 'HOME'.
        LEAVE TO SCREEN '0200'.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Module  MODIFY_LT_HU_LIST  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE modify_lt_hu_list INPUT.
  DATA: lv_exidv  TYPE vekp-exidv,
        lv_exidv2 TYPE vekp-exidv2.

  lines_steploop = sy-loopc.
  lv_index = sy-stepl + line.

  MODIFY lt_hu_list FROM ls_hu_list INDEX lv_index.
  READ TABLE lt_hu_list INTO ls_hu_list WITH KEY sel_idx = gc_x.

  lv_exidv = ls_hu_list-exidv.
  lv_exidv2 = ls_hu_list-exidv2.

*  IF sy-subrc <> 0.
*    MESSAGE 'Error in modify_lt_hu_list, at read lt_hu_list' TYPE 'I'.
*  ELSE.
*    lv_exidv = ls_hu_list-exidv.
*    lv_exidv2 = ls_hu_list-exidv2.
*  ENDIF.

  CLEAR ls_hu_list.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Form confirm_delete_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM confirm_delete_hu .

  DATA: lv_msgv1 TYPE symsgv.
  lv_msgv1 = lv_exidv.

  CLEAR answer.

  CALL FUNCTION 'CALL_MESSAGE_SCREEN'
    EXPORTING
      i_msgid          = 'CNV_PE_UI'
      i_lang           = sy-langu
      i_msgno          = '016'
      i_msgv1          = lv_msgv1
      i_message_screen = '0998'
      i_non_lmob_envt  = gc_x
    IMPORTING
      o_answer         = answer.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ELSE.
    IF answer = gc_x.
      PERFORM delete_hu.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form delete_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM delete_hu .
  DATA: lv_hu_to_delete TYPE bapihukey-hu_exid.
  lv_hu_to_delete = |{ lv_exidv ALPHA = IN }|.

  CALL FUNCTION 'BAPI_HU_DELETE_FROM_DEL'
    EXPORTING
      delivery = gv_vbeln
      hukey    = lv_hu_to_delete
    TABLES
      return   = lt_return.

  IF sy-subrc <> 0.

  ELSE.
    COMMIT WORK AND WAIT.
    DELETE FROM vekp WHERE exidv = lv_hu_to_delete.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0700 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0700 OUTPUT.
  SET PF-STATUS 'S0700'.
  SET TITLEBAR 'T0700'.

  gv_exidv = |{ lv_exidv ALPHA = OUT }|.
  gv_exidv2 = lv_exidv2.

  lv_exidv = |{ lv_exidv ALPHA = IN }|.

  SELECT SINGLE venum
    FROM vekp
    WHERE exidv = @lv_exidv
    INTO @gv_venum.

  SELECT matnr, vemng, vepos
    FROM vepo
    INTO CORRESPONDING FIELDS OF TABLE @lt_item_list
    WHERE venum = @gv_venum.

  IF selected_line < line_item + 1 OR selected_line > line_item + lines_steploop.
    selected_line = line_item + 1.
  ENDIF.

  DATA(lv_relative2) = selected_line - line_item.
  SET CURSOR FIELD 'LS_ITEM_LIST-ITEM_SEL_IDX' LINE lv_relative2.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0700  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0700 INPUT.
  lines_lt_item_list = lines( lt_item_list ).
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.

  CASE gv_okcode.
    WHEN 'ITMDTL'.
      LOOP AT lt_item_list INTO ls_item_list.
        IF ls_item_list-item_sel_idx = gc_x.
          CLEAR: sn_line, sn_sel_line, lt_serials.
          gv_init_0800 = gc_x.
          CALL SCREEN '0800'.
        ENDIF.
      ENDLOOP.
    WHEN 'UNPACK'.
      LOOP AT lt_item_list INTO ls_item_list.
        IF ls_item_list-item_sel_idx = gc_x.
          PERFORM confirm_unpack_hu.
        ENDIF.
      ENDLOOP.
    WHEN 'ADD'.
      CALL SCREEN '0400'.
    WHEN 'HOME'.
      PERFORM popup_confirm.
    WHEN 'BACK'.
      LEAVE TO SCREEN '0600'.
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
    WHEN 'PREV'.
      line_item = line_item - 1.
      IF line_item < 0.
        line_item = 0.
      ENDIF.
    WHEN 'NEXT'.
      line_item = line_item + 1.
      IF line_item > lines_lt_item_list - lines_steploop.
        line_item = lines_lt_item_list - lines_steploop.
      ENDIF.
    WHEN 'UP'.
      IF selected_line > 1.
        selected_line = selected_line - 1.
      ENDIF.
    WHEN 'DOWN'.
      IF selected_line < line_item + lines_steploop AND selected_line < lines_lt_item_list.
        selected_line = selected_line + 1.
      ENDIF.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module FILL_HU_ITEM OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE fill_hu_item OUTPUT.
  DATA(lv_idx) = sy-stepl + line_item.

  READ TABLE lt_item_list INTO ls_item_list INDEX lv_idx.
  ls_item_list-matnr = |{ ls_item_list-matnr ALPHA = OUT }|.

  IF lv_idx = selected_line.
    ls_item_list-item_sel_idx = gc_x.
  ELSE.
    CLEAR ls_item_list-item_sel_idx.
  ENDIF.

*  TRY.
*      ls_item_list-matnr = |{ lt_item_list[ lv_idx ]-matnr }|.
*      ls_item_list-vemng = |{ lt_item_list[ lv_idx ]-vemng }|.
*    CATCH cx_sy_itab_line_not_found.
*  ENDTRY.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  MODIFY_ITEM_LIST  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE modify_item_list INPUT.
*  DATA: lv_matnr TYPE matnr,
*        lv_vemng TYPE vepo-vemng.

  lines_steploop = sy-loopc.
  lv_idx = sy-stepl + line_item.

  MODIFY lt_item_list FROM ls_item_list INDEX lv_idx.
  READ TABLE lt_item_list INTO ls_item_list WITH KEY item_sel_idx = gc_x.

  gv_vepos = ls_item_list-vepos.
  lv_matnr = |{ ls_item_list-matnr  ALPHA = IN }|.
  lv_vemng = ls_item_list-vemng.

*  SELECT SINGLE i~matnr, i~vemng
*    FROM @lt_item_list AS i
*    WHERE item_sel_idx = 'X'
*    INTO (@lv_matnr, @lv_vemng).
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form confirm_unpack_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM confirm_unpack_hu .
  DATA: lv_msg_matnr TYPE symsgv.
  lv_msg_matnr = lv_matnr.
  CLEAR answer.
  CALL FUNCTION 'CALL_MESSAGE_SCREEN'
    EXPORTING
      i_msgid          = 'ZRF_MSG'
      i_lang           = sy-langu
      i_msgno          = '000'
      i_msgv1          = lv_msg_matnr
      i_message_screen = '0998'
      i_non_lmob_envt  = gc_x
    IMPORTING
      o_answer         = answer.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ELSE.
    IF answer = gc_x.
      PERFORM unpack_hu.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form unpack_hu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM unpack_hu .
  CLEAR: lt_verko, lt_verpo.

  ls_verko-exidv = |{ gv_exidv ALPHA = IN }|.
  APPEND ls_verko TO lt_verko.

  ls_verpo-exidv_ob = |{ gv_exidv ALPHA = IN }|.
  ls_verpo-exidv = |{ gv_exidv ALPHA = IN }|.
  ls_verpo-velin = '1'.
  ls_verpo-tmeng = -1 * ls_item_list-vemng.
  ls_verpo-matnr = ls_item_list-matnr.
  APPEND ls_verpo TO lt_verpo.

  CALL FUNCTION 'WS_DELIVERY_UPDATE'
    EXPORTING
      vbkok_wa                 = ls_vbkok
      synchron                 = 'X'
      commit                   = 'X'
      delivery                 = gv_vbeln
      update_picking           = 'X'
      nicht_sperren            = 'X'
      if_database_update       = '1'
      if_error_messages_send_0 = 'X'
    TABLES
      prot                     = lt_prot
      verko_tab                = lt_verko
      verpo_tab                = lt_verpo.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0800 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0800 OUTPUT.
  SET PF-STATUS 'S0800'.
  SET TITLEBAR 'T0800'.

  IF gv_init_0800 = gc_x.

    CLEAR: gv_vemng, gv_uom, gv_qty, gv_matnr, gv_init_0800, lt_deleted_serials.

*  SELECT SINGLE vemng, vemeh
*    FROM vepo
*    INTO (@gv_vemng,@gv_uom)
*    WHERE venum = @gv_venum
*      AND matnr = @lv_matnr.


    SELECT SINGLE *
      FROM vepo
      INTO @DATA(ls_vepo) BYPASSING BUFFER
      WHERE venum = @gv_venum
        AND vepos = @gv_vepos.

    IF sy-subrc <> 0.
      MESSAGE 'Error in status_0800, select qty and unit' TYPE 'I'.
    ELSE.
      gv_matnr = |{ ls_vepo-matnr ALPHA = OUT }| .
      gv_qty = ls_vepo-vemng.
      gv_uom = ls_vepo-vemeh.
      gv_init_qty = ls_vepo-vemng.
    ENDIF.

    SELECT objk~sernr
      FROM ser06
      INNER JOIN objk ON ser06~obknr = objk~obknr
      WHERE ser06~venum = @gv_venum
      INTO CORRESPONDING FIELDS OF TABLE @lt_serials.

    IF sy-subrc <> 0.
      MESSAGE 'Error in status_0800, select serial number' TYPE 'I'.
    ENDIF.

    SELECT SINGLE sernp
      FROM marc
      INTO @DATA(lv_sernp)
      WHERE matnr = @ls_vepo-matnr
        AND werks = @gv_vstel.

    IF sy-subrc = 0 AND lv_sernp IS NOT INITIAL.
      gv_is_serial = gc_x.
    ELSE.
      CLEAR gv_is_serial.
    ENDIF.
  ENDIF.

  " Contrôle du champ quantité
  LOOP AT SCREEN.

    IF screen-name = 'GV_QTY'.
      IF gv_is_serial = gc_x.
        screen-input = '0'.    " Display only si sérialisé
      ELSE.
        screen-input = '1'.    " Modifiable si non sérialisé
      ENDIF.
      MODIFY SCREEN.
    ENDIF.

    IF screen-name = 'SN_LIST' OR screen-name = 'RLMOB-PPGUP' OR screen-name = 'RLMOB-PPGDN' OR screen-name = 'REMOVE_SN'.
      IF gv_is_serial = gc_x.
        screen-active = '1'.
      ELSE.
        screen-active = '0'.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.

  ENDLOOP.

  IF sn_sel_line < sn_line + 1 OR sn_sel_line > sn_line + num_of_lines.
    sn_sel_line = sn_line + 1.
  ENDIF.

  DATA(lv_sn_relative) = sn_sel_line - sn_line.
  SET CURSOR FIELD 'LS_SERIAL-SN_SEL_IDX' LINE lv_sn_relative.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0800  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0800 INPUT.
  sn_count = lines( lt_serials ).
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.

  CASE gv_okcode.
    WHEN 'BACK'.
      LEAVE TO SCREEN '0700'.
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
    WHEN 'HOME'.
      PERFORM confirm_to_leave.
    WHEN 'DELSN'.
      PERFORM delete_sn.
    WHEN 'SAVE'.
      PERFORM save_item.
    WHEN 'PREV'.
      sn_line = sn_line - num_of_lines.
      IF sn_line < 0.
        sn_line = 0.
      ENDIF.
    WHEN 'NEXT'.
      sn_line = sn_line + num_of_lines.
      IF sn_line > sn_count - num_of_lines.
        sn_line = sn_count - num_of_lines.
      ENDIF.
    WHEN 'UP'.
      IF sn_sel_line > sn_line + 1.
        sn_sel_line = sn_sel_line - 1.
      ENDIF.
    WHEN 'DOWN'.
      IF sn_sel_line < sn_line + num_of_lines
      AND sn_sel_line < sn_count.
        sn_sel_line = sn_sel_line + 1.
      ENDIF.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Form save_item
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM save_item .

  DATA: sv_matnr        TYPE matnr18.
*        lt_sernr_update TYPE shp_sernr_update_t,
*        ls_sernr_update TYPE shp_sernr_update_t WITH HEADER LINE.

  CLEAR: lt_verko, lt_verpo, lt_return.

  ls_vbkok-vbeln_vl = gv_vbeln.

  IF gv_is_serial = gc_x.

    sv_matnr = |{ lv_matnr ALPHA = IN }|.

    READ TABLE gt_del_items INTO DATA(ls_del_item) WITH KEY matnr = |{ sv_matnr ALPHA = IN }|.

    ls_verko-exidv = |{ gv_exidv ALPHA = IN }|.
    APPEND ls_verko TO lt_verko.

    ls_verpo-exidv_ob = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-exidv = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-posnr = ls_del_item-posnr.
    ls_verpo-velin = '1'.
    ls_verpo-tmeng = -1 * gv_init_qty.
    ls_verpo-matnr = sv_matnr .
    APPEND ls_verpo TO lt_verpo.

    CALL FUNCTION 'WS_DELIVERY_UPDATE'
      EXPORTING
        vbkok_wa                 = ls_vbkok
        synchron                 = 'X'
        commit                   = 'X'
        delivery                 = gv_vbeln
        update_picking           = 'X'
        nicht_sperren            = 'X'
        if_database_update       = '1'
        if_error_messages_send_0 = 'X'
*       it_sernr_update          = lt_sernr_update
      IMPORTING
        ef_error_any_0           = lw_ef_error_any
        ef_error_sernr_update    = lw_ef_error_sernr_update
      TABLES
        prot                     = lt_prot
        verko_tab                = lt_verko
        verpo_tab                = lt_verpo.
*        it_verpo_sernr           = lt_sernr.

    CLEAR lt_verpo.

    ls_verpo-exidv_ob = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-exidv = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-posnr = ls_del_item-posnr.
    ls_verpo-velin = '1'.
    ls_verpo-tmeng = gv_qty.
    ls_verpo-matnr = sv_matnr .
    APPEND ls_verpo TO lt_verpo.

    LOOP AT lt_serials INTO ls_serial.
      ls_sernr-exidv_ob = |{ gv_exidv ALPHA = IN }|.
      ls_sernr-belnr = gv_vbeln.
      ls_sernr-posnr = ls_del_item-posnr.
      ls_sernr-sernr = |{ ls_serial-sernr ALPHA = OUT }|.
      APPEND ls_sernr TO lt_sernr.

*      ls_sernr_update-rfbel = gv_vbeln.
*      ls_sernr_update-rfpos = ls_del_item-posnr.
*      ls_sernr_update-sernr = |{ ls_serial-sernr ALPHA = IN }|.
*      APPEND ls_sernr_update TO lt_sernr_update.
    ENDLOOP.

    CALL FUNCTION 'WS_DELIVERY_UPDATE'
      EXPORTING
        vbkok_wa                 = ls_vbkok
        synchron                 = 'X'
        commit                   = 'X'
        delivery                 = gv_vbeln
        update_picking           = 'X'
        nicht_sperren            = 'X'
        if_database_update       = '1'
        if_error_messages_send_0 = 'X'
*       it_sernr_update          = lt_sernr_update
      IMPORTING
        ef_error_any_0           = lw_ef_error_any
        ef_error_sernr_update    = lw_ef_error_sernr_update
      TABLES
        prot                     = lt_prot
        verko_tab                = lt_verko
        verpo_tab                = lt_verpo
        it_verpo_sernr           = lt_sernr.

*    LOOP AT lt_deleted_serials INTO ls_deleted_serial.
*      ls_sernr-exidv_ob = |{ gv_exidv ALPHA = IN }|.
*      ls_sernr-belnr = gv_vbeln.
*      ls_sernr-posnr = ls_del_item-posnr.
*      ls_sernr-sernr = |{ ls_deleted_serial-sernr ALPHA = IN }|.
*      APPEND ls_sernr TO lt_sernr.
*    ENDLOOP.

*    CALL FUNCTION 'WS_DELIVERY_UPDATE'
*      EXPORTING
*        vbkok_wa                 = ls_vbkok
*        synchron                 = 'X'
*        commit                   = 'X'
*        delivery                 = gv_vbeln
*        update_picking           = 'X'
*        nicht_sperren            = 'X'
*        if_database_update       = '1'
*        if_error_messages_send_0 = 'X'
**       it_sernr_update          = lt_sernr_update
*      IMPORTING
*        ef_error_any_0           = lw_ef_error_any
*        ef_error_sernr_update    = lw_ef_error_sernr_update
*      TABLES
*        prot                     = lt_prot
*        verko_tab                = lt_verko
*        verpo_tab                = lt_verpo.
**        it_verpo_sernr           = lt_sernr.
  ELSE.

    ls_verko-exidv = |{ gv_exidv ALPHA = IN }|.
    APPEND ls_verko TO lt_verko.

    ls_verpo-exidv_ob = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-exidv = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-velin = '1'.
    ls_verpo-tmeng = -1 * ls_item_list-vemng.
    ls_verpo-matnr = ls_item_list-matnr.
    APPEND ls_verpo TO lt_verpo.

    ls_verpo-exidv_ob = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-exidv = |{ gv_exidv ALPHA = IN }|.
    ls_verpo-velin = '1'.
    ls_verpo-tmeng = gv_qty.
    ls_verpo-matnr = ls_item_list-matnr.
    APPEND ls_verpo TO lt_verpo.

    CALL FUNCTION 'WS_DELIVERY_UPDATE'
      EXPORTING
        vbkok_wa                 = ls_vbkok
        synchron                 = 'X'
        commit                   = 'X'
        delivery                 = gv_vbeln
        update_picking           = 'X'
        nicht_sperren            = 'X'
        if_database_update       = '1'
        if_error_messages_send_0 = 'X'
      TABLES
        prot                     = lt_prot
        verko_tab                = lt_verko
        verpo_tab                = lt_verpo.
  ENDIF.

  CLEAR: lv_removed_qty.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form confirm_to_leave
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM confirm_to_leave .

  CALL FUNCTION 'CALL_MESSAGE_SCREEN'
    EXPORTING
      i_msgid          = 'LF'
      i_lang           = sy-langu
      i_msgno          = '202'
      i_message_screen = '0998'
      i_non_lmob_envt  = gc_x
    IMPORTING
      o_answer         = answer.

  IF sy-subrc <> 0.
* Implement suitable error handling here
  ELSE.
    IF answer = gc_x.
      LEAVE TO SCREEN '0200'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0900 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0900 OUTPUT.
  SET PF-STATUS 'S0900'.
  SET TITLEBAR 'T0900'.

  CLEAR gs_del_item.

  PERFORM init_delivery_data.
  MOVE-CORRESPONDING gt_del_items TO lt_to_pack_list[].

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0900  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0900 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.

  CASE gv_okcode.
    WHEN 'BACK'.
      LEAVE TO SCREEN '0200'.
    WHEN 'CANCEL' OR 'EXIT'.
      LEAVE PROGRAM.
    WHEN 'ADDHU'.
      PERFORM init_new_hu.
      CALL SCREEN '0300'.
    WHEN 'PACKHU'.
      CALL SCREEN '1100'.
    WHEN 'PREV'.
      line_pack = line_pack - num_of_stepl_lines.
      IF line_pack < 0.
        line = 0.
      ENDIF.
    WHEN 'NEXT'.
      line_pack = line_pack + num_of_stepl_lines.
      IF line_pack < lines_to_be_packed - num_of_stepl_lines.
        line_pack = lines_to_be_packed - num_of_stepl_lines.
      ENDIF.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module FILL_PACK_LIST OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE fill_pack_list OUTPUT.

  DATA(pack_index) = sy-stepl + line_pack.
  num_of_stepl_lines =  sy-loopc.

  lines_to_be_packed = lines( lt_to_pack_list ).

  READ TABLE lt_to_pack_list INTO ls_to_pack_list INDEX pack_index.
  ls_to_pack_list-matnr = |{ ls_to_pack_list-matnr ALPHA = OUT }|.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  CHECK_SERIAL  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE check_serial INPUT.

  SELECT SINGLE sernp
    FROM marc
    INTO @lv_sernp
    WHERE matnr = @gv_matnr
      AND werks = @gv_vstel.

  IF sy-subrc = 0 AND lv_sernp IS NOT INITIAL.
    gv_is_serial = gc_x.
    gv_qty       = 1.
*    CLEAR gv_sernr.           " Vider le SN pour nouvelle saisie
  ELSE.
    CLEAR: gv_is_serial, gv_sernr.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_01000 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_01000 OUTPUT.
  SET PF-STATUS 'S01000'.
  SET TITLEBAR 'T01000'.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_01000  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_01000 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.
  CASE gv_okcode.
    WHEN 'PACK'.
      PERFORM validate_pack_entry.
      PERFORM add_to_pack_buffer.
      PERFORM clear_fields.
    WHEN 'SAVE'.
      PERFORM validate_pack_entry.
      PERFORM add_to_pack_buffer.
      PERFORM commit_pack_buffer.
    WHEN 'CLEAR'.
      PERFORM clear_fields.
    WHEN 'HOME'.
      PERFORM clear_fields.
      PERFORM popup_confirm.
    WHEN 'BACK'.
      PERFORM clear_fields.
      PERFORM popup_confirm.
    WHEN 'EXIT' OR 'CANCEL'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module FILL_SERIALS OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE fill_serials OUTPUT.
  DATA(sn_idx) = sy-stepl + sn_line.

  READ TABLE lt_serials INTO ls_serial INDEX sn_idx.
  ls_serial-sernr = |{ ls_serial-sernr ALPHA = OUT }|.

  IF sn_idx = sn_sel_line.
    ls_serial-sn_sel_idx = gc_x.
  ELSE.
    CLEAR ls_serial-sn_sel_idx.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  MODIFY_SERIALS  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE modify_serials INPUT.

  num_of_lines = sy-loopc.
  sn_idx = sy-stepl + sn_line.

  MODIFY lt_serials FROM ls_serial INDEX sn_idx.
  READ TABLE lt_serials INTO ls_serial WITH KEY sn_sel_idx = gc_x.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Form delete_sn
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM delete_sn .
  READ TABLE lt_serials INTO ls_deleted_serial WITH KEY sn_sel_idx = gc_x.
  IF sy-subrc <> 0.
  ELSE.
    CLEAR: ls_deleted_serial-sn_sel_idx.
    APPEND ls_deleted_serial TO lt_deleted_serials.
  ENDIF.
  DELETE lt_serials WHERE sn_sel_idx = gc_x.
  gv_qty -= 1.

  lv_removed_qty = gv_init_qty - gv_qty.
ENDFORM.
