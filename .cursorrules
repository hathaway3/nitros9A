# 6809/6309 Assembly Data Movement Optimization Rules

When generating, refactoring, or reviewing 6809 or 6309 assembly language code for data copy operations, you must strictly adhere to the following performance and engineering constraints:

## 1. 6309 Hardware Specific Optimizations
* **Condition:** Targeting 6309 hardware specifically.
* **Action:** Mandatorily emit `TFM X+,Y+` or `TFM X-,Y-` and completely bypass software loops to hit the 3.00 cycles/byte hardware limit.

## 2. Standard 6809 Buffer Optimizations (≤ 16 Bytes)
* **Condition:** Optimizing small-to-medium variable buffers up to 16 bytes on standard 6809.
* **Action:** Utilize constant 5-bit offsets (`LDD n,Y` / `STD n,X`) in an unrolled structure instead of auto-increment adjustments to save 2.00 cycles per byte (dropping from 8.00 to 6.00 cycles/byte raw path). Ensure `LEAX`/`LEAY` are emitted at the end of the unrolled block to correctly align base pointers if loop processing repeats.

## 3. 'Stack Blast' Routines using LDS
* **Condition:** Generating a 'Stack Blast' routine using LDS.
* **Action:** Prepend code with `ORCC #$50` and append with `ANDCC #$AF`. If these instructions are omitted, mark code generation as FAILED.

## 4. Overlapping Memory Blocks (Source < Destination)
* **Condition:** Memory blocks overlap such that Source < Destination.
* **Action:** Pointers must be calculated from the end of the buffers moving backward via pre-decrement operators `,--X` or negative 5-bit offsets to maintain data integrity at 11.50 cycles/byte.
