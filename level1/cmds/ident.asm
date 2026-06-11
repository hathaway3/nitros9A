********************************************************************
* Ident - Show module information
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*    6     ????/??/??  Kim Kempf
* Make -v flag be no verify
*
*          1982/12/30  Kim Kempf
* Add -x option
*
*   7      1093/02/18  Kim Kempf
* Display read-only header bit
* From Tandy OS-9 Level One VR 02.00.00.
*
*   8      2003/04/11  Boisy G. Pitre
* Now reports modules with a lang of Obj6309.
*
*   8r1    2005/03/07  Boisy G. Pitre
* Fixed so that an unsupported language shows ????

                    nam       Ident
                    ttl       Show module information

                  IFP1
                    use       defsfile
                  ENDC

DOHELP              set       0

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $01
edition             set       8

                    mod       eom,name,tylg,atrv,start,size

NAMLEN              set       32        Size of name buffer

**********
* Static Storage Offsets
*
                    org       0
linpos              rmb       2
pathptr             rmb       2
bufcnt              rmb       2
bufptr              rmb       2
bufsiz              rmb       2
dolink              rmb       1
short               rmb       1
modvfy              rmb       1
fperm               rmb       1
modptr              rmb       2
buf_curr            rmb       2
buf_end             rmb       2
mod_start           rmb       2
remaining_bytes     rmb       2
modcrc              rmb       3
crc                 rmb       3
modedit             rmb       1
zersup              rmb       1
zersupbl            rmb       1
path                rmb       1
mtype               rmb       1
modrev              rmb       1
dskmodln            rmb       2
dskbase1            rmb       2
dskbase2            rmb       2
linbuf              rmb       80
dskbuf              rmb       14
nambuf              rmb       NAMLEN
                    rmb       1
namsaf              rmb       251
stack               rmb       2048
size                equ       .

name                fcs       /Ident/
                    fcb       edition

                  IFNE    DOHELP
HelpMsg             fcb       C$LF
                    fcc       "Use: Ident [-opts] <path> [-opts]"
                    fcb       C$LF
                    fcc       "  -m = module in memory"
                    fcb       C$LF
                    fcc       "  -s = short form"
                    fcb       C$LF
                    fcc       "  -v = don't verify CRC"
                    fcb       C$LF
                    fcc       "  -x = file in exec dir"
                    fcb       C$CR
HelpLen             set       *-HelpMsg
                  ENDC

M_MInc              fcs       "Module header is incorrect!"
M_Hdr               fcs       "Header for: "
M_MSiz              fcs       "Module size:"
M_MCRC              fcs       "Module CRC: "
M_HdrP              fcs       "Hdr parity: "
M_ExOff             fcs       "Exec. off:  "
M_DatSz             fcs       "Data Size:  "
M_TLAR              fcs       "Ty/La At/Rv:"
M_Edtn              fcs       "Edition:    "
M_Mod               fcs       "mod,"
M_ReEn              fcs       "re-en,"
M_NonShr            fcs       "non-shr,"
M_RO                fcs       "R/O"
M_RW                fcs       "R/W"
M_Good              fcs       "(Good)"
M_Bad               fcc       "(Bad)"
                    fcb       $80+C$BELL

TypeTbl             fcb       T_BAD-TypeTbl
                    fcb       T_PR-TypeTbl
                    fcb       T_SU-TypeTbl
                    fcb       T_MU-TypeTbl
                    fcb       T_DA-TypeTbl
                    fcb       T_U5-TypeTbl
                    fcb       T_U6-TypeTbl
                    fcb       T_U7-TypeTbl
                    fcb       T_U8-TypeTbl
                    fcb       T_U9-TypeTbl
                    fcb       T_UA-TypeTbl
                    fcb       T_UB-TypeTbl
                    fcb       T_SY-TypeTbl
                    fcb       T_FM-TypeTbl
                    fcb       T_DRV-TypeTbl
                    fcb       T_DSC-TypeTbl
T_BAD               fcs       "bad type for"
T_PR                fcs       "Prog"
T_SU                fcs       "Subr"
T_MU                fcs       "Multi"
T_DA                fcs       "Data"
T_U5                fcs       "Usr 5"
T_U6                fcs       "Usr 6"
T_U7                fcs       "Usr 7"
T_U8                fcs       "Usr 8"
T_U9                fcs       "Usr 9"
T_UA                fcs       "Usr A"
T_UB                fcs       "Usr B"
T_SY                fcs       "System"
T_FM                fcs       "File Man"
T_DRV               fcs       "Dev Dvr"
T_DSC               fcs       "Dev Dsc"

LangTbl             fcb       L_DA-LangTbl
                    fcb       L_68-LangTbl
                    fcb       L_B09-LangTbl
                    fcb       L_PSC-LangTbl
                    fcb       L_C-LangTbl
                    fcb       L_COB-LangTbl
                    fcb       L_FOR-LangTbl
                    fcb       L_63-LangTbl
                    fcb       L_BAD-LangTbl
                    fcb       L_BAD-LangTbl
                    fcb       L_BAD-LangTbl
                    fcb       L_BAD-LangTbl
                    fcb       L_BAD-LangTbl
                    fcb       L_BAD-LangTbl
                    fcb       L_BAD-LangTbl
                    fcb       L_BAD-LangTbl
L_DA                fcs       "Data,"
L_68                fcs       "6809 obj,"
L_B09               fcs       "BASIC09 I-code,"
L_PSC               fcs       "PASCAL P-code,"
L_C                 fcs       "C I-code,"
L_COB               fcs       "COBOL I-code,"
L_FOR               fcs       "FORTRAN I-code,"
L_63                fcs       "6309 obj,"
L_BAD               fcs       "????"

**********
* Ident
*    Print module header
*
start               leas      >stack,u  move stack
                    sts       <bufptr   set buffer pointer
                    tfr       y,d       get end of RAM ptr
                    subd      <bufptr   get buffer size
                    std       <bufsiz   ..and set it
                    leay      <linbuf,u get output buffer addr
                    sty       <linpos   reset output buffer
                    clr       <dolink   assume disk module
                    clr       <short    assume full form
                    clr       <modvfy   assume CRC check
                    clr       <zersupbl no blanks on zero suppress
                    lda       #READ.    default file open mode
                    sta       <fperm    ..save it
                    ldd       #$0000    get a zero
                    std       <pathptr  zero path pointer
                    std       <bufcnt   clear buffer byte count

*****
* Parse out pathlist/options
*
IDNT02              lda       ,x+       get parameter character
IDNT03              cmpa      #C$SPAC   space?
                    beq       IDNT02    ..yes, skip it
                    cmpa      #C$COMA   comma?
                    beq       IDNT02    ..yes, skip it
                    cmpa      #C$CR     end-of-line?
                    beq       IDNT10    ..yes, take off
                    cmpa      #'-       start of options?
                    beq       IDNT05    ..yes, go process options
                    ldy       <pathptr  get path pointer
                    bne       IDNT02    ..don't save if already found
                    stx       <pathptr  ..first pathlist found
                    bra       IDNT02    look for more options

IDNT05              lda       ,x+       get the option character
                    cmpa      #'-       still doing options?
                    beq       IDNT05    ..yes, continue processing
                    cmpa      #'0       a (loosly) delim?
                    bcs       IDNT03    ..yes, back to pathlist scan

*****
* Handle -m option
*
                    eora      #'M       check a memory module?
                    anda      #$DF      upper or lower case
                    bne       IDNT06    ..no, not this option
                    inc       <dolink   display memory module
                    bra       IDNT05    look for more options

*****
* Handle -s option
*
IDNT06              lda       -$01,x    get the option character
                    eora      #'S       short form?
                    anda      #$DF      upper or lower case
                    bne       IDNT07    ..no, not this option
                    inc       <short    display short form
                    bra       IDNT05    look for more options

*****
* Handle -v option
*
IDNT07              lda       -$01,x    get the option character
                    eora      #'V       do CRC check?
                    anda      #$DF      upper or lower case
                    bne       IDNT08    ..no, not this option
                    inc       <modvfy   no CRC check
                    bra       IDNT05    look for more options

*****
* Handle -x option
*
IDNT08              lda       -$01,x    get the option character
                    eora      #'X       execution directory?
                    anda      #$DF      upper or lower case
                    bne       IDNT09    ..no, not this option
                    lda       #EXEC.+READ. exec mode
                    sta       <fperm    ..save it
                    bra       IDNT05    look for more options

*****
* Handle more options here
*
IDNT09              lbra      ShowHelp  bad option, print help

IDNT10              ldx       <pathptr  get start of pathlist
                    lbeq      ShowHelp  ..error if no pathlist found
                    leax      -$01,x    backup to start of pathlist

*****
* Dispatch
*
                    tst       <dolink
                    beq       DSKMOD

*****
* Handle module in memory
*
                    pshs      u         save data pointer
                    clra                any module, any type
                    os9       F$Link    link to the module
                    lbcs      IDNT99    ..error, exit
                    stu       <modptr   save abs. address of module
                    ldd       M$ID,u    get module id bytes
                    cmpd      #M$ID12   really a module header?
                    beq       IDNT12    yes, continue
                    puls      u
IDNT11              leay      >M_MInc,pcr
                    lbsr      OutName   print bad module message
                    lbsr      OutEol    print the line
                    clrb                return no error
                    lbra      IDNT99    ..and exit

*****
* Copy module CRC
*
IDNT12              ldd       pathptr,u load module size from header
                    subd      #$0003    backup up to the CRC bytes
                    leax      d,u       point to the CRC bytes
                    puls      u         get data pointer
                    leay      <modcrc,u point to CRC holder
                    pshs      u         save data pointer
                    lda       #$03      number of bytes to transfer
IDNT20              ldb       ,x+       get a byte
                    stb       ,y+       store the byte
                    deca
                    bne       IDNT20    until all copied
                    puls      u         restore data pointer

                    lbsr      SHOMOD    show the module data

                    ldu       <modptr   load module header address
                    os9       F$UnLink  unlink the module
                    lbcs      IDNT99    error
                    clrb                return no errors
                    lbra      IDNT99    ..and exit

*****
* Handle module on disk
*
DSKMOD              lda       #$80      ; get safety byte
                    sta       <namsaf
                    lda       <fperm    ; get open mode
                    os9       I$Open
                    lbcs      IDNT99
                    sta       <path

                    ;         Initialize buffer pointers
                    ldx       <bufptr
                    stx       <buf_curr
                    stx       <buf_end

                    ;         Initialize base file offset
                    ldd       #$0000
                    std       <dskbase1
                    std       <dskbase2

DSKM05              lbsr      ScanForModule ; find next `$87CD` in buffer/file
                    lbcs      DSKM99    ; if EOF/error, we are done

                    ;         We        found a module!
                    ldx       <buf_curr ; X = start of module in buffer
                    stx       <mod_start
                    stx       <modptr

                    ;         Load      module size
                    ldd       M$Size,x
                    std       <dskmodln

                    ;         Copy      name and edition directly from buffer
                    ldd       M$Name,x
                    leay      d,x       ; Y = name source address
                    leax      >nambuf,u ; dest
                    ldb       #NAMLEN+1
copy_name_loop      lda       ,y+
                    sta       ,x+
                    decb
                    bne       copy_name_loop

                    ;         Check     if CRC verify is skipped (-v)
                    tst       <modvfy
                    bne       no_crc_verify

                    ;         CRC       Verify mode: Compute CRC sequentially
                    ldd       #$FFFF
                    std       <crc
                    stb       <crc+2

                    ldd       <dskmodln
                    std       <remaining_bytes

                    ;         Start     CRC loop from mod_start
                    ldx       <mod_start
                    stx       <buf_curr

crc_loop            ldd       <remaining_bytes
                    beq       crc_done

                    ldd       <buf_end
                    subd      <buf_curr
                    tfr       d,y       ; Y = bytes available in buffer
                    bne       crc_have_bytes

                    ;         Buffer    is empty, refill it
                    lbsr      RefillBuffer
                    lbcs      IDNT99    ; exit on error/EOF
                    bra       crc_loop

crc_have_bytes      cmpy      <remaining_bytes
                    bls       crc_use_y
                    ldy       <remaining_bytes
crc_use_y           pshs      y
                    ldd       <remaining_bytes
                    subd      ,s
                    std       <remaining_bytes

                    ldx       <buf_curr
                    pshs      u
                    leau      <crc,u
                    os9       F$CRC
                    puls      u

                    puls      y
                    tfr       y,d
                    leay      d,x
                    sty       <buf_curr
                    bra       crc_loop

crc_done            ;         Copy      CRC bytes from buf_curr - 3
                    ldx       <buf_curr
                    lda       -3,x
                    ldb       -2,x
                    std       <modcrc
                    lda       -1,x
                    sta       <modcrc+2

                    bra       show_module_info

no_crc_verify       ;         Skip      verify: seek to end of module to get CRC if needed
                    ;         Actually, if the entire module is in the buffer:
                    ldd       <dskmodln
                    addd      <mod_start
                    cmpd      <buf_end
                    bls       crc_in_buf

                    ;         CRC       is outside buffer, seek to dskbase + mod_size - 3
                    ldd       <dskmodln
                    subd      #3        ; D = mod_size - 3
                    addd      <dskbase2
                    tfr       d,y       ; Y = low 16 bits of seek offset
                    ldx       <dskbase1 ; X = dskbase1
                    bcc       no_verify_seek
                    leax      1,x
no_verify_seek      pshs      u
                    tfr       y,u
                    lda       <path
                    os9       I$Seek
                    puls      u
                    lbcs      IDNT99

                    leax      <modcrc,u
                    ldy       #3
                    lda       <path
                    os9       I$Read
                    lbcs      IDNT99

                    ;         Since     we seeked, invalidate buffer pointers
                    ldx       <bufptr
                    stx       <buf_curr
                    stx       <buf_end
                    bra       show_module_info

crc_in_buf          ldd       <dskmodln
                    ldx       <mod_start
                    leax      d,x       ; X = end of module in buffer
                    lda       -3,x
                    ldb       -2,x
                    std       <modcrc
                    lda       -1,x
                    sta       <modcrc+2

                    ;         update    buf_curr to point past the module
                    stx       <buf_curr

show_module_info    lbsr      SHOMOD

                    ;         Update    dskbase for next module: dskbase = dskbase + mod_size
                    ldd       <dskmodln
                    addd      <dskbase2
                    std       <dskbase2
                    bcc       dskbase_ok
                    ldd       <dskbase1
                    addd      #1
                    std       <dskbase1
dskbase_ok          lbra      DSKM05

DSKM99              clrb

RefillBuffer        lda       <path
                    ldx       <bufptr
                    ldy       <bufsiz
                    os9       I$Read
                    bcs       refill_err
                    sty       <bufcnt
                    beq       refill_eof
                    stx       <buf_curr
                    tfr       y,d
                    addd      <bufptr
                    std       <buf_end
                    andcc     #$FE
                    rts
refill_eof          ldb       #E$EOF
                    orcc      #$01
refill_err          rts

EnsureBytes         pshs      y
                    ldd       <buf_end
                    subd      <buf_curr
                    cmpd      ,s++
                    bhs       ensure_ok

                    ldd       <buf_end
                    subd      <buf_curr
                    tfr       d,y
                    beq       ensure_empty

                    ldx       <buf_curr
                    pshs      u
                    ldu       <bufptr
shift_loop          lda       ,x+
                    sta       ,u+
                    leay      -1,y
                    bne       shift_loop
                    puls      u

ensure_empty        ldd       <buf_end
                    subd      <buf_curr
                    pshs      d
                    addd      <bufptr
                    tfr       d,x

                    ldd       <bufsiz
                    subd      ,s
                    tfr       d,y

                    lda       <path
                    os9       I$Read
                    bcs       ensure_err_pop
                    cmpy      #0
                    beq       ensure_eof_pop

                    tfr       y,d
                    addd      ,s+
                    std       <buf_end

                    ldx       <bufptr
                    stx       <buf_curr
ensure_ok           andcc     #$FE
                    rts
ensure_err_pop      leas      2,s
ensure_err          rts
ensure_eof_pop      leas      2,s
ensure_eof          ldb       #E$EOF
                    orcc      #$01
                    rts

ScanForModule       ldx       <buf_curr
scan_loop           cmpx      <buf_end
                    bhs       scan_refill

                    tfr       x,d
                    addd      #14
                    cmpd      <buf_end
                    bhi       scan_refill_partial

                    ldd       M$ID,x
                    cmpd      #M$ID12
                    beq       scan_found

                    leax      1,x
                    bra       scan_loop
scan_found          stx       <buf_curr
                    andcc     #$FE
                    rts
scan_refill         lbsr      RefillBuffer
                    bcs       scan_err
                    bra       ScanForModule
scan_refill_partial ldy       #14
                    lbsr      EnsureBytes
                    bcs       scan_err
                    bra       ScanForModule
scan_err            rts                 return no errors
                    bra       IDNT99

ShowHelp            equ       *
                  IFNE    DOHELP
                    lda       #$01      std output
                    leax      >HelpMsg,pcr point to help message
                    ldy       #HelpLen  ..and it's length
                    os9       I$WritLn  print the help
                  ENDC
                    clrb                return no errors

IDNT99              os9       F$Exit    terminate

**********
* SHOMOD
*    Print the module description
*
SHOMOD              tst       <short    short form?
                    lbne      ShoShrt   ..yes, show short form

                    lbsr      OutEol
                    leay      >M_Hdr,pcr
                    lbsr      OutName   print "Description of..."
                    lbsr      ShoName   print the name
                    lbsr      OutEol    print the line

                    leay      >M_MSiz,pcr
                    lbsr      OutName   print "Module size:"
                    ldy       <modptr   get address of module
                    ldd       M$Size,y  get module size
                    lbsr      HexLine   print the info line

                    leay      >M_MCRC,pcr
                    lbsr      OutName   print "Module CRC:"
                    lbsr      CRCOut    print the CRC bytes
                    tst       <modvfy   do the CRC check?
                    bne       SHOM07    ..yes
                    lbsr      CheckCRC  verify the CRC
                    tsta                was it OK?
                    beq       SHOM05    ..yes
                    leay      >M_Bad,pcr
                    lbsr      OutName   print " *** Bad CRC "
                    bra       SHOM07
SHOM05              leay      >M_Good,pcr
                    lbsr      OutName   print " (Correct)"
SHOM07              lbsr      OutEol    print the line

                    leay      >M_HdrP,pcr
                    lbsr      OutName   print "Header parity:"
                    ldy       <modptr   get module addr
                    ldb       M$Parity,y get module parity
                    lbsr      Hex2Out   print the hex bytes
                    lbsr      OutEol    print the line

                    ldy       <modptr   get module address
                    ldb       M$Type,y  get module type
                    stb       <mtype    save module type
                    andb      #TypeMask save hi nybble of type
                    cmpb      #Drivr    ..is a device driver
                    beq       SHOM10    ..yes; show parity and exec. offset
                    cmpb      #Prgrm    ..is a program module
                    bne       SHOM20    ..no; skip parity and exec. offset

SHOM10              leay      >M_ExOff,pcr
                    lbsr      OutName   print "Execution offset:"
                    ldy       <modptr   get module address
                    ldd       M$Exec,y  get execution offset
                    lbsr      HexLine   print the info line

                    leay      >M_DatSz,pcr
                    lbsr      OutName   print "Perm. Storage..."
                    ldy       <modptr   get module address
                    ldd       M$Mem,y   get memory size
                    lbsr      HexLine   print the info line

SHOM20              leay      >M_Edtn,pcr
                    lbsr      OutName   print "Edition:"
                    ldb       <modedit  get module edition
                    pshs      b         save for later
                    lbsr      Hex2Out   print the hex value
                    ldb       #$05      output some
                    lbsr      SpaceOut  ..spaces
                    puls      b         get edition
                    clra                do only the lo nybble
                    lbsr      DecOut    print in decimal
                    lbsr      OutEol    print the line

                    leay      >M_TLAR,pcr
                    lbsr      OutName   print "Type/Lang Attr/Rev:"
                    ldb       <mtype
                    lbsr      Hex2Out   output the Type/Lan byte
                    ldy       <modptr   get module address
                    ldb       M$Revs,y  get module revs
                    stb       <modrev   save for later
                    lbsr      Hex2Out   output the Attr/Rev bytes
                    lbsr      OutEol

                    ldb       <mtype    get module type
                    lsrb                shift down the high nibble
                    lsrb
                    lsrb
                    lsrb
                    leax      >TypeTbl,pcr get addr of addr table
                    lda       b,x       get the address of the text
                    leay      a,x       make the text address
                    lbsr      OutName   print the type text
                    leay      >M_Mod,pcr
                    lbsr      OutName   print " module"

                    ldb       <mtype    load module type
                    andb      #LangMask keep only the language nybble
                    leax      >LangTbl,pcr get addr of addr table
                    lda       b,x       get the address of the text
                    leay      a,x       make the text address
                    lbsr      OutName   print the language type

                    ldb       <modrev   get revision byte
                    bitb      #ReEnt    is module re-entrant?
                    beq       ATTR10    ..no
                    leay      >M_ReEn,pcr
                    lbsr      OutName   print "Re-entrant" and return
                    bra       ATTR20

ATTR10              leay      >M_NonShr,pcr
                    lbsr      OutName
ATTR20              bitb      #$40      print "Non-sharable"
                    beq       ATTR25    bra if not
                    leay      >M_RW,pcr
                    bra       SHOM98
ATTR25              leay      >M_RO,pcr
SHOM98              lbsr      OutName
                    lbsr      OutEol    print the line and return
                    rts

ShoName             tst       <dolink   memory module in memory?
                    beq       SHON02    ..no, get from special buffer
                    ldy       <modptr   get address of module
                    ldd       M$Name,y  get offset to name
                    leay      d,y       point to module name
                    bra       SHON05    go print the name

SHON02              leay      >nambuf,u load address of name buffer

SHON05              lbsr      OutName   print the module name
                    lda       ,y        get the Edition byte
                    sta       <modedit  save it for later
                    rts                 exit

**********
* ShoShrt
*  Show display in short form
*
ShoShrt             ldb       #$06      save some space in buffer
                    lbsr      SpaceOut  ..for module edition

                    ldy       <modptr   get address of module
                    ldb       M$Type,y  get module type/lang
                    lbsr      Hex2Out   display in hex
                    bsr       CRCOut    display CRC in hex
                    tst       <modvfy   do the CRC check?
                    beq       SHOS05    ..yes
                    lda       #C$SPAC   just a space if no CRC check
                    bra       SHOS10    go print it
SHOS05              bsr       CheckCRC  verify the CRC
                    tsta                was it ok?
                    bne       SHOS10    ..no, branch
                    lda       #C$PERD   print CRC ok character
SHOS10              lbsr      OutChar   print the CRC bad character
                    lbsr      PutSpc    space separator
                    bsr       ShoName   show the module name
                    ldx       <linpos   get the current line pointer
                    pshs      x         ..and save it
                    leax      <linbuf,u reset the line pointer
                    stx       <linpos   ..to beginning of buffer
                    ldb       <modedit  get module edition
                    inc       <zersupbl show blanks on zero supp
                    clra
                    lbsr      BinDec    show the edition
                    clr       <zersupbl no blanks on zero supp
                    puls      x         get the line pointer back
                    stx       <linpos   ..and restore it
                    lbsr      OutEol    print the short line
                    rts                 ..and return

**********
* CrcOut
*  Display CRC bytes
*
CRCOut              lda       #'$       put the hex sign
                    lbsr      OutChar   ..in the buffer
                    ldd       <modcrc   get the first 2 CRC bytes
                    lbsr      Bin4Hx    ..and store in buffer
                    ldb       <modcrc+2 get the third CRC byte
                    lbsr      Bin2Hs    ..and store in buffer
                    rts

**********
* CheckCrc
*  Verify module CRC
*
* Returns: (A)=0 if CRC is OK
*
CheckCRC            pshs      u,y,x     ; save registers
                    tst       <dolink   ; is module in memory?
                    beq       Check60   ; no, do nothing (CRC already computed!)

                    ldd       #$FFFF
                    std       <crc
                    stb       <crc+2
                    leau      <crc,u
                    ldx       <modptr
                    ldy       M$Size,x
                    os9       F$CRC
                    lbcs      IDNT99

Check60             puls      u,y,x
                    lda       <crc
                    cmpa      #CRCCon1
                    bne       Check90
                    ldd       <crc+1
                    cmpd      #CRCCon23
                    bne       Check90
                    clra
                    rts
Check90             lda       #$3F
                    rts

**********
* HexLine
*  Print line of Hex4 and Decimal
*
HexLine             pshs      b,a       save the value
                    bsr       Hex4Out   output the hex value
                    ldb       #$03      output some
                    bsr       SpaceOut  ..spaces
                    puls      b,a       get the value again
                    bsr       DecOut    output the decimal value
                    bsr       OutEol    print the buffer
                    rts

**********
* HiNyble
*  Print line of Hi nybble of B
*
HiNybble            pshs      b,a       save regs
                    andb      #$F0      mask high nybble
                    lsrb                shift if to right
                    lsrb                ..2
                    lsrb                ..3
                    lsrb                ..4 times
DoNybble            lda       #'$       put $ in buffer
                    bsr       OutChar   ..for $0
                    lbsr      HexChr    print the hex char
                    ldb       #$02      output some
                    bsr       SpaceOut  ..spaces
                    puls      pc,b,a    restore regs and RTS

LoNybble            pshs      b,a       save byte
                    andb      #$0F      mask low byte
                    bra       DoNybble  and show it

**********
* Outname
*    Print name, High byte delimiter
*
* Passed: (Y)=Ptr to name
* Destroys: A,CC
*
OutName             lda       ,y
                    anda      #$7F
                    bsr       OutChar
                    lda       ,y+
                    bpl       OutName
* Fall through to Outchar

**********
* Outchar
*    Put one char in output buffer
*
* Passed: (A)+Char
* Destroys: CC
*
Outspace            lda       #C$SPAC

OutChar             pshs      x
                    ldx       <linpos
                    sta       ,x+
                    stx       <linpos
                    puls      pc,x

**********
* OutEol
*    Print buffer
*
* Destroys: CC
*
OutEol              pshs      y,x,a
                    lda       #C$CR
                    bsr       OutChar   put carriage return in buffer
                    leax      <linbuf,u
                    stx       <linpos   reset line ptr
                    ldy       #80
                    lda       #$01
                    os9       I$WritLn
                    puls      pc,y,x,a

**********
* Hex4Out
*  Convert D to hex value; store in LINBUF
*
Hex4Out             pshs      a         save regs
                    lda       #'$       put a $ in the
                    bsr       OutChar   ..buffer for $0000
                    puls      a         restore regs
                    bsr       Bin4Hs    put the hex value in buffer
                    rts                 restore regs and RTS

**********
* Hex2Out
*  Convert B to hex value; store in LINBUF
*
Hex2Out             pshs      a         save regs
                    lda       #'$       put a $ in the
                    bsr       OutChar   ..buffer for $0
                    puls      a         restore regs
                    bsr       Bin2Hs    put the hex char in buffer
                    rts                 return

**********
* Hex1Out
* Convert low nybble of B to hex value; store in LINBUF
*
Hex1Out             pshs      a
                    lda       #'$       put a # in the
                    bsr       OutChar   ..buffer for #00000
                    puls      a         restore regs
                    bsr       HexChr    put the decimal value in buffer
                    rts

**********
* DecOut
*  Convert D to decimal value; store in LINBUF
*
DecOut              pshs      a
                    lda       #'#
                    bsr       OutChar
                    puls      a
                    bsr       BinDec
                    rts

**********
* SpaceOut
*  Put spaces in output buffer
*
* Passed: (B) number of spaces to output
*
SpaceOut            pshs      b,a
Space01             tstb                more?
                    ble       Space99   ..no, exit
                    bsr       Outspace  output a space
                    decb                bump counter
                    bra       Space01

Space99             puls      pc,b,a

**********
* Bin4Hs
*  Subroutine to convert word in D reg
*    to four-char hex followed by a space
*
* Passed: (D) Word to convert
* Destroys: CC
*
Bin4Hs              bsr       Bin4Hx    perform conversion
                    bra       PutSpc    go output a space and return

**********
* Bin2Hs
*  Subroutine to convert byte in B reg
*    to two-char hex followed by a space
*
* Passed: (B) Byte to convert
* Destroys: CC
*
Bin2Hs              bsr       Bin2Hx    perform conversion
* Fall through to Putspc

**********
* PutSpc
*  Put a space character in output buffer
*
PutSpc              pshs      a
                    lda       #C$SPAC
                    bsr       OutChar
                    puls      pc,a

**********
* Bin4Hx
*  Convert word in D register to
*    four-char hex
*
Bin4Hx              exg       a,b
                    bsr       Bin2Hx
                    tfr       a,b
* Fall through to convert low byte

**********
* Bin2Hx
*  Convert byte in B register to
*    two-char hex
*
Bin2Hx              pshs      b         save byte
                    andb      #$F0      mask HI nybble
                    lsrb                shift it to right
                    lsrb                ..2
                    lsrb                ..3
                    lsrb                ..4 times
                    bsr       HexChr    ..then convert it
                    puls      b         restore byte
                    andb      #$0F      mask low byte

HexChr              cmpb      #$09      range 0-9?
                    bls       HxChr2    ..yes, skip correction
                    addb      #$07      adjust for A-F
HxChr2              addb      #$30      make it ASCII
                    exg       a,b
                    lbsr      OutChar   put in buffer
                    exg       a,b
                    rts

**********
* BinDec
*  Convert word in D reg to
*    five-char decimal
BinDec              pshs      u,y,b     save local registers
                    leau      <TnsTbl,pcr get constants table address
                    clr       <zersup   set zero suppression
                    ldy       #$0005    Y is loop counter

* Digit conversion loop
BinDc2              clr       ,s        clear digit temp
BinDc3              subd      ,u        subtract power-of-ten
                    bcs       BinDc4    ..exit if underflow
                    inc       ,s        ..else bump count
                    bra       BinDc3    ...and do it again
BinDc4              addd      ,u++      restore and bump pointer
                    pshs      b         save low byte
                    ldb       $01,s     get digit counter
                    exg       a,b
                    bsr       ZeroSup   print with zero suppress
                    exg       a,b       restore lo byte
                    puls      b         on last digit?
                    cmpy      #$0002    ..no, continue
                    bgt       BinDc5    ..yes, print the digit always
                    inc       <zersup   ..yes, print the digit always
BinDc5              leay      -$01,y    decr loop count
                    bne       BinDc2    loop if more to do
                    puls      pc,u,y,b  pop regs and rts

* Power-of-Tens conversion table
TnsTbl              fdb       10000,1000,100,10,1

**********
* ZeroSup
*  Print with zero suppression
*
* Passed: (A)=Digit
* Destroys: A,CC
*
ZeroSup             tsta
                    beq       Zero10
                    sta       <zersup   ..no; end zero suppression
Zero10              tst       <zersup   zero suppression?
                    bne       Zero20    ..no: print digit
                    tst       <zersupbl show blanks on suppress?
                    beq       Zero15    ..no; exit
                    lda       #C$SPAC   print a space
                    bra       Zero30
Zero15              rts

Zero20              adda      #'0       make is ASCII
Zero30              lbra      OutChar

                    emod
eom                 equ       *
                    end
