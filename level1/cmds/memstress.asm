********************************************************************
* memstress - NitrOS-9 MMU Memory Stress & Swapping Benchmark
*
* Evaluates memory bandwidth, bank-switching overhead, and RAM
* compression performance across physical 8KB MMU blocks in NitrOS-9 Level 2.
*
* 1. Dynamically allocates physical 8K RAM blocks via F$AllRAM
* 2. Calibrates baseline unswapped speed (within hot pool)
* 3. Scans block counts (4..N) to detect the zero-penalty hot-pool capacity
* 4. Benchmarks full sequential sweep (worst-case LRU cache thrashing)
* 5. Benchmarks full random sweep (coprime permutation hit/miss profile)
* 6. Verifies data integrity across all blocks post-swapping
* 7. Safely deallocates all blocks via F$DelRAM before exit
********************************************************************

                    nam       memstress
                    ttl       NitrOS-9 MMU Memory Stress & Swapping Benchmark

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+Rev
rev                 set       $00
edition             set       1

MAX_BLKS            equ       48                  ; Max physical 8K blocks in block_pool ($00-$2F)
MIN_BLKS            equ       4                   ; Minimum blocks needed for benchmark
BASE_BLKS           equ       8                   ; Default unswapped baseline block count

                    org       0
data_base           rmb       2                   ; Pointer to start of data area (for signal handler)
time_buf            rmb       6                   ; F$Time buffer (yr, mo, day, hr, min, sec)
start_sec           rmb       1                   ; Starting second
last_sec            rmb       1                   ; Last second polled
duration_sec        rmb       1                   ; Interval length (1s or 2s)
quick_mode          rmb       1                   ; 0 = normal (2s), 1 = quick (1s)
req_blks            rmb       1                   ; User-specified block count (0 = max available)
blkcnt              rmb       1                   ; Actual physical blocks allocated
mapped_addr         rmb       2                   ; Logical address returned by F$MapBlk
baseline_swaps      rmb       2                   ; Baseline swaps/sec (at 8 blocks)
seq_swaps           rmb       2                   ; Sequential swaps/sec (all blocks)
rnd_swaps           rmb       2                   ; Random swaps/sec (all blocks)
hot_pool_size       rmb       1                   ; Detected zero-penalty capacity
swap_onset          rmb       1                   ; Detected first block count with swapping penalty
integrity_errors    rmb       2                   ; Corruption count
bad_block           rmb       1                   ; First failing block number
div_cnt             rmb       1                   ; 32/16 div loop counter
divisor             rmb       2                   ; 32/16 divisor
cur_step_blks       rmb       1                   ; Current block count being tested
step_swaps          rmb       2                   ; Current step swaps/sec
step_pct            rmb       1                   ; Current step percentage of baseline
pass_seed           rmb       2                   ; Test pattern seed
is_6309             rmb       1                   ; 0 = 6809, 1 = 6309
swap_count          rmb       2                   ; Loop swap counter
inner_cnt           rmb       1                   ; Batch counter between time checks
rnd_step            rmb       1                   ; Coprime step for random sweep
blktbl              rmb       MAX_BLKS            ; Physical block numbers allocated
out_buf             rmb       128                 ; Formatted text output buffer
                    rmb       256                 ; Hardware stack space
stack               equ       .
size                equ       .

                    mod       eom,name,tylg,atrv,start,size

name                fcs       /memstress/
                    fcb       edition

* Text strings
banner_msg          fcb       C$CR,C$LF
                    fcc       "============================================================"
                    fcb       C$CR,C$LF
                    fcc       "         NitrOS-9 MMU Memory Stress & Swapping Benchmark"
                    fcb       C$CR,C$LF
                    fcc       "============================================================"
                    fcb       C$CR,C$LF
banner_len          equ       *-banner_msg

cpu6809_str         fcc       "CPU Architecture    : Motorola 6809"
                    fcb       C$CR,C$LF
cpu6809_len         equ       *-cpu6809_str

cpu6309_str         fcc       "CPU Architecture    : Hitachi 6309"
                    fcb       C$CR,C$LF
cpu6309_len         equ       *-cpu6309_str

ram_hdr             fcc       "Physical RAM Tested : "
ram_hdr_len         equ       *-ram_hdr

blks_str            fcc       " blocks ("
blks_str_len        equ       *-blks_str

kb_str              fcc       " KB)"
                    fcb       C$CR,C$LF
kb_str_len          equ       *-kb_str

scan_hdr            fcb       C$CR,C$LF
                    fcc       "--- Swapping Threshold Scan ---"
                    fcb       C$CR,C$LF
                    fcc       "  Blocks Active :"
scan_hdr_len        equ       *-scan_hdr

tput_hdr            fcb       C$CR,C$LF
                    fcc       "  Throughput    :"
tput_hdr_len        equ       *-tput_hdr

div_line            fcb       C$CR,C$LF
                    fcc       "  ----------------------------------------------------------"
                    fcb       C$CR,C$LF
div_line_len        equ       *-div_line

hot_msg             fcc       "  -> Zero-Swapping Hot Pool : "
hot_msg_len         equ       *-hot_msg

onset_msg           fcc       "  -> Swapping Begins At     : "
onset_msg_len       equ       *-onset_msg

none_msg            fcc       "None detected (all tested blocks resident)"
                    fcb       C$CR,C$LF
none_msg_len        equ       *-none_msg

perf_hdr            fcb       C$CR,C$LF
                    fcc       "--- Access Pattern Performance ---"
                    fcb       C$CR,C$LF
perf_hdr_len        equ       *-perf_hdr

base_lbl            fcc       "  1. Baseline (Unswapped, "
base_lbl_len        equ       *-base_lbl

seq_lbl             fcc       "  2. Sequential Sweep ("
seq_lbl_len         equ       *-seq_lbl

rnd_lbl             fcc       "  3. Random Sweep     ("
rnd_lbl_len         equ       *-rnd_lbl

blks_close          fcc       " blks) : "
blks_close_len      equ       *-blks_close

swaps_sec_str       fcc       " swaps/sec  "
swaps_sec_len       equ       *-swaps_sec_str

pen_hdr             fcc       "     -> Swapping Penalty          : -"
pen_hdr_len         equ       *-pen_hdr

pen_mid             fcc       "% throughput ("
pen_mid_len         equ       *-pen_mid

pen_end             fcc       "x latency)"
                    fcb       C$CR,C$LF
pen_end_len         equ       *-pen_end

verif_hdr           fcb       C$CR,C$LF
                    fcc       "--- Data Integrity Verification ---"
                    fcb       C$CR,C$LF
                    fcc       "  Pattern Verification : "
verif_hdr_len       equ       *-verif_hdr

of_str              fcc       " / "
of_str_len          equ       *-of_str

verif_ok            fcc       " blocks verified OK"
                    fcb       C$CR,C$LF
verif_ok_len        equ       *-verif_ok

pass_msg            fcc       "  Data Integrity       : PASS (0 corruptions)"
                    fcb       C$CR,C$LF
pass_msg_len        equ       *-pass_msg

fail_msg            fcc       "  Data Integrity       : FAIL ("
fail_msg_len        equ       *-fail_msg

errs_in_blk         fcc       " errors, first bad block "
errs_in_blk_len     equ       *-errs_in_blk

close_paren         fcc       ")"
                    fcb       C$CR,C$LF
close_paren_len     equ       *-close_paren

bot_line            fcc       "============================================================"
                    fcb       C$CR,C$LF
bot_line_len        equ       *-bot_line

help_msg            fcc       "Syntax: memstress [options] [blocks]"
                    fcb       C$CR,C$LF
                    fcc       "Usage : Benchmark NitrOS-9 MMU bank-switching and RAM compression"
                    fcb       C$CR,C$LF
                    fcc       "Options:"
                    fcb       C$CR,C$LF
                    fcc       "  [blocks]   Number of 8K physical blocks to test (default: all free)"
                    fcb       C$CR,C$LF
                    fcc       "  -q         Quick mode (1-second sampling intervals, key step points)"
                    fcb       C$CR,C$LF
                    fcc       "  -?         Display this help message"
                    fcb       C$CR,C$LF
help_len            equ       *-help_msg

err_noram           fcc       "Error: Insufficient free physical RAM (need at least 4 blocks)."
                    fcb       C$CR,C$LF
err_noram_len       equ       *-err_noram

* Scan step lists (table of block counts to test, terminated by 0)
step_table_norm     fcb       4,8,12,16,18,20,24,28,32,36,40,48,0
step_table_quick    fcb       8,16,18,24,32,48,0

* Entry point
start
                    leas      stack,u             ; set up private hardware stack
                    tfr       u,d
                    tfr       a,dp                ; DP = high byte of data area
                    stu       data_base,u         ; save data area base for signal handler

* 1. Detect CPU Architecture (6809 vs 6309)
                    ldd       #$FFFF
                    fdb       $104F               ; CLRD on 6309; CLRA on 6809 leaving B=$FF
                    tstb
                    beq       set_6309
                    clr       is_6309,u
                    bra       arch_done
set_6309            lda       #1
                    sta       is_6309,u
arch_done

* 2. Initialize default state
                    clr       quick_mode,u
                    clr       req_blks,u
                    clr       blkcnt,u
                    clr       hot_pool_size,u
                    clr       swap_onset,u
                    clr       bad_block,u
                    lda       #$FF
                    sta       start_sec,u         ; mark time unsynchronized
                    ldd       #0
                    std       integrity_errors,u
                    std       baseline_swaps,u
                    std       seq_swaps,u
                    std       rnd_swaps,u
                    ldd       #$A55A
                    std       pass_seed,u

* 3. Parse command line arguments (X = parameter pointer from caller)
parse_args          lda       ,x+
                    cmpa      #' '
                    beq       parse_args
                    cmpa      #C$CR
                    beq       args_done
                    cmpa      #'-
                    beq       parse_opt
                    cmpa      #'?
                    beq       do_help
                    cmpa      #'0
                    blo       parse_args
                    cmpa      #'9
                    bhi       parse_args
* Parse decimal block count
                    leax      -1,x
                    lbsr      parse_dec
                    stb       req_blks,u
                    bra       parse_args

parse_opt           lda       ,x+
                    cmpa      #'?
                    beq       do_help
                    cmpa      #'q
                    beq       set_quick
                    cmpa      #'Q
                    beq       set_quick
                    bra       parse_args
set_quick           lda       #1
                    sta       quick_mode,u
                    bra       parse_args

do_help             leax      help_msg,pcr
                    ldy       #help_len
                    lda       #1
                    os9       I$Write
                    clrb
                    os9       F$Exit

args_done
* 4. Register signal intercept handler to safely free RAM on Ctrl-C
                    leax      SigHandler,pcr
                    os9       F$Icpt

* 5. Print banner
                    leax      banner_msg,pcr
                    ldy       #banner_len
                    lda       #1
                    os9       I$Write

* 6. Print CPU Architecture
                    tst       is_6309,u
                    bne       p_6309
                    leax      cpu6809_str,pcr
                    ldy       #cpu6809_len
                    bra       p_arch
p_6309              leax      cpu6309_str,pcr
                    ldy       #cpu6309_len
p_arch              lda       #1
                    os9       I$Write

* 7. Allocate physical RAM blocks via F$AllRAM
                    lbsr      AllocRAM
                    lda       blkcnt,u
                    cmpa      #MIN_BLKS
                    bhs       ram_ok

* Less than MIN_BLKS available - report error and exit
                    leax      err_noram,pcr
                    ldy       #err_noram_len
                    lda       #1
                    os9       I$WritLn
                    lbsr      FreeRAM
                    ldb       #1
                    os9       F$Exit

ram_ok
* 8. Print Physical RAM Tested: XX blocks (YYY KB)
                    leax      ram_hdr,pcr
                    ldy       #ram_hdr_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       blkcnt,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      blks_str,pcr
                    ldy       #blks_str_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       blkcnt,u
                    lslb
                    rola
                    lslb
                    rola
                    lslb
                    rola                          ; D = blkcnt * 8
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      kb_str,pcr
                    ldy       #kb_str_len
                    lda       #1
                    os9       I$Write

* 9. Establish duration (quick mode = 1s, normal = 2s)
                    lda       #2
                    tst       quick_mode,u
                    beq       dur_set
                    lda       #1
dur_set             sta       duration_sec,u

* 10. Calibrate Baseline Unswapped Speed
* Use min(BASE_BLKS, blkcnt) blocks, well within the 16 hot slots
                    lda       #BASE_BLKS
                    cmpa      blkcnt,u
                    bls       base_size_ok
                    lda       blkcnt,u
base_size_ok        sta       cur_step_blks,u

                    lda       duration_sec,u
                    lbsr      BenchBlocks
                    ldd       swap_count,u
                    tst       quick_mode,u
                    bne       base_save
* In 2s mode, divide by 2 to get swaps/sec
                    lsra
                    rorb
base_save           cmpd      #0
                    bne       base_nonzero
                    ldd       #1                  ; safety floor
base_nonzero        std       baseline_swaps,u

* 11. Run Threshold Scan
                    leax      scan_hdr,pcr
                    ldy       #scan_hdr_len
                    lda       #1
                    os9       I$Write

* Print header row of block counts
                    leax      step_table_norm,pcr
                    tst       quick_mode,u
                    beq       sh_tbl_ok
                    leax      step_table_quick,pcr
sh_tbl_ok
print_step_hdr      lda       ,x+
                    beq       step_hdr_done
                    cmpa      blkcnt,u
                    bhi       step_hdr_done
                    pshs      x,a                 ; 0,s = block count, 1..2,s = X
                    leay      out_buf,u
                    lda       #' '
                    sta       ,y+
                    sta       ,y+
                    sta       ,y+
                    ldb       ,s                  ; block count
                    cmpb      #10
                    bhs       sh_2d
                    lda       #' '
                    sta       ,y+
sh_2d               clra
                    ldb       ,s
                    lbsr      PrintDec16
                    lbsr      PrintBuf
                    puls      a,x
                    bra       print_step_hdr
step_hdr_done

* Print throughput row
                    leax      tput_hdr,pcr
                    ldy       #tput_hdr_len
                    lda       #1
                    os9       I$Write

                    leax      step_table_norm,pcr
                    tst       quick_mode,u
                    beq       st_tbl_ok
                    leax      step_table_quick,pcr
st_tbl_ok
run_step_scan       lda       ,x+
                    beq       scan_steps_done
                    cmpa      blkcnt,u
                    bhi       scan_steps_done
                    sta       cur_step_blks,u
                    pshs      x

* Benchmark this step count for 1 second
                    lda       #1
                    lbsr      BenchBlocks

* Calculate percentage of baseline: (swap_count * 100) / baseline_swaps
                    ldx       swap_count,u
                    lbsr      Mul16x100           ; X:D = swap_count * 100
                    ldy       baseline_swaps,u
                    lbsr      Div32x16            ; D = quotient (percentage)
                    cmpd      #100
                    bls       pct_clamped
                    ldd       #100
pct_clamped         tfr       b,a
                    sta       step_pct,u

* Update hot_pool_size and swap_onset
                    cmpa      #85
                    blo       below_thresh
                    lda       cur_step_blks,u
                    sta       hot_pool_size,u
                    bra       pct_print
below_thresh        tst       swap_onset,u
                    bne       pct_print
                    lda       cur_step_blks,u
                    sta       swap_onset,u

pct_print
* Print formatted percentage: " 100%" or "  78%" or "   5%"
                    leay      out_buf,u
                    lda       #' '
                    sta       ,y+
                    ldb       step_pct,u
                    cmpb      #100
                    bhs       pct_3d
                    cmpb      #10
                    bhs       pct_2d
                    lda       #' '
                    sta       ,y+
pct_2d              lda       #' '
                    sta       ,y+
pct_3d              clra
                    ldb       step_pct,u
                    lbsr      PrintDec16
                    lda       #'%'
                    sta       ,y+
                    lbsr      PrintBuf

                    puls      x
                    bra       run_step_scan

scan_steps_done
* Print divider and summary of threshold
                    leax      div_line,pcr
                    ldy       #div_line_len
                    lda       #1
                    os9       I$Write

* Print Zero-Swapping Hot Pool
                    leax      hot_msg,pcr
                    ldy       #hot_msg_len
                    lda       #1
                    os9       I$Write

                    lda       hot_pool_size,u
                    bne       pr_hot_val
                    lda       #16                 ; default expectation
pr_hot_val          sta       cur_step_blks,u
                    leay      out_buf,u
                    clra
                    ldb       cur_step_blks,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      blks_str,pcr
                    ldy       #blks_str_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       cur_step_blks,u
                    lslb
                    rola
                    lslb
                    rola
                    lslb
                    rola
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      kb_str,pcr
                    ldy       #kb_str_len
                    lda       #1
                    os9       I$Write

* Print Swapping Begins At
                    leax      onset_msg,pcr
                    ldy       #onset_msg_len
                    lda       #1
                    os9       I$Write

                    lda       swap_onset,u
                    bne       pr_onset_val
* No onset detected within tested range
                    leax      none_msg,pcr
                    ldy       #none_msg_len
                    lda       #1
                    os9       I$Write
                    bra       scan_finished

pr_onset_val        sta       cur_step_blks,u
                    leay      out_buf,u
                    clra
                    ldb       cur_step_blks,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      blks_str,pcr
                    ldy       #blks_str_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       cur_step_blks,u
                    lslb
                    rola
                    lslb
                    rola
                    lslb
                    rola
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      kb_str,pcr
                    ldy       #kb_str_len
                    lda       #1
                    os9       I$Write

scan_finished

* 12. Run Sequential Sweep across all blkcnt blocks
                    lda       blkcnt,u
                    sta       cur_step_blks,u
                    lda       duration_sec,u
                    lbsr      BenchBlocks
                    ldd       swap_count,u
                    tst       quick_mode,u
                    bne       seq_save
                    lsra
                    rorb
seq_save            std       seq_swaps,u

* 13. Run Random Sweep across all blkcnt blocks
* Pick coprime step: if blkcnt % 11 != 0, use 11; else use 13
                    clra
                    ldb       blkcnt,u
div11_lp            cmpb      #11
                    blo       div11_done
                    subb      #11
                    bra       div11_lp
div11_done          tstb
                    bne       step_is_11
                    lda       #13
                    bra       set_rnd_step
step_is_11          lda       #11
set_rnd_step        sta       rnd_step,u

                    lda       duration_sec,u
                    lbsr      BenchRandom
                    ldd       swap_count,u
                    tst       quick_mode,u
                    bne       rnd_save
                    lsra
                    rorb
rnd_save            std       rnd_swaps,u

* 14. Print Access Pattern Performance Report
                    leax      perf_hdr,pcr
                    ldy       #perf_hdr_len
                    lda       #1
                    os9       I$Write

* Print 1. Baseline
                    leax      base_lbl,pcr
                    ldy       #base_lbl_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       #BASE_BLKS
                    cmpb      blkcnt,u
                    bls       pr_bsz
                    ldb       blkcnt,u
pr_bsz              lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      blks_close,pcr
                    ldy       #blks_close_len
                    lda       #1
                    os9       I$Write

                    ldd       baseline_swaps,u
                    lbsr      PrintRateAndMBS

* Print 2. Sequential Sweep
                    leax      seq_lbl,pcr
                    ldy       #seq_lbl_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       blkcnt,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      blks_close,pcr
                    ldy       #blks_close_len
                    lda       #1
                    os9       I$Write

                    ldd       seq_swaps,u
                    lbsr      PrintRateAndMBS

* Print Sequential Penalty
                    ldd       seq_swaps,u
                    lbsr      PrintPenalty

* Print 3. Random Sweep
                    leax      rnd_lbl,pcr
                    ldy       #rnd_lbl_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       blkcnt,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      blks_close,pcr
                    ldy       #blks_close_len
                    lda       #1
                    os9       I$Write

                    ldd       rnd_swaps,u
                    lbsr      PrintRateAndMBS

* Print Random Penalty
                    ldd       rnd_swaps,u
                    lbsr      PrintPenalty

* 15. Data Integrity Verification Pass
                    leax      verif_hdr,pcr
                    ldy       #verif_hdr_len
                    lda       #1
                    os9       I$Write

* Populate distinct patterns into each block
                    ldd       #$5AA5
                    std       pass_seed,u
                    clra
pop_loop            pshs      a
                    lbsr      TouchBlock
                    puls      a
                    inca
                    cmpa      blkcnt,u
                    blo       pop_loop

* Exercise 3 sequential and random stress sweeps under compression pressure
                    ldb       #3
stress_passes       pshs      b
* Sequential pass
                    clra
sp_seq_lp           pshs      a
                    lbsr      TouchBlock
                    puls      a
                    inca
                    cmpa      blkcnt,u
                    blo       sp_seq_lp
* Random pass
                    clra
                    ldb       blkcnt,u
sp_rnd_lp           pshs      b,a
                    lbsr      TouchBlock
                    puls      a,b
                    adda      rnd_step,u
sp_rnd_mod          cmpa      blkcnt,u
                    blo       sp_rnd_next
                    suba      blkcnt,u
                    bra       sp_rnd_mod
sp_rnd_next         decb
                    bne       sp_rnd_lp
                    puls      b
                    decb
                    bne       stress_passes

* Verify all blocks
                    clr       integrity_errors,u
                    clr       integrity_errors+1,u
                    clra
verif_loop          pshs      a
                    lbsr      VerifyBlock
                    puls      a
                    inca
                    cmpa      blkcnt,u
                    blo       verif_loop

* Print verification count
                    leay      out_buf,u
                    clra
                    ldb       blkcnt,u
                    subd      integrity_errors,u
                    bpl       good_cnt_ok
                    ldd       #0
good_cnt_ok         lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      of_str,pcr
                    ldy       #of_str_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       blkcnt,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      verif_ok,pcr
                    ldy       #verif_ok_len
                    lda       #1
                    os9       I$Write

* Print PASS or FAIL
                    ldd       integrity_errors,u
                    bne       do_fail
                    leax      pass_msg,pcr
                    ldy       #pass_msg_len
                    lda       #1
                    os9       I$Write
                    bra       verif_done

do_fail             leax      fail_msg,pcr
                    ldy       #fail_msg_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    ldd       integrity_errors,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      errs_in_blk,pcr
                    ldy       #errs_in_blk_len
                    lda       #1
                    os9       I$Write

                    leay      out_buf,u
                    clra
                    ldb       bad_block,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      close_paren,pcr
                    ldy       #close_paren_len
                    lda       #1
                    os9       I$Write

verif_done
* Print bottom border
                    leax      bot_line,pcr
                    ldy       #bot_line_len
                    lda       #1
                    os9       I$Write

* 16. Clean Deallocation and Exit
                    lbsr      FreeRAM
                    clrb
                    os9       F$Exit

* Signal handler (Ctrl-C / SIGINT)
SigHandler          lbsr      FreeRAM
                    clrb
                    os9       F$Exit

********************************************************************
* AllocRAM - Allocate 1 block at a time up to MAX_BLKS or req_blks
********************************************************************
AllocRAM            clr       blkcnt,u
                    leay      blktbl,u
alloc_lp            ldb       #1                  ; request 1 block
                    os9       F$AllRAM
                    bcs       alloc_ret           ; no more RAM available
                    stb       ,y+                 ; record physical block number
                    inc       blkcnt,u
                    lda       blkcnt,u
                    cmpa      #MAX_BLKS
                    bhs       alloc_ret
                    lda       req_blks,u
                    beq       alloc_lp
                    cmpa      blkcnt,u
                    bhi       alloc_lp
alloc_ret           rts

********************************************************************
* FreeRAM - Deallocate all allocated physical RAM blocks
********************************************************************
FreeRAM             lda       blkcnt,u
                    beq       free_ret
                    leay      blktbl,u
free_lp             clra
                    ldb       ,y+                 ; physical block number
                    tfr       d,x                 ; X = 16-bit block number
                    ldb       #1                  ; 1 block
                    os9       F$DelRAM
                    dec       blkcnt,u
                    bne       free_lp
free_ret            rts

********************************************************************
* TouchBlock - Map block, write pattern words, and unmap
* Entry: A = index into blktbl (0..blkcnt-1)
********************************************************************
TouchBlock          pshs      u,y,x,d
                    leay      blktbl,u
                    ldb       a,y                 ; B = physical block number
                    clra
                    tfr       d,x                 ; X = physical block number
                    ldb       #1                  ; 1 block
                    pshs      u                   ; preserve data pointer U
                    os9       F$MapBlk            ; returns mapped address in U
                    bcs       tb_map_err
                    tfr       u,x                 ; X = mapped block base
                    puls      u                   ; restore our U
                    stx       mapped_addr,u

* Write signature words across 16 offsets
                    ldd       pass_seed,u
                    eora      ,s                  ; combine with block index
                    std       ,x
                    std       $0200,x
                    std       $0400,x
                    std       $0600,x
                    std       $0800,x
                    std       $0A00,x
                    std       $0C00,x
                    std       $0E00,x
                    std       $1000,x
                    std       $1200,x
                    std       $1400,x
                    std       $1600,x
                    std       $1800,x
                    std       $1A00,x
                    std       $1C00,x
                    std       $1E00,x

* Unmap block
                    ldb       #1
                    ldu       mapped_addr,u
                    os9       F$ClrBlk
                    puls      d,x,y,u,pc

tb_map_err          puls      u
                    puls      d,x,y,u,pc

********************************************************************
* VerifyBlock - Map block, verify signature words, and unmap
* Entry: A = index into blktbl (0..blkcnt-1)
********************************************************************
VerifyBlock         pshs      u,y,x,d
                    leay      blktbl,u
                    ldb       a,y
                    clra
                    tfr       d,x
                    ldb       #1
                    pshs      u
                    os9       F$MapBlk
                    lbcs      vb_map_err
                    tfr       u,x
                    puls      u
                    stx       mapped_addr,u

* Compare signature words
                    ldd       pass_seed,u
                    eora      ,s                  ; expected signature
                    cmpd      ,x
                    bne       vb_err
                    cmpd      $0200,x
                    bne       vb_err
                    cmpd      $0400,x
                    bne       vb_err
                    cmpd      $0600,x
                    bne       vb_err
                    cmpd      $0800,x
                    bne       vb_err
                    cmpd      $0A00,x
                    bne       vb_err
                    cmpd      $0C00,x
                    bne       vb_err
                    cmpd      $0E00,x
                    bne       vb_err
                    cmpd      $1000,x
                    bne       vb_err
                    cmpd      $1200,x
                    bne       vb_err
                    cmpd      $1400,x
                    bne       vb_err
                    cmpd      $1600,x
                    bne       vb_err
                    cmpd      $1800,x
                    bne       vb_err
                    cmpd      $1A00,x
                    bne       vb_err
                    cmpd      $1C00,x
                    bne       vb_err
                    cmpd      $1E00,x
                    bne       vb_err

vb_unmap            ldb       #1
                    ldu       mapped_addr,u
                    os9       F$ClrBlk
                    puls      d,x,y,u,pc

vb_err              ldd       integrity_errors,u
                    addd      #1
                    std       integrity_errors,u
                    lda       ,s                  ; block index
                    sta       bad_block,u
                    bra       vb_unmap

vb_map_err          puls      u
                    puls      d,x,y,u,pc

********************************************************************
* SyncEdge - Wait for next second rollover and record start_sec
********************************************************************
SyncEdge            leax      time_buf,u
                    os9       F$Time
                    lda       time_buf+5,u
                    sta       last_sec,u
se_wait             leax      time_buf,u
                    os9       F$Time
                    lda       time_buf+5,u
                    cmpa      last_sec,u
                    beq       se_wait
                    sta       start_sec,u
                    rts

********************************************************************
* BenchBlocks - Benchmark sequential access across cur_step_blks
* Entry: A = duration in seconds (1 or 2)
* Exit:  swap_count = total block swaps completed
********************************************************************
BenchBlocks         sta       duration_sec,u
                    lbsr      SyncEdge
bb_synced           ldd       #0
                    std       swap_count,u
                    clr       inner_cnt,u
                    clra                          ; start block index 0

bb_loop             pshs      a
                    lbsr      TouchBlock
                    puls      a

                    ldd       swap_count,u
                    addd      #1
                    std       swap_count,u

* Advance sequential block index
                    inca
                    cmpa      cur_step_blks,u
                    blo       bb_next
                    clra                          ; wrap around

bb_next             inc       inner_cnt,u
                    lda       inner_cnt,u
                    anda      #$1F                ; check time every 32 swaps
                    bne       bb_loop

* Check elapsed time
                    pshs      a
                    leax      time_buf,u
                    os9       F$Time
                    lda       time_buf+5,u
                    suba      start_sec,u
                    bpl       bb_tpos
                    adda      #60
bb_tpos             cmpa      duration_sec,u
                    puls      a
                    blo       bb_loop
* Record current second so next back-to-back bench knows start
                    lda       time_buf+5,u
                    sta       start_sec,u
                    rts

********************************************************************
* BenchRandom - Benchmark coprime permutation access across cur_step_blks
* Entry: A = duration in seconds (1 or 2)
* Exit:  swap_count = total block swaps completed
********************************************************************
BenchRandom         sta       duration_sec,u
                    lbsr      SyncEdge
br_synced           ldd       #0
                    std       swap_count,u
                    clr       inner_cnt,u
                    clra                          ; starting block index 0

br_loop             pshs      a
                    lbsr      TouchBlock
                    puls      a

                    ldd       swap_count,u
                    addd      #1
                    std       swap_count,u

* Next block: (idx + rnd_step) % cur_step_blks
                    adda      rnd_step,u
br_mod              cmpa      cur_step_blks,u
                    blo       br_next
                    suba      cur_step_blks,u
                    bra       br_mod

br_next             inc       inner_cnt,u
                    lda       inner_cnt,u
                    anda      #$1F
                    bne       br_loop

* Check elapsed time
                    pshs      a
                    leax      time_buf,u
                    os9       F$Time
                    lda       time_buf+5,u
                    suba      start_sec,u
                    bpl       br_tpos
                    adda      #60
br_tpos             cmpa      duration_sec,u
                    puls      a
                    blo       br_loop
                    lda       time_buf+5,u
                    sta       start_sec,u
                    rts

********************************************************************
* PrintRateAndMBS - Print swaps/sec and (XX.X MB/s)
* Entry: D = swaps/sec
********************************************************************
PrintRateAndMBS     std       step_swaps,u
                    leay      out_buf,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      swaps_sec_str,pcr
                    ldy       #swaps_sec_len
                    lda       #1
                    os9       I$Write

* Format: (XX.X MB/s)
                    leay      out_buf,u
                    lda       #'('
                    sta       ,y+
* Calculate MB/s: swaps / 128 (since each block is 8 KB = 1/128 MB)
                    ldd       step_swaps,u
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb                          ; D = swaps / 128 (whole MB/s)
                    lbsr      PrintDec16
                    lda       #'.'
                    sta       ,y+

* Remainder * 10 / 128 (tenths digit)
                    ldd       step_swaps,u
                    andb      #$7F
                    clra                          ; D = remainder (0..127)
                    lda       #10
                    mul                           ; D = remainder * 10 (0..1270)
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb                          ; B = tenths (0..9)
                    addb      #'0'
                    stb       ,y+

                    lda       #' '
                    sta       ,y+
                    lda       #'M'
                    sta       ,y+
                    lda       #'B'
                    sta       ,y+
                    lda       #'/'
                    sta       ,y+
                    lda       #'s'
                    sta       ,y+
                    lda       #')'
                    sta       ,y+
                    lda       #C$CR
                    sta       ,y+
                    lda       #C$LF
                    sta       ,y+
                    lbsr      PrintBuf
                    rts

********************************************************************
* PrintPenalty - Print penalty % and latency multiplier
* Entry: D = measured swaps/sec
********************************************************************
PrintPenalty        std       step_swaps,u
                    leax      pen_hdr,pcr
                    ldy       #pen_hdr_len
                    lda       #1
                    os9       I$Write

* Compute penalty %: 100 - (measured * 100 / baseline)
                    ldx       step_swaps,u        ; measured swaps
                    lbsr      Mul16x100           ; X:D = measured * 100
                    ldy       baseline_swaps,u
                    lbsr      Div32x16            ; D = percentage
                    cmpd      #100
                    bls       pen_pct_ok
                    ldd       #100
pen_pct_ok          ldx       #100
                    exg       x,d                 ; X = percentage, D = 100
                    pshs      x
                    subd      ,s++                ; D = 100 - percentage
                    bpl       pen_pos
                    ldd       #0
pen_pos
                    leay      out_buf,u
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      pen_mid,pcr
                    ldy       #pen_mid_len
                    lda       #1
                    os9       I$Write

* Compute latency multiplier: (baseline * 100) / measured
                    ldd       step_swaps,u
                    bne       have_swaps
                    ldd       #1                  ; avoid div by 0
have_swaps          tfr       d,y                 ; Y = divisor (measured swaps)
                    ldx       baseline_swaps,u
                    lbsr      Mul16x100           ; X:D = baseline * 100
                    lbsr      Div32x16            ; D = ratio * 100
                    tfr       d,x                 ; X = ratio * 100

                    leay      out_buf,u
* Whole part: ratio / 100
                    tfr       x,d
                    ldx       #100
                    lbsr      Div16x16            ; D = whole, X = remainder
                    lbsr      PrintDec16
                    lda       #'.'
                    sta       ,y+

* Fractional part (2 digits)
                    cmpx      #10
                    bhs       lat_2d
                    lda       #'0'
                    sta       ,y+
lat_2d              tfr       x,d                 ; D = remainder (0..99)
                    lbsr      PrintDec16
                    lbsr      PrintBuf

                    leax      pen_end,pcr
                    ldy       #pen_end_len
                    lda       #1
                    os9       I$Write
                    rts

********************************************************************
* PrintBuf - Write contents of out_buf from start to Y to stdout
* Output: Buffer written, Y reset to out_buf,u
* Preserves: D, X
********************************************************************
PrintBuf            pshs      x,d
                    leax      out_buf,u
                    tfr       y,d
                    pshs      x
                    subd      ,s++                ; D = Y - out_buf,u (byte count)
                    beq       pb_done
                    tfr       d,y                 ; Y = length
                    lda       #1                  ; stdout path
                    os9       I$Write
pb_done             puls      d,x
                    leay      out_buf,u           ; reset Y
                    rts

********************************************************************
* PrintBufLn - Write contents of out_buf from start to Y to stdout with CR
* Output: Buffer written, Y reset to out_buf,u
* Preserves: D, X
********************************************************************
PrintBufLn          pshs      x,d
                    leax      out_buf,u
                    tfr       y,d
                    pshs      x
                    subd      ,s++                ; D = Y - out_buf,u (byte count)
                    tfr       d,y                 ; Y = length
                    lda       #1                  ; stdout path
                    os9       I$WritLn
                    puls      d,x
                    leay      out_buf,u           ; reset Y
                    rts

********************************************************************
* PrintDec16 - Convert 16-bit integer D into decimal characters at Y
* Input: D = 16-bit unsigned number
*        Y = buffer pointer where characters will be appended
* Output: characters appended at Y, Y updated past last character
* Preserves: D, X, U
********************************************************************
PrintDec16          pshs      u,x,d               ; preserve caller's U, X, D
                    leas      -3,s                ; 0,s = loop_cnt, 1,s = zersup, 2,s = digit
                    clr       1,s                 ; zersup = 0
                    lda       #5
                    sta       ,s                  ; loop_cnt = 5
                    ldd       3,s                 ; reload input D from stack
                    leax      tns_tbl,pcr         ; X points to table of powers of 10
pd_pow_lp           clr       2,s                 ; reset digit counter to 0
pd_sub_lp           subd      ,x                  ; subtract current power of 10
                    bcs       pd_underflow
                    inc       2,s                 ; increment digit counter
                    bra       pd_sub_lp
pd_underflow        addd      ,x++                ; restore remainder, advance X to next power
                    pshs      d                   ; preserve working remainder D across emission
                    lda       2,s                 ; loop counter (offset +2 due to pushed D)
                    cmpa      #1                  ; last digit (units)?
                    beq       pd_force_emit       ; last digit is ALWAYS emitted!
                    lda       4,s                 ; get digit
                    bne       pd_emit_digit       ; non-zero: end suppression and emit
                    tst       3,s                 ; zero: already emitting?
                    bne       pd_emit_digit       ; yes: emit '0'
                    bra       pd_skip_emit        ; no: suppress leading zero
pd_force_emit       inc       3,s                 ; force emission of last digit
pd_emit_digit       lda       4,s                 ; digit (0..9)
                    inc       3,s                 ; flag non-zero emitted
                    adda      #'0'
                    sta       ,y+
pd_skip_emit        puls      d                   ; restore working remainder D
pd_next_pow         dec       ,s                  ; decrement loop counter (5..1)
                    bne       pd_pow_lp
pd_done             leas      3,s                 ; drop loop counter, zersup, and digit counter
                    puls      d,x,u,pc            ; restore caller's D, X, U and return

tns_tbl             fdb       10000,1000,100,10,1

********************************************************************
* parse_dec - Parse decimal number from X
* Exit: B = number
********************************************************************
parse_dec           clrb
pdec_lp             lda       ,x
                    cmpa      #'0'
                    blo       pdec_done
                    cmpa      #'9'
                    bhi       pdec_done
                    suba      #'0'
                    pshs      a
                    lda       #10
                    mul
                    addb      ,s+
                    leax      1,x
                    bra       pdec_lp
pdec_done           rts

********************************************************************
* Mul16x100 - Multiply 16-bit X by 100 -> 32-bit in X (high) : D (low)
********************************************************************
Mul16x100           pshs      x                   ; 0,s = N (high byte 0,s, low byte 1,s)
                    lda       #100
                    ldb       1,s                 ; N_L
                    mul                           ; D = N_L * 100
                    pshs      d                   ; 0,s = L_1:L_0, 2,s = N
                    lda       #100
                    ldb       2,s                 ; N_H
                    mul                           ; D = N_H * 100
                    addb      ,s                  ; B = H_0 + L_1
                    adca      #0                  ; A = H_1 + carry
                    stb       ,s                  ; 0,s now has byte 1
                    clrb
                    exg       a,b                 ; D = high 16 bits
                    tfr       d,x                 ; X = high 16 bits
                    puls      d                   ; D = byte 1 : byte 0
                    leas      2,s                 ; clean up pushed N
                    rts

********************************************************************
* Div32x16 - 32-bit by 16-bit unsigned division
* Entry: X = High 16 bits, D = Low 16 bits
*        Y = 16-bit divisor
* Exit:  D = Quotient, X = Remainder
********************************************************************
Div32x16            sty       divisor,u
                    cmpy      #0
                    bne       d32_ok
                    ldd       #0
                    ldx       #0
                    rts
d32_ok              pshs      a
                    lda       #16
                    sta       div_cnt,u
                    puls      a
d32_lp              lslb
                    rola
                    exg       x,d
                    rolb
                    rola
                    cmpd      divisor,u
                    blo       d32_no
                    subd      divisor,u
                    exg       x,d
                    orb       #1
                    bra       d32_next
d32_no              exg       x,d
d32_next            dec       div_cnt,u
                    bne       d32_lp
                    rts

********************************************************************
* Div16x16 - 16-bit unsigned divide
* Entry: D = dividend, X = divisor
* Exit:  D = quotient, X = remainder
********************************************************************
Div16x16            pshs      y
                    tfr       x,y                 ; Y = divisor
                    ldx       #0                  ; X = High 16 bits = 0
                                                  ; D = Low 16 bits = dividend
                    lbsr      Div32x16
                    puls      y,pc

                    emod
eom                 equ       *
                    end
