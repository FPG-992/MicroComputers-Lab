.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=1000
.equ F1=FOSC_MHZ*DEL_mS
    
.def pos=r31
    
.org 0x0
    rjmp reset
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; Load delay to r24-r25
    ldi r24, low(F1)
    ldi r25, high(F1)
    
    ldi pos,0b10000000
    
    ser r24		; r24 = 0xFF
    out DDRD,r24	; Set DDRD as output
    
    out PORTD,pos	; Output initial position.
    set			; T=1, we're moving to the left

    rcall wait_x_msec
    
to_left:
    lsr pos
    out PORTD,pos
    
    rcall wait_x_msec	    ; 1s delay
    sbrs pos,0		    ; Skip if we're in the first bit (bit 0 = 1)
    rjmp to_left
    
    set			    ; T=0
    rcall wait_x_msec
    rjmp to_right	    ; Change_direction
    
to_right:
    lsl pos		    ; Shift bit to the right, left on the LEDs
    out PORTD,pos	    ; output position
    
    rcall wait_x_msec	    ; 1s delay
    sbrs pos,7		    ; Skip if we're in the last bit (bit 7 = 1)
    rjmp to_right
    
    clt			    ; T=0
    rcall wait_x_msec
    rjmp to_left	    ; Change_direction
    
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
    
    nop			; 1 cycle
    ret			; 4 cycles