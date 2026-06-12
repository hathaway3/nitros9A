********************************************************************
* ls - Sorted directory lister
*
* Modeled on dir.asm, tuned for speed:
*  - directory is read in 1024-byte sector-aligned chunks (RBF
*    sectors are 256 bytes; reads stay on 256-byte multiples)
*  - entries are gathered, sorted, then formatted into a 1KB output
*    buffer that is flushed with single large I$Write calls -- no
*    per-character or per-line system calls
*  - the 32-byte entry copy is fully unrolled
*  - all scalar state lives in the direct page
*
* Output line endings: CR, plus LF only when standard output is an
* SCF path with auto-linefeed enabled (read via SS.Opt).  This
* reproduces exactly what I$WritLn's line editing would have done,
* while still allowing multi-line raw writes.
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   1      2026/06/12  Jim Hathaway
* Created.

;;; ls
;;;
;;; Syntax:	ls [<opts>] [<path>]
;;; Usage:	Displays a sorted list of the file names in a directory
;;; Parameters:
;;;     -a  include the . and .. directory entries
;;;     -l  long listing (owner, date, attributes, sector, size)
;;;     -x  list the execution directory

                    nam       ls
                    ttl       Sorted directory lister

                  IFP1
                    use       defsfile
                  ENDC

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

MAXENT              equ       256       most entries we can sort
OUTSZ               equ       1024      output buffer size
OUTMARG             equ       300       worst-case line length headroom
DBUFSZ              equ       1024      directory read buffer (256-multiple)

                    mod       eom,name,tylg,atrv,start,size

                    org       0
dirpath             rmb       1         directory path number
lflag               rmb       1         <>0 = long listing (-l)
addmode             rmb       1         extra I$Open mode (-x adds EXEC.)
alfflg              rmb       1         <>0 = append LF after each CR
scrwid              rmb       1         screen width
colw                rmb       1         column width (maxnam+2)
maxnam              rmb       1         longest name seen
skipcnt             rmb       1         leading entries to skip (. and ..)
zsup                rmb       1         hex leading-zero suppress state
truncfl             rmb       1         <>0 = directory had > MAXENT entries
entcnt              rmb       2         number of entries collected
entsz2              rmb       2         entcnt*2 (pointer table size)
bufptr              rmb       2         output buffer position
outtop              rmb       2         output buffer flush threshold
dbptr               rmb       2         directory buffer position
dbend               rmb       2         directory buffer end
poolptr             rmb       2         next free entry pool slot
tblbase             rmb       2         pointer table base address
tblend              rmb       2         pointer table end address
keyptr              rmb       2         sort: key entry pointer
outerx              rmb       2         sort: outer cursor
curs                rmb       2         sort: inner cursor save
entp                rmb       2         current entry pointer
nrows2              rmb       2         rows*2 (table offset step/column)
rowoff              rmb       2         current row table offset
idxoff              rmb       2         current entry table offset
pathp               rmb       2         pathname pointer from cmd line
tmpd                rmb       2         scratch word
fdsect              rmb       FD.Creat-FD.ATT file descriptor head (-l)
optbuf              rmb       32        SS.Opt path option buffer
ptrtbl              rmb       MAXENT*2  sort pointer table
outbuf              rmb       OUTSZ     output staging buffer
dirbuf              rmb       DBUFSZ    directory read buffer
pool                rmb       MAXENT*DIR.SZ entry pool
                    rmb       250       stack
size                equ       .

name                fcs       /ls/
                    fcb       edition

Dot                 fcc       "."
                    fcb       C$CR
TruncMsg            fcc       "** directory truncated **"
TruncLen            equ       *-TruncMsg
PermMask            fcc       "dsewrewr"
                    fcb       $FF

start               clr       <lflag
                    clr       <addmode
                    clr       <alfflg
                    clr       <maxnam
                    clr       <truncfl
                    lda       #2        the first two entries are .. and .
                    sta       <skipcnt
                    ldd       #0
                    std       <entcnt
                    std       <pathp
                    leay      outbuf,u  set up the output buffer
                    sty       <bufptr
                    leay      outbuf+OUTSZ-OUTMARG,u
                    sty       <outtop
                    leay      pool,u    and the entry pool
                    sty       <poolptr
                    leay      ptrtbl,u  and the pointer table
                    sty       <tblbase

* Parse the command line.  X = parameter pointer.
Parse               lda       ,x+       get a character
                    cmpa      #C$CR     end of line?
                    beq       PDone
                    cmpa      #C$SPAC   filler?
                    beq       Parse
                    cmpa      #'-       an option?
                    beq       POpt
* A pathname: remember the first one, skip the token either way
                    ldy       <pathp
                    bne       PSkip     already have one
                    leax      -1,x
                    stx       <pathp
                    leax      1,x
PSkip               lda       ,x+       skip to the next delimiter
                    cmpa      #C$SPAC
                    beq       Parse
                    cmpa      #C$CR
                    bne       PSkip
                    bra       PDone
POpt                lda       ,x+       get the option letter
                    cmpa      #C$CR
                    beq       PDone
                    cmpa      #C$SPAC
                    beq       Parse
                    ora       #$20      fold to lower case
                    cmpa      #'l       long listing?
                    beq       SetL
                    cmpa      #'a       show . and .. as well?
                    beq       SetA
                    cmpa      #'x       execution dir?
                    bne       BadOpt
                    lda       #EXEC.
                    sta       <addmode
                    bra       POpt
SetL                sta       <lflag
                    bra       POpt
SetA                clr       <skipcnt
                    bra       POpt
BadOpt              ldb       #E$IllArg
Exit                os9       F$Exit
ExitOk              clrb
                    bra       Exit

* Learn what standard output is.  SS.Opt fills optbuf with the path
* options; pipes (piper getstat is a no-op) and errors leave it all
* zero.  LF is appended only for SCF paths with auto-LF on -- exactly
* what I$WritLn's line editing would have produced.
PDone               leax      <optbuf,u
                    ldb       #31       zero the buffer first
                    clra
zopt                sta       b,x
                    decb
                    bpl       zopt
                    lda       #1        standard output
                    ldb       #SS.Opt
                    os9       I$GetStt
                    lda       <optbuf+(PD.DTP-PD.OPT) device type
                    cmpa      #DT.SCF   character device?
                    bne       NoAlf
                    lda       <optbuf+(PD.ALF-PD.OPT) auto linefeed?
                    beq       NoAlf
                    sta       <alfflg
NoAlf
* Screen width: preload X in case the driver ignores SS.ScSiz (Ed13
* fix from dir.asm), then take the low byte of the answer.
                    lda       #1
                    ldb       #SS.ScSiz
                    ldx       #80
                    os9       I$GetStt
                    tfr       x,d
                    tstb
                    bne       SavWid
                    ldb       #80       0 means nobody answered
SavWid              stb       <scrwid

* Open the directory.
                    ldx       <pathp
                    bne       OpenIt
                    leax      >Dot,pcr  no pathname given: use .
OpenIt              lda       #DIR.+READ.
                    ora       <addmode
                    os9       I$Open
                    lbcs      Exit
                    sta       <dirpath
                    leax      dirbuf,u  buffer starts out empty
                    stx       <dbptr
                    stx       <dbend

*****
* Collection pass: read the directory in sector-aligned chunks and
* copy live entries into the pool.
*****
Collect             ldx       <dbptr
                    cmpx      <dbend
                    blo       HaveEnt
                    lda       <dirpath  refill the buffer
                    ldy       #DBUFSZ
                    leax      dirbuf,u
                    os9       I$Read
                    lbcs      RdEof     EOF (or error) ends collection
                    leax      dirbuf,u
                    stx       <dbptr
                    tfr       y,d
                    addd      <dbptr
                    std       <dbend
                    ldx       <dbptr
HaveEnt             leay      DIR.SZ,x
                    sty       <dbptr
                    lda       <skipcnt  still inside . and .. ?
                    beq       ChkLive
                    deca
                    sta       <skipcnt
                    bra       Collect
ChkLive             tst       ,x        deleted entry?
                    beq       Collect
* Copy the 32-byte entry into the pool -- fully unrolled.
                    ldy       <poolptr
                    ldd       ,x
                    std       ,y
                    ldd       2,x
                    std       2,y
                    ldd       4,x
                    std       4,y
                    ldd       6,x
                    std       6,y
                    ldd       8,x
                    std       8,y
                    ldd       10,x
                    std       10,y
                    ldd       12,x
                    std       12,y
                    ldd       14,x
                    std       14,y
                    ldd       16,x
                    std       16,y
                    ldd       18,x
                    std       18,y
                    ldd       20,x
                    std       20,y
                    ldd       22,x
                    std       22,y
                    ldd       24,x
                    std       24,y
                    ldd       26,x
                    std       26,y
                    ldd       28,x
                    std       28,y
                    ldd       30,x
                    std       30,y
* Record it in the pointer table and track the longest name.
                    ldd       <entcnt
                    lslb                entcnt*2 = table offset
                    rola
                    leax      ptrtbl,u
                    leax      d,x
                    sty       ,x
                    clrb                measure the name
nmlen               incb
                    lda       ,y+
                    bpl       nmlen
                    cmpb      <maxnam
                    bls       nmok
                    stb       <maxnam
nmok                ldy       <poolptr  advance the pool
                    leay      DIR.SZ,y
                    sty       <poolptr
                    ldd       <entcnt
                    addd      #1
                    std       <entcnt
                    cmpd      #MAXENT   out of room to sort?
                    lblo      Collect
                    inc       <truncfl  note it and stop collecting
                    bra       RdDone
RdEof               cmpb      #E$EOF    real error?
                    lbne      Exit
RdDone              ldd       <entcnt
                    lbeq      ExitOk    empty directory: nothing to say
                    lslb                entsz2 = entcnt*2
                    rola
                    std       <entsz2
                    addd      <tblbase
                    std       <tblend

*****
* Sort the pointer table (insertion sort, case-insensitive names).
*****
                    ldd       <entcnt
                    cmpd      #1
                    bls       SortDone
                    ldx       <tblbase
                    leax      2,x
                    stx       <outerx
SoLoop              ldx       <outerx
                    cmpx      <tblend
                    bhs       SortDone
                    ldd       ,x        key = tbl[i]
                    std       <keyptr
                    tfr       x,y       Y = candidate slot (j+1)
SoIn                cmpy      <tblbase
                    bls       SoIns     hit the front: insert here
                    ldx       -2,y      X = tbl[j] (name is at offset 0)
                    sty       <curs
                    ldy       <keyptr
                    bsr       NamCmp    carry set if tbl[j] > key
                    ldy       <curs
                    bcc       SoIns     in order: insert here
                    ldd       -2,y      shift tbl[j] up a slot
                    std       ,y
                    leay      -2,y
                    bra       SoIn
SoIns               ldd       <keyptr
                    std       ,y
                    ldx       <outerx
                    leax      2,x
                    stx       <outerx
                    bra       SoLoop

* Compare the hi-bit terminated names at X and Y, case-insensitive.
* Exit: carry set if name(X) > name(Y), else carry clear.
NamCmp              lda       ,x+
                    ldb       ,y+
                    std       <tmpd     keep the raw pair for the hi bits
                    bsr       Fold
                    exg       a,b
                    bsr       Fold
                    exg       a,b
                    pshs      b
                    cmpa      ,s+
                    bhi       NCgt      X's char collates higher
                    blo       NCle      X's char collates lower
                    lda       <tmpd     equal: who ended?
                    bmi       NCle      X done first (or both): X <= Y
                    lda       <tmpd+1
                    bmi       NCgt      Y done but X continues: X > Y
                    bra       NamCmp
NCgt                orcc      #$01
                    rts
NCle                andcc     #$FE
                    rts

* Fold A: strip the hi bit, upper-case letters.
Fold                anda      #$7F
                    cmpa      #'a
                    blo       FoldR
                    cmpa      #'z
                    bhi       FoldR
                    suba      #$20
FoldR               rts

*****
* Output.
*****
SortDone            tst       <lflag
                    lbne      LongList

* Multi-column names, sorted down the columns like ls.
                    lda       <maxnam
                    adda      #2
                    sta       <colw
                    lda       <scrwid   columns = width/colw, at least 1
                    clrb
ncl                 suba      <colw
                    bcs       ncl2
                    incb
                    bra       ncl
ncl2                tstb
                    bne       ncl3
                    incb
ncl3                clra                rows = ceil(entcnt/ncols)
                    tfr       d,x       X = ncols
                    ldd       <entcnt
                    addd      #-1
                    pshs      x
                    addd      ,s        D = entcnt+ncols-1
                    ldy       #0
nrw                 leay      1,y       divide by ncols
                    subd      ,s
                    cmpd      ,s
                    bhs       nrw
                    leas      2,s
                    tfr       y,d       D = rows
                    lslb
                    rola
                    std       <nrows2
                    ldd       #0
                    std       <rowoff
RowL                ldd       <rowoff
                    cmpd      <nrows2
                    bhs       OutDone
                    std       <idxoff
RowEnt              ldd       <idxoff
                    leax      ptrtbl,u
                    ldx       d,x       X = entry (name at offset 0)
                    bsr       PutName   B = characters emitted
                    stb       <tmpd     remember the length (ldd below kills B)
                    ldd       <idxoff   step down one column
                    addd      <nrows2
                    std       <idxoff
                    cmpd      <entsz2   anything left on this row?
                    bhs       RowDone
                    lda       <colw     pad the column with spaces
                    suba      <tmpd
                    bsr       PutSpaces
                    bra       RowEnt
RowDone             bsr       PutEOL
                    ldd       <rowoff
                    addd      #2
                    std       <rowoff
                    bra       RowL
OutDone             tst       <truncfl
                    beq       AllOut
                    leax      >TruncMsg,pcr
                    ldy       <bufptr
                    ldb       #TruncLen
trc                 lda       ,x+
                    sta       ,y+
                    decb
                    bne       trc
                    sty       <bufptr
                    bsr       PutEOL
AllOut              bsr       FlushOut
                    lbra      ExitOk

* Append the hi-bit terminated name at X to the output buffer.
* Exit: B = number of characters written.  X past the name.
PutName             ldy       <bufptr
                    clrb
pnm1                lda       ,x+
                    bmi       pnm2
                    sta       ,y+
                    incb
                    bra       pnm1
pnm2                anda      #$7F
                    sta       ,y+
                    incb
                    sty       <bufptr
                    rts

* Append A spaces to the output buffer.
PutSpaces           tfr       a,b
                    ldy       <bufptr
                    lda       #C$SPAC
psp1                sta       ,y+
                    decb
                    bne       psp1
                    sty       <bufptr
                    rts

* End the line: CR (plus LF when emulating SCF auto-linefeed), then
* flush the buffer with one big I$Write once it is nearly full.
PutEOL              ldy       <bufptr
                    lda       #C$CR
                    sta       ,y+
                    tst       <alfflg
                    beq       peo1
                    lda       #C$LF
                    sta       ,y+
peo1                sty       <bufptr
                    cmpy      <outtop
                    bhs       FlushOut
                    rts

FlushOut            ldd       <bufptr
                    leax      outbuf,u
                    pshs      x
                    subd      ,s++      D = bytes buffered
                    beq       flo1
                    tfr       d,y
                    leax      outbuf,u
                    lda       #1
                    os9       I$Write
                    lbcs      Exit
                    leax      outbuf,u
                    stx       <bufptr
flo1                rts

*****
* Long listing: one line per entry, dir -e style.
* owner date time attrs sector size name
*****
LongList            ldd       #0
                    std       <idxoff
LL1                 ldd       <idxoff
                    cmpd      <entsz2
                    lbhs      LLdone
                    leax      ptrtbl,u
                    ldx       d,x       X = entry
                    stx       <entp
* Fetch the file descriptor head via SS.FDInf.
                    pshs      u
                    lda       DIR.FD,x  LSN bits 16-23
                    ldb       #FD.Creat-FD.ATT
                    tfr       d,y
                    ldu       DIR.FD+1,x LSN bits 0-15 (before X moves!)
                    ldx       ,s        caller's U
                    leax      <fdsect,x
                    lda       <dirpath
                    ldb       #SS.FDInf
                    os9       I$GetStt
                    puls      u
                    lbcs      Exit
* owner
                    clr       <zsup
                    ldd       <fdsect+FD.OWN
                    lbsr      PHexW
                    bsr       PutSp
* modified date and time
                    leax      <fdsect+FD.DAT,u
                    bsr       PYear
                    bsr       PSlash
                    bsr       PSlash
                    bsr       PutSp
                    bsr       PB2A      hours
                    lda       #':
                    bsr       OutCh
                    bsr       PB2A      minutes
                    bsr       PutSp
* attributes
                    ldb       <fdsect+FD.ATT
                    leax      >PermMask,pcr
                    lda       ,x+
pat1                lslb
                    bcs       pat2
                    lda       #'-
pat2                bsr       OutCh
                    lda       ,x+
                    bpl       pat1
                    bsr       PutSp
                    bsr       PutSp
* sector (24 bits) and size (32 bits), hex
                    ldx       <entp
                    clr       <zsup
                    lda       DIR.FD,x
                    bsr       PHexB
                    ldx       <entp
                    ldd       DIR.FD+1,x
                    bsr       PHexW
                    clr       <zsup
                    ldd       <fdsect+FD.SIZ
                    bsr       PHexB
                    tfr       b,a
                    bsr       PHexB
                    ldd       <fdsect+FD.SIZ+2
                    bsr       PHexW
* name
                    ldx       <entp
                    lbsr      PutName
                    lbsr      PutEOL
                    ldd       <idxoff
                    addd      #2
                    std       <idxoff
                    lbra      LL1
LLdone              lbra      OutDone

* Append one character (A) to the output buffer; X preserved.
OutCh               pshs      x
                    ldx       <bufptr
                    sta       ,x+
                    stx       <bufptr
                    puls      pc,x

PutSp               lda       #C$SPAC
                    bra       OutCh

* '/' then a 2-digit value from ,x+
PSlash              lda       #'/
                    bsr       OutCh
PB2A                ldb       ,x+
                    subb      #100      PTensU counts up from the -100 residue
                    bra       PTensU

* 4-digit year with century (Glenside Y2K arithmetic, as in dir).
PYear               lda       #'.+128
                    ldb       ,x
pyr1                inca
                    subb      #100
                    bcc       pyr1
                    stb       ,x        remainder = 2-digit year
                    tfr       a,b
                    bsr       PTensU    prints the century digits
                    ldb       ,x+
* Print B (0-99) as two decimal digits.
PTensU              lda       #'9+1
ptu1                deca
                    addb      #10
                    bcc       ptu1
                    bsr       OutCh     tens
                    tfr       b,a
                    adda      #'0
                    bra       OutCh     units

* Print A as 2 hex digits honoring leading-zero suppression (zsup).
PHexB               pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    bsr       PNib
                    puls      a
                    anda      #$0F
PNib                tsta                zero digit?
                    beq       pni1
                    sta       <zsup     nonzero: stop suppressing
pni1                tst       <zsup
                    bne       pni2
                    lda       #C$SPAC   suppressed: align with a space
                    bra       OutCh
pni2                adda      #'0
                    cmpa      #'9
                    bls       pni3
                    adda      #7
pni3                bra       OutCh

* Print D as 4 hex digits (zsup honored, last digit always printed),
* followed by a space.
PHexW               bsr       PHexB
                    tfr       b,a
                    pshs      a
                    lsra
                    lsra
                    lsra
                    lsra
                    bsr       PNib
                    inc       <zsup     final digit always shows
                    puls      a
                    anda      #$0F
                    bsr       PNib
                    bra       PutSp

                    emod
eom                 equ       *
                    end
