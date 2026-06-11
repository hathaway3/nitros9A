* Clean assembly file that should pass Gemini PR Review
          nam       case_pass
          ttl       Clean Code Example

* Subroutine: Copy data using optimized 5-bit offsets for small buffer (10 bytes)
* Input: X = destination, Y = source
* Preserves: D, X, Y
CopyBuffer
          pshs      d,x,y
          ldd       0,y
          std       0,x
          ldd       2,y
          std       2,x
          ldd       4,y
          std       4,x
          ldd       6,y
          std       6,x
          ldd       8,y
          std       8,x
          leax      10,x
          leay      10,y
          puls      d,x,y
          rts
