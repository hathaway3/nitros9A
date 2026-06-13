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
;;; Syntax:	ls [<opts>] [<path>][<pattern>]
;;; Usage:	Displays a sorted list of the file names in a directory
;;; Parameters:
;;;     -a  include the . and .. directory entries
;;;     -l  long listing (owner, date, attributes, sector, size)
;;;     -r  recurse into subdirectories (depth first, like ls -R)
;;;     -x  list the execution directory
;;;
;;; The final pathname component may be a pattern: * matches any run
;;; of characters, ? matches any single character, case-insensitive
;;; (ls ab*, ls /dd/cmds/d?r).  A name that is not a directory is
;;; treated as an exact-match pattern, so ls startup lists one file.

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
QSZ                 equ       1024      pending-directory path stack (-r)
MAXPATH             equ       220       longest path we will recurse into

                    mod       eom,name,tylg,atrv,start,size

                    org       0
dirpath             rmb       1         directory path number
lflag               rmb       1         <>0 = long listing (-l)
rflag               rmb       1         <>0 = recurse (-r)
skipinit            rmb       1         entries to skip per dir (0 with -a)
hdrfst              rmb       1         <>0 once the first header is out
qovfl               rmb       1         <>0 = path stack overflowed
curplen             rmb       1         current path length
totcnt              rmb       2         entries listed across all dirs
qtop                rmb       2         path stack top (next free byte)
qend                rmb       2         path stack limit
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
patflg              rmb       1         <>0 = filtering with a pattern
slashp              rmb       2         last '/' in the token (0 = none)
mstar               rmb       2         matcher: position after last *
mss                 rmb       2         matcher: name restart position
patbuf              rmb       30        folded NUL-terminated pattern
nmbuf               rmb       30        folded NUL-terminated name
fdsect              rmb       FD.Creat-FD.ATT file descriptor head (-l)
optbuf              rmb       32        SS.Opt path option buffer
ptrtbl              rmb       MAXENT*2  sort pointer table
outbuf              rmb       OUTSZ     output staging buffer
dirbuf              rmb       DBUFSZ    directory read buffer
pathq               rmb       QSZ       pending-directory path stack
curpath             rmb       MAXPATH+12 current directory pathname
pool                rmb       MAXENT*DIR.SZ entry pool
                    rmb       250       stack
size                equ       .

name                fcs       /ls/
                    fcb       edition

Dot                 fcc       "."
                    fcb       C$CR
TruncMsg            fcc       "** directory truncated **"
TruncLen            equ       *-TruncMsg
DeepMsg             fcc       "** some directories skipped **"
DeepLen             equ       *-DeepMsg
PermMask            fcc       "dsewrewr"
                    fcb       $FF

start               clr       <lflag
                    clr       <rflag
                    clr       <addmode
                    clr       <alfflg
                    clr       <hdrfst
                    clr       <qovfl
                    clr       <patflg
                    lda       #2        the first two entries are .. and .
                    sta       <skipinit
                    ldd       #0
                    std       <totcnt
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
                    cmpa      #'r       recurse?
                    beq       SetR
                    cmpa      #'a       show . and .. as well?
                    beq       SetA
                    cmpa      #'x       execution dir?
                    bne       BadOpt
                    lda       #EXEC.
                    sta       <addmode
                    bra       POpt
SetL                sta       <lflag
                    bra       POpt
SetR                sta       <rflag
                    bra       POpt
SetA                clr       <skipinit
                    bra       POpt
BadOpt              ldb       #E$IllArg
Exit                os9       F$Exit
ExitOk              clrb
                    bra       Exit

* Learn what standard output is.  SS.Opt fills optbuf with the path
* options; pipes (piper getstat is a no-op) and errors leave it all
* zero.  LF is appended only for SCF paths with auto-LF on -- exactly
* what I$WritLn's line editing would have produced.
PDone               leax      optbuf,u
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

* Work out the starting directory, peeling off a trailing wildcard
* pattern if the token has one (the OS-9 shell does not expand
* wildcards for us).
                    ldx       <pathp
                    bne       ScanTok
                    leax      >Dot,pcr  no pathname given: use .
                    bra       SeedPath
ScanTok             stx       <tmpd     remember the token start
                    ldd       #0
                    std       <slashp
scan1               lda       ,x+
                    cmpa      #C$SPAC
                    beq       scand
                    cmpa      #C$CR
                    beq       scand
                    cmpa      #'/
                    bne       scan2
                    leay      -1,x      remember the last slash
                    sty       <slashp
                    bra       scan1
scan2               cmpa      #'*
                    beq       scan3
                    cmpa      #'?
                    bne       scan1
scan3               inc       <patflg
                    bra       scan1
scand               tst       <patflg
                    bne       SplitPat
* No wildcards: probe whether the token is a directory.
                    ldx       <tmpd
                    lda       #DIR.+READ.
                    ora       <addmode
                    os9       I$Open
                    bcs       NotADir
                    os9       I$Close   it is; the main loop reopens it
                    ldx       <tmpd
                    bra       SeedPath
* Not a directory: treat the token as an exact-name pattern.
NotADir             inc       <patflg
SplitPat            ldx       <slashp
                    beq       PatNoDir
                    lda       #C$CR     terminate the directory part
                    sta       ,x
                    leax      1,x       pattern begins after the slash
                    lbsr      CopyPat
                    ldx       <tmpd     and start from the directory part
                    bra       SeedPath
PatNoDir            ldx       <tmpd     pattern is the whole token
                    lbsr      CopyPat
                    leax      >Dot,pcr  matched against the current dir
* Copy the delimited starting directory into curpath and prime the
* pending-directory stack.
SeedPath            leay      curpath,u
                    clrb
seed1               lda       ,x+
                    cmpa      #C$SPAC
                    beq       seed2
                    cmpa      #C$CR
                    beq       seed2
                    sta       ,y+
                    incb
                    bra       seed1
seed2               lda       #C$CR
                    sta       ,y
                    stb       <curplen
                    leax      pathq,u
                    stx       <qtop
                    leax      pathq+QSZ,u
                    stx       <qend

*****
* Process one directory per pass: open, collect, sort, print, then
* with -r queue its subdirectories and pop the next pending path.
*****
DirLoop             leax      curpath,u
                    lda       #DIR.+READ.
                    ora       <addmode
                    os9       I$Open
                    lbcs      Exit
                    sta       <dirpath
                    ldd       #0        reset the per-directory state
                    std       <entcnt
                    clr       <maxnam
                    clr       <truncfl
                    lda       <skipinit
                    sta       <skipcnt
                    leay      pool,u
                    sty       <poolptr
                    leax      dirbuf,u  buffer starts out empty
                    stx       <dbptr
                    stx       <dbend
* -r names each directory ahead of its contents.
                    tst       <rflag
                    beq       Collect
                    tst       <hdrfst
                    beq       hdr1      no blank line before the first
                    lbsr      PutEOL
hdr1                inc       <hdrfst
                    leax      curpath,u
                    ldy       <bufptr
hdr2                lda       ,x+
                    cmpa      #C$CR
                    beq       hdr3
                    sta       ,y+
                    bra       hdr2
hdr3                lda       #':
                    sta       ,y+
                    sty       <bufptr
                    lbsr      PutEOL

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
                    lbeq      Collect
                    tst       <patflg   filtering against a pattern?
                    beq       nofilt
                    lbsr      FoldName  fold the entry name into nmbuf
                    lbsr      Match     does it fit the pattern?
                    bcc       nofilt    it does, keep it
* No match.  When recursing, a subdirectory still has to be visited
* so the pattern can be tried against its contents (find-like).
                    tst       <rflag
                    lbeq      Collect
                    lbsr      PushIfDir visit it, but don't list it
                    lbra      Collect
nofilt
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
RdDone              ldd       <totcnt   tally entries across all dirs
                    addd      <entcnt
                    std       <totcnt
                    ldd       <entcnt
                    lbeq      DirDone   nothing here: on to the next dir
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
                    lbls      SortDone
                    ldx       <tblbase
                    leax      2,x
                    stx       <outerx
SoLoop              ldx       <outerx
                    cmpx      <tblend
                    lbhs      SortDone
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

* Copy the delimited pattern at X to patbuf, folded, NUL-terminated.
CopyPat             leay      <patbuf,u
                    ldb       #29       at most a name's worth
cpat1               lda       ,x+
                    cmpa      #C$SPAC
                    beq       cpat2
                    cmpa      #C$CR
                    beq       cpat2
                    bsr       Fold
                    sta       ,y+
                    decb
                    bne       cpat1
cpat2               clr       ,y
                    rts

* Copy the hi-bit terminated entry name at X to nmbuf, folded,
* NUL-terminated.  X is preserved.
FoldName            pshs      x
                    leay      <nmbuf,u
fnm1                lda       ,x+
                    bmi       fnm2
                    bsr       Fold
                    sta       ,y+
                    bra       fnm1
fnm2                bsr       Fold      last character carries the hi bit
                    sta       ,y+
                    clr       ,y
                    puls      pc,x

* Glob-match nmbuf against patbuf (* = any run, ? = one character).
* Exit: carry clear on a match, carry set otherwise.  X and Y preserved.
Match               pshs      y,x
                    leax      <patbuf,u
                    leay      <nmbuf,u
                    ldd       #0
                    std       <mstar
mat1                ldb       ,y        current name char (0 = end)
                    lda       ,x+       current pattern char
                    beq       matpend   pattern exhausted
                    cmpa      #'*
                    beq       matstar
                    tstb
                    beq       matback   name ended before the pattern
                    cmpa      #'?
                    beq       matadv    ? swallows any one character
                    pshs      b
                    cmpa      ,s+
                    bne       matback
matadv              leay      1,y
                    bra       mat1
matstar             stx       <mstar    resume point after the star
                    sty       <mss      name position the star covers
                    bra       mat1
matpend             tstb                both exhausted = a match
                    beq       matok
matback             ldx       <mstar    mismatch: grow the last star
                    beq       matfail   there wasn't one
                    ldy       <mss
                    ldb       ,y
                    beq       matfail   star cannot grow past the end
                    leay      1,y
                    sty       <mss
                    bra       mat1
matok               andcc     #$FE
                    puls      pc,y,x
matfail             orcc      #$01
                    puls      pc,y,x

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
                    lbsr      PutName   B = characters emitted
                    stb       <tmpd     remember the length (ldd below kills B)
                    ldd       <idxoff   step down one column
                    addd      <nrows2
                    std       <idxoff
                    cmpd      <entsz2   anything left on this row?
                    bhs       RowDone
                    lda       <colw     pad the column with spaces
                    suba      <tmpd
                    lbsr      PutSpaces
                    bra       RowEnt
RowDone             lbsr      PutEOL
                    ldd       <rowoff
                    addd      #2
                    std       <rowoff
                    bra       RowL
OutDone             tst       <truncfl
                    beq       DirDone
                    leax      >TruncMsg,pcr
                    ldy       <bufptr
                    ldb       #TruncLen
trc                 lda       ,x+
                    sta       ,y+
                    decb
                    bne       trc
                    sty       <bufptr
                    lbsr      PutEOL

* Directory finished.  With -r, push its subdirectories (walking the
* sorted table backward so the pop order is depth-first preorder),
* then close it and pop the next pending path.
DirDone             tst       <rflag
                    lbeq      CloseDir
                    ldd       <entcnt
                    lbeq      CloseDir
                    ldx       <tblend
qploop              cmpx      <tblbase
                    bhi       qpbody
                    lbra      CloseDir
qpbody              leax      -2,x
                    stx       <curs
                    ldx       ,x        X = entry
                    lbsr      PushIfDir
                    ldx       <curs
                    lbra      qploop

* If the directory entry at X is a subdirectory, push curpath + '/' +
* its name onto the pending stack as a trailer-length record.  The .
* and .. links are never pushed.  X is preserved.
PushIfDir           stx       <entp
                    lda       ,x
                    cmpa      #'.+$80
                    beq       pidret
                    cmpa      #'.
                    bne       pidchk
                    lda       1,x
                    cmpa      #'.+$80
                    beq       pidret
pidchk              pshs      u         is the entry a directory?
                    lda       DIR.FD,x
                    ldb       #FD.Creat-FD.ATT
                    tfr       d,y
                    ldu       DIR.FD+1,x
                    ldx       ,s
                    leax      <fdsect,x
                    lda       <dirpath
                    ldb       #SS.FDInf
                    os9       I$GetStt
                    puls      u
                    bcs       pidret
                    lda       <fdsect+FD.ATT
                    bpl       pidret    a plain file
* Push curpath + '/' + name, with a trailing length byte.
                    ldb       <curplen
                    cmpb      #MAXPATH
                    bhi       pidfull   path would grow too long
                    clra
                    addd      #31       worst case name + slash + trailer
                    addd      <qtop
                    cmpd      <qend
                    bls       pidroom
pidfull             inc       <qovfl    no room: note it and carry on
                    bra       pidret
pidroom             ldy       <qtop
                    leax      curpath,u
                    ldb       <curplen
pidc1               lda       ,x+
                    sta       ,y+
                    decb
                    bne       pidc1
                    lda       #'/
                    sta       ,y+
                    ldx       <entp
                    ldb       <curplen
                    incb                count the slash
pidc2               lda       ,x+
                    bmi       pidc3
                    sta       ,y+
                    incb
                    bra       pidc2
pidc3               anda      #$7F
                    sta       ,y+
                    incb
                    stb       ,y+       record trailer = total length
                    sty       <qtop
pidret              ldx       <entp
                    rts

CloseDir            lda       <dirpath
                    os9       I$Close
                    tst       <rflag
                    beq       Finish
                    ldx       <qtop     anything left to visit?
                    leay      pathq,u
                    pshs      y
                    cmpx      ,s++
                    beq       Finish
* Pop the most recently pushed path into curpath.
                    ldb       -1,x      record length
                    stb       <curplen
                    clra
                    addd      #1        record plus its trailer
                    pshs      d
                    ldd       <qtop
                    subd      ,s++
                    std       <qtop
                    tfr       d,x       X = start of the path text
                    ldb       <curplen
                    leay      curpath,u
pop1                lda       ,x+
                    sta       ,y+
                    decb
                    bne       pop1
                    lda       #C$CR
                    sta       ,y
                    lbra      DirLoop

Finish              ldd       <totcnt   anything listed anywhere?
                    bne       FinOk
                    tst       <patflg
                    beq       FinOk
                    lbsr      FlushOut  pattern matched nothing at all
                    ldb       #E$PNNF
                    lbra      Exit
FinOk               tst       <qovfl
                    beq       fin2
                    leax      >DeepMsg,pcr
                    ldy       <bufptr
                    ldb       #DeepLen
finm                lda       ,x+
                    sta       ,y+
                    decb
                    bne       finm
                    sty       <bufptr
                    lbsr      PutEOL
fin2                lbsr      FlushOut
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
