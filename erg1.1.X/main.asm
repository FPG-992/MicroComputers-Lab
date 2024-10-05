.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=10000
.equ F1=FOSC_MHZ*DEL_mS

reset:
    ; Initialize Stack
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24

main:
    ldi r24, low(F1)
    ldi r25, high(F1)
    rcall wait_x_msec
    rjmp finish
    
; wait_x_msec generates a delay of (6 + 1000 * x + 12 = 1000*x + 18) cycles
wait_x_msec:
    push r23		; 2 cycles
    push r24		; 2 cycles
    push r25		; 2 cycles
repeat_x:		; ! (x-1) * (996 + 2 + 2) + 996 + 2 + 1 + 10 = 1000 * x + 13 - 1 = 1000*x + 12 !
    rcall wait_one_msec	; 3 + 993 = 996 cycles
    sbiw r24,1		; 2 cycles
    brne repeat_x	; 1 or 2 cycles
    
    pop r25		; 2 cycles
    pop	r24		; 2 cycles
    pop r23		; 2 cycles
    ret			; 4 cycles

wait_one_msec:		; ! 246 * 4 + 8 + 1 = 993 cycles * 
    ldi	r23, 247	; 1 cycle
repeat_one:		; ! 4 cycles (last 3 + 5 = 8 cycles) !
    dec r23		; 1 cycle
    nop			; 1 cycle
    brne repeat_one	; 1 or 2 cycles
    
    nop			; 1 cycle (this can be avoided and make the repeat_x
			; loop cost 1003 cycles instead of 1004
    ret			; 4 cycles

finish: