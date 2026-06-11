* Violates rules in .ai_assembly_rules.md
          nam       case_fail_rules_violation
          ttl       Rules Violation Example

* 1. 6809 buffer optimization violation:
* Uses auto-increment loop for a small 8-byte copy instead of 5-bit offsets.
CopySmall
          ldb       #4
Loop
          ldu       ,y+
          stu       ,x+
          decb
          bne       Loop
          rts

* 2. Stack blast violation:
* Uses LDS to blast stack but does not disable interrupts via ORCC #$50
StackBlast
          lds       #$7FFF
          pshs      d,x,y,u
          puls      d,x,y,u
          rts
