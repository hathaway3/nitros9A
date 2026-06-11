* Clobbers register X and Y without saving/restoring them
          nam       case_fail_clobber
          ttl       Clobbering Registers Example

* Subroutine: Modifies X and Y but does not preserve them
MyFunc
          pshs      d
          ldx       #$1000
          ldy       #$2000
          puls      d
          rts
