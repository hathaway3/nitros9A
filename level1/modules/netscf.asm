********************************************************************
* netscf - Multiplexed Wi-Fi Virtual Serial SCF Driver
* For RPI-Nine Pico 2W Virtual Hardware
*
* Edition: 1
********************************************************************
                    nam       netscf
                    ttl       Wi-Fi Virtual Serial SCF Driver

                    ifp1
                    use       defsfile
                    endc

rev                 set       0
edition             set       1

                    ifndef    VPORT_BASE
VPORT_BASE          equ       $FF70
                    endif

* Hardware Register Offsets (relative to VPORT_BASE)
VNET.SEL            equ       $00                 Port Select (W) / IRQ Pending (R)
VNET.STAT           equ       $01                 Port Status
VNET.DATA           equ       $02                 16-bit Data Port ($FF72-$FF73)

* Status Register Bit Masks
Stat.RxRdy          equ       %00000001           RX FIFO has >= 1 byte
Stat.RxW2           equ       %00000010           RX FIFO has >= 2 bytes (LDD ready)
Stat.TxRdy          equ       %00000100           TX FIFO has >= 1 byte space
Stat.TxW2           equ       %00001000           TX FIFO has >= 2 byte space (STD ready)
Stat.Ovr            equ       %00100000           RX Overrun error
Stat.CD             equ       %01000000           Carrier Detect (client connected)
Stat.IRQ            equ       %10000000           IRQ pending for this port

* Static Data Storage Offsets (allocated by OS-9 per device instance)
                    org       V.SCF
V.PortID            rmb       1                   Virtual Port Index (0-3)
V.HWAddr            rmb       2                   Base hardware address (VPORT_BASE)
V.SigPID            rmb       1                   Process ID for SS.SSig
V.SigCode           rmb       1                   Signal code for SS.SSig
V.CDPID             rmb       1                   Process ID for CD change signal
V.CDSig             rmb       1                   CD signal code
MemSize             equ       .

                    mod       ModSize,ModName,Drivr+Objct,ReEnt+rev,ModEntry,MemSize
                    fcb       UPDAT.              Access mode

ModName             fcs       /netscf/
                    fcb       edition

* IRQ Polling Packet
IRQPckt             equ       *
Pkt.Flip            fcb       $00                 Active high status bits
Pkt.Mask            fcb       Stat.IRQ            Mask for IRQ pending
                    fcb       $0A                 Priority (10)

* Module Jump Table
ModEntry            lbra      Init
                    bra       Read
                    nop
                    bra       Write
                    nop
                    lbra      GetStat
                    lbra      SetStat
                    lbra      Term

********************************************************************
* Init - Initialize Device Instance
* Entry: Y = Address of device descriptor
*        U = Address of device static memory
********************************************************************
Init                pshs      cc,dp
                    orcc      #IntMasks           Mask interrupts

* Store base hardware address
                    ldd       <V.PORT,u           Base address from descriptor
                    anda      #$FF
                    andb      #$F0                Round down to base register window
                    std       <V.HWAddr,u

* Extract Port ID from lower nibble of V.PORT
                    ldb       <V.PORT+1,u
                    andb      #$03                Port 0-3
                    stb       <V.PortID,u

* Register interrupt handler with OS-9 kernel
* D = hardware status register address (VPORT_BASE + 1)
                    ldd       <V.HWAddr,u
                    addb      #VNET.STAT
                    leax      IRQPckt,pc
                    leay      IRQSvc,pc
                    os9       F$IRQ
                    bcs       InitErr

* Clear signals and return
                    clr       <V.SigPID,u
                    clr       <V.CDPID,u
                    clrb
                    puls      cc,dp,pc

InitErr             puls      cc,dp,pc

********************************************************************
* Read - Read One Character from Virtual Port
* Entry: Y = Path descriptor pointer
*        U = Device memory pointer
* Exit:  A = Character read
*        CC = Carry set on error (B = error code)
********************************************************************
Read                ldx       <V.HWAddr,u
                    ldb       <V.PortID,u

ReadPoll            orcc      #IntMasks
                    stb       VNET.SEL,x          Select this port
                    lda       VNET.STAT,x         Read port status
                    bita      #Stat.RxRdy         Is data ready?
                    bne       ReadChar            Yes, go grab it

* No data ready: sleep waiting for IRQ
                    lda       P$ID,pcr            Get current Process ID
                    sta       <V.WAKE,u           Register for wakeup
                    andcc     #^IntMasks          Unmask interrupts
                    ldx       #0                  Sleep until signal/wake
                    os9       F$Sleep
                    ldx       <V.HWAddr,u
                    ldb       <V.PortID,u
                    bra       ReadPoll

ReadChar            lda       VNET.DATA,x         Pop character from FIFO
                    clr       <V.WAKE,u           Clear wakeup flag
                    andcc     #^IntMasks          Restore interrupts
                    clrb
                    rts

********************************************************************
* Write - Write One Character to Virtual Port
* Entry: A = Character to write
*        U = Device memory pointer
********************************************************************
Write               pshs      a
                    ldx       <V.HWAddr,u
                    ldb       <V.PortID,u

WriteWait           stb       VNET.SEL,x          Select this port
                    lda       VNET.STAT,x         Check TX status
                    bita      #Stat.TxRdy         Can we send?
                    bne       WriteOut

* TX FIFO is full: yield CPU for a tick
                    pshs      x,b
                    ldx       #1
                    os9       F$Sleep
                    puls      x,b
                    bra       WriteWait

WriteOut            puls      a
                    sta       VNET.DATA,x         Push character into TX FIFO
                    clrb
                    rts

********************************************************************
* IRQSvc - Interrupt Service Routine
* Called by OS-9 kernel when an interrupt occurs
********************************************************************
IRQSvc              ldx       <V.HWAddr,u
                    ldb       <V.PortID,u
                    stb       VNET.SEL,x          Select this port
                    lda       VNET.STAT,x
                    bita      #Stat.IRQ           Did our port trigger it?
                    beq       IRQNotOurs

* Check if a process registered for SS.SSig
                    lda       <V.SigPID,u
                    beq       ChkSleep
                    ldb       <V.SigCode,u
                    clr       <V.SigPID,u         One-shot signal
                    os9       F$Send

ChkSleep            lda       <V.WAKE,u
                    beq       IRQDone
                    clr       <V.WAKE,u
                    ldb       #S$Wake             Wakeup signal
                    os9       F$Send              Wake up sleeping reader

IRQDone             clrb
                    rts

IRQNotOurs          orcc      #Carry              Carry set = not our interrupt
                    rts

********************************************************************
* GetStat - Get Device Status
********************************************************************
GetStat             cmpb      #SS.Ready           Is data ready?
                    bne       GetStatCD
                    ldx       <V.HWAddr,u
                    ldb       <V.PortID,u
                    stb       VNET.SEL,x
                    lda       VNET.STAT,x
                    bita      #Stat.RxRdy
                    bne       GS.Ok
                    comb                          Carry set = not ready
                    ldb       #E$NotRdy
                    rts
GS.Ok               clrb
                    rts

GetStatCD           cmpb      #SS.CDSta           Carrier Detect status?
                    bne       GetStatPass
                    ldx       <V.HWAddr,u
                    ldb       <V.PortID,u
                    stb       VNET.SEL,x
                    lda       VNET.STAT,x
                    bita      #Stat.CD
                    bne       GS.CDOn
                    clra                          Carrier down
                    rts
GS.CDOn             lda       #1                  Carrier up
                    clrb
                    rts

GetStatPass         clrb
                    rts

********************************************************************
* SetStat - Set Device Status
********************************************************************
SetStat             cmpb      #SS.SSig            Set process signal on RX
                    bne       SetStatOther
                    lda       R$X,u               Calling Process ID
                    sta       <V.SigPID,u
                    lda       R$Y,u               Signal code
                    sta       <V.SigCode,u
                    clrb
                    rts

SetStatOther        clrb
                    rts

********************************************************************
* Term - Terminate Device
********************************************************************
Term                ldd       <V.HWAddr,u
                    addb      #VNET.STAT
                    leax      IRQPckt,pc
                    ldy       #0                  Remove IRQ handler
                    os9       F$IRQ
                    clrb
                    rts

                    emod
ModSize             equ       *
                    end
