* Subroutine makes an OS-9 system call but does not check the Carry bit
          nam       case_fail_os9_carry
          ttl       Missing OS-9 Error Check Example

LinkModule
          pshs      d,x,y,u
          os9       F$Link
* Bug: Should check BCS or BCC here immediately!
          sty       ModuleEntry,p
          puls      d,x,y,u
          rts
