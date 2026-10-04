********************************************************************
* CPUSpeed - Benchmark CPU performance under NitrOS-9
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   1      2026/10/03  Jim Hathaway
* Started. Synchronizes to 60 Hz clock and benchmarks CPU performance.

                    nam       CPUSpeed
                    ttl       CPU Speed Benchmark for NitrOS-9

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+Rev
rev                 set       $00
edition             set       1

                    org       0
time_buf            rmb       6                   ; F$Time buffer (yr, mo, day, hr, min, sec)
start_sec           rmb       1
end_sec             rmb       1
batch_count         rmb       2                   ; 16-bit batch counter
out_buf             rmb       16                  ; Output buffer for formatted numbers
                    rmb       200                 ; Stack space
size                equ       .

                    mod       eom,name,tylg,atrv,start,size

name                fcs       /cpuspeed/
                    fcb       edition

banner_msg          fcc       /NitrOS-9 CPU Speed Benchmark/
                    fcb       C$CR

coco_msg            fcc       /Real CoCo 3 Fast Mode reference : 1.79 MHz/
                    fcb       C$CR

measuring_msg       fcc       /Benchmarking CPU over 3 seconds.../
                    fcb       C$CR

cpu6809_str         fcc       /CPU Detected : Motorola 6809/
                    fcb       C$CR

cpu6309_str         fcc       /CPU Detected : Hitachi 6309/
                    fcb       C$CR

res_hdr             fcc       /Measured Effective Clock Speed  : /
res_hdr_len         equ       *-res_hdr

mhz_str             fcc       / MHz/
                    fcb       C$CR

rel_hdr             fcc       /Performance vs Real CoCo 3 (1.79M): /
rel_hdr_len         equ       *-rel_hdr

times_str           fcc       /x real CoCo 3/
                    fcb       C$CR

help_msg            fcc       /Syntax: cpuspeed/
                    fcb       C$CR
                    fcc       /Usage : Benchmark CPU performance and effective clock speed/
                    fcb       C$CR
help_len            equ       *-help_msg

start
* Check for help request ('?') in arguments
                    cmpd      #0
                    beq       run_bench
skip_sp             lda       ,x+
                    cmpa      #' '
                    beq       skip_sp
                    cmpa      #C$CR
                    beq       run_bench
                    cmpa      #'?
                    beq       show_help
                    cmpa      #'-
                    bne       run_bench
                    lda       ,x
                    cmpa      #'?
                    beq       show_help
                    bra       run_bench
show_help           leax      help_msg,pcr
                    ldy       #help_len
                    lda       #1
                    os9       I$WritLn
                    clrb
                    os9       F$Exit

run_bench
* 1. Detect CPU type (6809 vs 6309)
                    ldd       #$FFFF
                    fdb       $104F               ; CLRD on 6309; CLRA ($10 prefix + $4F) on 6809 leaving B=$FF
                    tstb
                    bne       is_6809
                    leax      cpu6309_str,pcr
                    bra       pr_cpu
is_6809             leax      cpu6809_str,pcr
pr_cpu              ldy       #80
                    lda       #1
                    os9       I$WritLn

                    leax      banner_msg,pcr
                    ldy       #80
                    lda       #1
                    os9       I$WritLn

                    leax      coco_msg,pcr
                    ldy       #80
                    lda       #1
                    os9       I$WritLn

                    leax      measuring_msg,pcr
                    ldy       #80
                    lda       #1
                    os9       I$WritLn

* 2. Synchronize to second rollover
                    leax      time_buf,u
                    os9       F$Time
                    lda       5,x                 ; current second (0..59)
sync_wait
                    os9       F$Time
                    cmpa      5,x
                    beq       sync_wait           ; wait for second to tick

* Now we are exactly at the start of a second!
                    lda       5,x
                    sta       start_sec,u
                    adda      #3                  ; sample for 3 seconds
                    cmpa      #60
                    bcs       sec_ok
                    suba      #60
sec_ok              sta       end_sec,u

                    clra
                    clrb
                    std       batch_count,u

* 3. Calibrated benchmark loop:
* Inner loop: 5000 iterations * 20 cycles = 100,000 cycles per batch
bench_loop
                    ldx       #5000
inner_loop
                    nop                           ; 2
                    nop                           ; 2
                    nop                           ; 2
                    nop                           ; 2
                    nop                           ; 2
                    nop                           ; 2
                    leax      -1,x                ; 5
                    bne       inner_loop          ; 3 (2 on exit)
* ~20 cycles * 5000 = ~100,000 cycles

                    ldd       batch_count,u
                    addd      #1
                    std       batch_count,u

                    leax      time_buf,u
                    os9       F$Time
                    lda       5,x
                    cmpa      end_sec,u
                    bne       bench_loop

* 4. 3 seconds finished! Calculate MHz:
* Each batch = 100,000 cycles.
* In 3 seconds, Cycles/sec = (Batches * 100,000) / 3
* MHz = Batches / 30.0

* Print "Measured Effective Clock Speed  : "
                    leax      res_hdr,pcr
                    ldy       #res_hdr_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    pshs      y                   ; remember buffer start
                    ldx       batch_count,u
* X = Batches
                    lbsr      div_x_30            ; A = quotient (MHz), X = remainder
                    lbsr      put_int
                    lda       #'.
                    sta       ,y+

* Remainder in X (0..29). Multiply by 10:
                    tfr       x,d                 ; D = remainder
                    lda       #10
                    mul                           ; D = remainder * 10 (0..290)
                    tfr       d,x
                    lbsr      div_x_30            ; A = first decimal digit, X = remainder
                    adda      #'0
                    sta       ,y+

                    tfr       x,d
                    lda       #10
                    mul
                    tfr       d,x
                    lbsr      div_x_30            ; A = second decimal digit
                    adda      #'0
                    sta       ,y+

* Write out the measured string
                    tfr       y,d
                    subd      ,s+                 ; D = length
                    tfr       d,y
                    leax      out_buf,u
                    lda       #1
                    os9       I$Write

                    leax      mhz_str,pcr
                    ldy       #80
                    lda       #1
                    os9       I$WritLn

* 5. Calculate ratio vs Real CoCo 3 Fast Mode (1.78977 MHz):
* At 1.78977 MHz in 3.0 sec, a real CoCo 3 does 53.69 batches (~54).
* Ratio = Batches / 54
                    leax      rel_hdr,pcr
                    ldy       #rel_hdr_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    pshs      y                   ; remember buffer start
                    ldx       batch_count,u
                    lbsr      div_x_54            ; A = quotient, X = remainder
                    lbsr      put_int
                    lda       #'.
                    sta       ,y+

                    tfr       x,d
                    lda       #10
                    mul
                    tfr       d,x
                    lbsr      div_x_54
                    adda      #'0
                    sta       ,y+

                    tfr       x,d
                    lda       #10
                    mul
                    tfr       d,x
                    lbsr      div_x_54
                    adda      #'0
                    sta       ,y+

                    tfr       y,d
                    subd      ,s+                 ; D = length
                    tfr       d,y
                    leax      out_buf,u
                    lda       #1
                    os9       I$Write

                    leax      times_str,pcr
                    ldy       #80
                    lda       #1
                    os9       I$WritLn

                    clrb
                    os9       F$Exit

* Helper: Write integer part in A (0..255) to ,y+
put_int
                    cmpa      #10
                    bcs       put_1dig
                    cmpa      #100
                    bcs       put_2dig
* 3 digits (100..255)
                    ldb       #'0
div100              cmpa      #100
                    bcs       div100_done
                    suba      #100
                    incb
                    bra       div100
div100_done         stb       ,y+
put_2dig            ldb       #'0
div10               cmpa      #10
                    bcs       div10_done
                    suba      #10
                    incb
                    bra       div10
div10_done          stb       ,y+
put_1dig            adda      #'0
                    sta       ,y+
                    rts

* Helper: Divide X (0..2000) by 30
* Entry: X = dividend
* Exit:  A = quotient, X = remainder
div_x_30
                    clra
div_30_lp           cmpx      #30
                    bcs       div_30_done
                    leax      -30,x
                    inca
                    bra       div_30_lp
div_30_done         rts

* Helper: Divide X (0..2000) by 54
* Entry: X = dividend
* Exit:  A = quotient, X = remainder
div_x_54
                    clra
div_54_lp           cmpx      #54
                    bcs       div_54_done
                    leax      -54,x
                    inca
                    bra       div_54_lp
div_54_done         rts

                    emod
eom                 equ       *
                    end
