* Subroutine that falls through without RTS
          nam       case_fail_missing_return
          ttl       Missing Return Example

MyFunc
          pshs      d,x
          ldd       #$00FF
          std       ,x
          puls      d,x
* Bug: Missing RTS/RTI, falls through to arbitrary code
