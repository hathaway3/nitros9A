********************************************************************
* term_net - Wi-Fi Virtual Terminal Device Descriptor Template
* Supports /N0, /N1, /N2, /N3 (configured via PORT_NUM)
*
* IT.RPR and IT.DUP use the window descriptors' values (w.asm,
* term_win80.asm), not the serial defaults. SCF turns on its enhanced
* line editor whenever IT.RPR is not C$RPRT (Ctrl-D); the reprint
* character then moves the cursor right one character, so right arrow
* walks across a Shell+ history line the same as on the windowed
* console, and Ctrl-P/Ctrl-Q/Ctrl-S delete, insert and print the rest
* of the line. Ctrl-D and Ctrl-A are ordinary characters in this mode.
* "tmode rpr=04 dup=01" switches a path back to classic SCF input.
* See RPI-Nine docs/TELNET_TERMINALS.md.
********************************************************************
                    nam       term_net
                    ttl       Wi-Fi Virtual Terminal Device Descriptor

                    ifp1
                    use       defsfile
                    endc

tylg                set       Devic+Objct
atrv                set       ReEnt+rev
rev                 set       $00

                    ifndef    PORT_NUM
PORT_NUM            equ       0
                    endif

                    ifndef    VPORT_BASE
VPORT_BASE          equ       $FF70
                    endif

HwBASE              equ       VPORT_BASE + PORT_NUM

                    mod       eom,name,tylg,atrv,mgrnam,drvnam

                    fcb       UPDAT.              Mode byte (read/write)
                    fcb       HW.Page             Extended controller address (0)
                    fdb       HwBASE              Physical controller base address

                    fcb       initsize-*-1        Initialization table size
                    fcb       DT.SCF              IT.DVC device type: SCF
                    fcb       $00                 IT.UPC uppercase flag: 0=upper & lower
                    fcb       $01                 IT.BSO backspace behavior: 1=bsp then sp & bsp
                    fcb       $00                 IT.DLO delete line: 0=backspace over line
                    fcb       $01                 IT.EKO echo flag: 1=echo on
                    fcb       $01                 IT.ALF auto line feed: 1=auto LF on
                    fcb       $00                 IT.NUL end of line null count
                    fcb       $00                 IT.PAU pause flag: 0=no end of page pause
                    fcb       24                  IT.PAG lines per page (standard VT-100)
                    fcb       C$BSP               IT.BSP backspace character ($08)
                    fcb       C$DEL               IT.DEL delete line character ($18)
                    fcb       C$CR                IT.EOR end of record character ($0D)
                    fcb       C$EOF               IT.EOF end of file character ($1B)
                    fcb       C$RARR              IT.RPR reprint/cursor right character ($09 right arrow, enables the line editor)
                    fcb       C$SHRARR            IT.DUP duplicate rest of line character ($19 shift right arrow)
                    fcb       C$PAUS              IT.PSC pause character ($17)
                    fcb       C$INTR              IT.INT interrupt character ($03 / Ctrl-C)
                    fcb       C$QUIT              IT.QUT quit character ($05 / Ctrl-E)
                    fcb       C$BSP               IT.BSE backspace echo character ($08)
                    fcb       C$BELL              IT.OVF line overflow character ($07)
                    fcb       PARNONE             IT.PAR parity: none
                    fcb       STOP1+WORD8+B115200 IT.BAU baud rate
                    fdb       name                IT.D2P copy of descriptor name address
                    fcb       C$XON               IT.XON xon char ($11)
                    fcb       C$XOFF              IT.XOFF xoff char ($13)
                    fcb       80                  IT.COL number of columns (standard 80 col)
                    fcb       24                  IT.ROW number of rows (standard 24 row)
                    fcb       $00                 IT.XTYP extended type
initsize            equ       *

                    ifeq      PORT_NUM
name                fcs       /N0/
                    endif
                    ifeq      PORT_NUM-1
name                fcs       /N1/
                    endif
                    ifeq      PORT_NUM-2
name                fcs       /N2/
                    endif
                    ifeq      PORT_NUM-3
name                fcs       /N3/
                    endif

mgrnam              fcs       /SCF/
drvnam              fcs       /netscf/

                    emod
eom                 equ       *
                    end
