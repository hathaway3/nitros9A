********************************************************************
* netscf - Multiplexed Wi-Fi Virtual Serial SCF Driver
* For RPI-Nine Pico 2W Virtual Hardware
*
* Edition: 4
*
* Edt/Rev  Comment
* ------------------------------------------------------------------
*   3      Received bytes are drained into a driver buffer by the IRQ
*          service routine, which checks each one against the path's
*          interrupt, quit and pause characters (V.INTR/V.QUIT/V.PCHR)
*          the way vtio and sc6850 do, so Ctrl-C and BREAK send
*          S$Intrpt/S$Abort to the last process that used the port
*          even while it is busy and not reading
*   4      GetStat answers SS.ScSiz from the descriptor's IT.COL/IT.ROW and
*          returns E$UnkSvc for calls it does not support, as sc6850 does
********************************************************************
                    nam       netscf
                    ttl       Wi-Fi Virtual Serial SCF Driver

                    ifp1
                    use       defsfile
                    endc

rev                 set       0
edition             set       4

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

* receive buffer size: a power of two no larger than 128, so the get and
* put offsets wrap with a single and and stay positive as 8-bit indexes
RxBufSz             equ       128

* Static Data Storage Offsets (allocated by OS-9 per device instance)
                    org       V.SCF
V.PortID            rmb       1                   Virtual Port Index (0-3)
V.HWAddr            rmb       2                   Base hardware address (VPORT_BASE)
V.SigPID            rmb       1                   Process ID for SS.SSig (must precede V.SigCode)
V.SigCode           rmb       1                   Signal code for SS.SSig (must follow V.SigPID)
V.CDPID             rmb       1                   Process ID for CD change signal
V.CDSig             rmb       1                   CD signal code
V.IRQPkt            equ       .                   Dynamic IRQ Polling Packet
V.Flip              rmb       1                   Flip byte (0 = active high)
V.Mask              rmb       1                   Mask byte (1 << PortID on VNET.SEL)
V.Prty              rmb       1                   Priority byte (10)
V.RxPut             rmb       1                   offset where the next received byte is stored
V.RxGet             rmb       1                   offset of the next byte read returns
V.RxCnt             rmb       1                   number of bytes waiting in the receive buffer
V.RxBuf             rmb       RxBufSz             receive buffer filled by the irq service routine
MemSize             equ       .

                    mod       ModSize,ModName,Drivr+Objct,ReEnt+rev,ModEntry,MemSize
                    fcb       UPDAT.              Access mode

ModName             fcs       /netscf/
                    fcb       edition

* Module Jump Table
ModEntry            lbra      Init
                    lbra      Read
                    lbra      Write
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

* Store base hardware address ($FF70)
                    ldd       <V.PORT,u           Base address from descriptor
                    anda      #$FF
                    andb      #$F0                Round down to base register window ($FF70)
                    std       <V.HWAddr,u

* Extract Port ID from lower nibble of V.PORT
                    ldb       <V.PORT+1,u
                    andb      #$03                Port 0-3
                    stb       <V.PortID,u

* Setup IRQ Polling Packet in device static storage
* Offset 0 ($FF70) returns IRQ pending bitmask (1 << PortID)
                    clr       <V.Flip,u
                    lda       #$0A
                    sta       <V.Prty,u
                    ldb       <V.PortID,u
                    lda       #1
MaskLp              tstb
                    beq       MaskDone
                    asla
                    decb
                    bra       MaskLp
MaskDone            sta       <V.Mask,u

* start with an empty receive buffer
                    clr       <V.RxPut,u          store the first byte at the start of the buffer
                    clr       <V.RxGet,u          read the first byte from the start of the buffer
                    clr       <V.RxCnt,u          nothing has been received yet

* Register interrupt handler with OS-9 kernel
* D = hardware polling register address (VPORT_BASE, $FF70)
* X = address of IRQ packet
* Y = address of IRQ service routine
                    ldd       <V.HWAddr,u
                    leax      <V.IRQPkt,u
                    leay      IRQSvc,pc
                    os9       F$IRQ
                    bcs       InitErr

* Clear signals and return
                    clr       <V.SigPID,u
                    clr       <V.CDPID,u
                    clr       <V.WAKE,u
                    clrb
                    puls      cc,dp,pc

InitErr             puls      cc,dp
                    coma                          Set Carry flag on error
                    rts

********************************************************************
* Read - Read One Character from Virtual Port
* Entry: Y = Path descriptor pointer
*        U = Device memory pointer
* Exit:  A = Character read
*        CC = Carry set on error (B = error code)
********************************************************************
Read                orcc      #IntMasks           keep the irq service routine out of the buffer
                    ldb       <V.RxCnt,u          any bytes waiting?
                    beq       ReadSlp             no, wait for the irq service routine to store one
                    decb                          account for the byte about to be taken
                    stb       <V.RxCnt,u          save the new waiting count
                    leax      <V.RxBuf,u          point to the receive buffer
                    ldb       <V.RxGet,u          get the offset of the oldest byte
                    lda       b,x                 get the oldest byte
                    incb                          move past it
                    andb      #RxBufSz-1          wrap at the end of the buffer
                    stb       <V.RxGet,u          save the new read offset
                    clrb                          no error and clear carry
                    andcc     #^IntMasks          let interrupts back in
                    rts                           return with the byte in a

* nothing buffered: sleep until the irq service routine stores a byte and
* wakes us, the same way vtio waits for a key
ReadSlp             lda       <V.BUSY,u           get the process reading this port
                    sta       <V.WAKE,u           ask the irq service routine to wake it
                    andcc     #^IntMasks          let interrupts back in
                    ldx       #1                  sleep for at most one tick in case the wakeup is missed
                    os9       F$Sleep
                    clr       <V.WAKE,u           no longer waiting to be woken
                    ldx       >D.Proc             get the current process descriptor
                    ldb       P$Signal,x          is a signal pending?
                    beq       Read                no, go look for data again
                    cmpb      #S$Wake             only the wakeup from the irq service routine?
                    beq       Read                yes, go look for data again
                    lda       P$State,x           get the process state
                    bita      #Condem             is the process being killed?
                    bne       ReadErr             yes, return with the signal as the error
                    cmpb      #S$Window           window change or user defined signal?
                    bhs       Read                yes, it does not end the read so keep waiting
ReadErr             coma                          keyboard abort or interrupt: return error b to scf
                    rts

********************************************************************
* Write - Write One Character to Virtual Port
* Entry: A = Character to write
*        U = Device memory pointer
********************************************************************
Write               pshs      a
                    ldx       <V.HWAddr,u
                    ldb       <V.PortID,u

WriteWait           orcc      #IntMasks
                    stb       VNET.SEL,x          Select this port
                    lda       VNET.STAT,x         Check TX status
                    bita      #Stat.TxRdy         Can we send?
                    bne       WriteOut

* TX FIFO is full: yield CPU for a tick
                    andcc     #^IntMasks
                    pshs      x,b
                    ldx       #1
                    os9       F$Sleep
                    puls      x,b
                    bra       WriteWait

WriteOut            puls      a
                    sta       VNET.DATA,x         Push character into TX FIFO
                    andcc     #^IntMasks
                    clrb
                    rts

********************************************************************
* IRQSvc - Interrupt Service Routine
* Called by OS-9 kernel when an interrupt occurs
* Entry: U = Device memory pointer
********************************************************************
IRQSvc              ldx       <V.HWAddr,u
                    ldb       <V.PortID,u
                    stb       VNET.SEL,x          Select this port
                    lda       VNET.STAT,x
                    bita      #Stat.IRQ           Did our port trigger it?
                    beq       IRQNotOurs
                    lda       #Stat.IRQ
                    sta       VNET.STAT,x         Acknowledge and deassert hardware IRQ

* drain everything the port has received into the driver buffer; the
* hardware fifo is bounded and only refilled between cpu batches, so this
* loop always ends
IRQRxLp             ldb       <V.PortID,u         get our port number
                    stb       VNET.SEL,x          reselect our port in case a signal handler changed it
                    lda       VNET.STAT,x         get the port status
                    bita      #Stat.RxRdy         another byte waiting?
                    beq       IRQWake             no, go wake the reader
                    lda       VNET.DATA,x         take the byte from the hardware fifo
                    pshs      x                   keep the hardware address across the checks
                    bsr       RxChar              check for special keys and buffer the byte
                    puls      x                   recover the hardware address
                    bra       IRQRxLp             go look for another byte

* Check if a process registered for SS.SSig
IRQWake             lda       <V.RxCnt,u          did anything get buffered?
                    beq       IRQDone             no, nobody needs waking
                    lda       <V.SigPID,u
                    beq       ChkSleep
                    ldb       <V.SigCode,u
                    clr       <V.SigPID,u         One-shot signal
                    os9       F$Send

ChkSleep            lda       <V.WAKE,u           Is someone sleeping?
                    beq       IRQDone             No
                    clr       <V.WAKE,u           only wake the reader once
                    ldb       #S$Wake             wake it so it reads the new data
                    os9       F$Send

IRQDone             clrb                          Carry clear = our interrupt handled
                    rts

IRQNotOurs          orcc      #Carry              Carry set = not our interrupt
                    rts

* RxChar - handle one received byte the way vtio handles a key
* Entry: A = byte received
*        U = Device memory pointer
RxChar              tsta                          a null byte?
                    beq       RxStore             yes, it can not be a special key
                    ldb       #S$Intrpt           assume the interrupt key
                    cmpa      <V.INTR,u           is it the interrupt key (ctrl-c)?
                    beq       RxSig               yes, signal the last process
                    decb                          now assume the quit key (s$abort)
                    cmpa      <V.QUIT,u           is it the quit key (break)?
                    beq       RxSig               yes, signal the last process
                    cmpa      <V.PCHR,u           is it the pause key?
                    bne       RxStore             no, just buffer it
                    ldx       <V.DEV2,u           is there an attached output device?
                    beq       RxStore             no, just buffer it
                    sta       <V.PAUS,x           ask the output device to pause
                    bra       RxStore             and buffer the key too

RxSig               pshs      a                   keep the key to buffer it afterwards
                    lda       <V.LPRC,u           get the last process to use the port
                    beq       RxSigDn             nobody to signal
                    os9       F$Send              send it the keyboard signal
RxSigDn             puls      a                   recover the key

* keys that sent a signal are still buffered, as vtio and sc6850 do
RxStore             ldb       <V.RxCnt,u          how full is the buffer?
                    cmpb      #RxBufSz            no room left?
                    bhs       RxDrop              yes, drop the byte rather than block the port
                    inc       <V.RxCnt,u          count the new byte
                    leax      <V.RxBuf,u          point to the receive buffer
                    ldb       <V.RxPut,u          get the offset for the new byte
                    sta       b,x                 store the byte
                    incb                          move to the next slot
                    andb      #RxBufSz-1          wrap at the end of the buffer
                    stb       <V.RxPut,u          save the new store offset
RxDrop              rts

********************************************************************
* GetStat - Get Device Status
* Entry: A = Status call function code
*        Y = Path descriptor pointer
*        U = Device memory pointer
********************************************************************
GetStat             cmpa      #SS.EOF             End of file?
                    beq       GS.Ok               SCF never returns EOF
                    cmpa      #SS.Ready           Is data ready?
                    bne       GetStatSz
                    ldb       <V.RxCnt,u          how many bytes are waiting?
                    beq       GS.NRdy             none, not ready
                    ldx       PD.RGS,y            point to the caller's registers
                    stb       R$B,x               return the waiting count in the caller's b
GS.Ok               clrb
                    rts
GS.NRdy             comb                          Carry set = not ready
                    ldb       #E$NotRdy
                    rts

* screen size comes from the descriptor (IT.COL/IT.ROW), as sc6850 does;
* without it mdir laid out its columns from whatever was left in x
GetStatSz           cmpa      #SS.ScSiz           Screen size?
                    bne       GetStatCD           no, check carrier detect
                    ldx       PD.RGS,y            point to the caller's registers
                    ldu       PD.DEV,y            get the device table entry
                    ldu       V$DESC,u            get the device descriptor
                    clra                          sizes are one byte
                    ldb       IT.COL,u            get the number of columns
                    std       R$X,x               return them in the caller's x
                    ldb       IT.ROW,u            get the number of rows
                    std       R$Y,x               return them in the caller's y
                    clrb                          no error
                    rts

GetStatCD           cmpa      #SS.CDSta           Carrier Detect status?
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

* anything else is unsupported: say so instead of returning success with
* the caller's registers untouched, as sc6850 does
GetStatPass         comb                          set carry for the error
                    ldb       #E$UnkSvc           unknown service request
                    rts

********************************************************************
* SetStat - Set Device Status
* Entry: A = Status call function code
*        Y = Path descriptor pointer
*        U = Device memory pointer
********************************************************************
SetStat             cmpa      #SS.SSig            Set process signal on RX
                    bne       SetStatRel
                    ldx       PD.RGS,y            Caller's register stack
                    lda       PD.CPR,y            Calling Process ID
                    ldb       R$X+1,x             Signal code from caller's X (LSB)
                    orcc      #IntMasks           keep the irq service routine out while deciding
                    tst       <V.RxCnt,u          is data already waiting?
                    bne       SSigNow             yes, signal right away
                    std       <V.SigPID,u         no, have the irq service routine signal later
                    andcc     #^IntMasks          let interrupts back in
                    clrb
                    rts
SSigNow             andcc     #^IntMasks          let interrupts back in
                    os9       F$Send              signal the caller now
                    clrb
                    rts

SetStatRel          cmpa      #SS.Relea           Release the data ready signal?
                    bne       SetStatOther
                    lda       PD.CPR,y            get the releasing process
                    cmpa      <V.SigPID,u         is it the one waiting for a signal?
                    bne       SetStatOther        no, leave it alone
                    clr       <V.SigPID,u         yes, forget the signal request

SetStatOther        clrb
                    rts

********************************************************************
* Term - Terminate Device
* Entry: U = Device memory pointer
********************************************************************
Term                ldd       <V.HWAddr,u         $FF70
                    ldx       #0                  Remove IRQ handler (X=0)
                    leay      IRQSvc,pc
                    os9       F$IRQ
                    clrb
                    rts

                    emod
ModSize             equ       *
                    end

