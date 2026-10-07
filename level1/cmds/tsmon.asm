*******************************************************************
* Tsmon - Timesharing monitor
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   6      ????/??/??
* From Tandy OS-9 Level Two VR 02.00.01.

                    nam       Tsmon
                    ttl       Timesharing monitor

* Disassembled 02/07/13 23:44:55 by Disasm v1.6 (C) 1988 by RML

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       9

                    mod       eom,name,tylg,atrv,start,size

                    org       0
childid             rmb       1
parmptr             rmb       2
parmlen             rmb       2
cmdptr              rmb       2
cmdprm              rmb       2
inbuff              rmb       451
size                equ       .

name                fcs       /Tsmon/
                    fcb       edition

Login               fcc       "LOGIN"
LoginPrm            fcb       C$CR

IcptRtn             rti

start               stx       <parmptr            save parameter pointer
                    std       <parmlen            save parameter length
                    leax      <IcptRtn,pcr        point to intercept routine
                    os9       F$Icpt              and set it
                    leax      <Login,pcr          default command: LOGIN
                    stx       <cmdptr
                    leax      <LoginPrm,pcr       default params: C$CR
                    stx       <cmdprm
L0024               ldx       <parmptr            get pointer to parameter
                    ldd       <parmlen            and length
                    cmpd      #$0002
                    bcs       L0052
                    lda       ,x                  get byte at command line
                    cmpa      #C$CR               cr?
                    beq       L0052               if so, branch
                    clra                          stdin
                    os9       I$Close             close it
                    lda       #UPDAT.
                    os9       I$Open              open device on command line
                    lbcs      Exit                branch if error
                    pshs      x                   save pointer past device name
                    inca                          A = 1
                    os9       I$Close             close stdout
                    inca                          A = 2
                    os9       I$Close             close stderr
                    clra                          stdin path
                    os9       I$Dup               dup to stdout
                    lbcs      Exit                branch if error
                    os9       I$Dup               dup to stderr
                    lbcs      Exit                branch if error
                    puls      x                   restore pointer past device name
* Skip spaces after device name to find optional command
skipsp@             lda       ,x+
                    cmpa      #C$SPAC
                    beq       skipsp@
                    cmpa      #C$CR
                    beq       L0052
                    tsta
                    beq       L0052
                    leax      -1,x                point to start of command
                    stx       <cmdptr
* Scan to end of command name
findsp@             lda       ,x+
                    cmpa      #C$CR
                    beq       noprm@
                    tsta
                    beq       noprm@
                    cmpa      #C$SPAC
                    bne       findsp@
* Scan past spaces to start of parameters
skpprm@             lda       ,x
                    cmpa      #C$SPAC
                    bne       gotprm@
                    leax      1,x
                    bra       skpprm@
gotprm@             stx       <cmdprm
                    bra       L0052
noprm@              leax      <LoginPrm,pcr
                    stx       <cmdprm
L0052               clra                          stdin
                    leax      inbuff,u            point to buffer
                    ldy       #$0001              read 1 byte
                    os9       I$ReadLn            read line
                    lbcs      L0024               branch if error
                    clrb                          no additional mem
                    pshs      u                   preserve tsmon data pointer
                    ldx       <cmdptr             point to command
                    ldu       <cmdprm             and to parameters
                    ldy       #$0000              calculate parameter length
prmlen@             lda       ,u+
                    leay      1,y
                    cmpa      #C$CR
                    bne       prmlen@
                    ldu       <cmdprm             restore parameter pointer
                    lda       #Objct              object, set after the length scan which uses a
                    os9       F$Fork              fork program
                    puls      u                   restore tsmon data pointer
                    lbcs      L0024               branch if error
                    sta       <childid            else save process ID of child
L0072               os9       F$Wait              wait for it to finish
                    cmpa      <childid            same as PID we forked?
                    bne       L0072               if not, wait more
                    lbra      L0024               else go back
Exit                os9       F$Exit              exit

                    emod
eom                 equ       *
                    end
