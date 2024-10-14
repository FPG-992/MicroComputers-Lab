.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=50
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms
    
.def count=r26
.def updated=r27
    
.org 0x0
    rjmp reset
    
.org 0x4
    rjmp ISR1
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; Set PORTB as output
    ser r24
    out DDRB,r24
    
    ; Setup interrupts
    ldi r24,(1 << ISC11) | (1 << ISC10)
    sts EICRA,r24
    
    ldi r24, (1 << INT1)
    out EIMSK,r24
    
    sei
    
    ; Load delay to r24-r25
    ldi r24, low(F1)
    ldi r25, high(F1)
    
start:
    cpi count,0
    brne check1
    
    clr updated
    clr r28
    out PORTB, r28
    rjmp end
    
check1:
    cpi count,91
    brsh check2
    
    ldi r28,0x01
    out PORTB,r28
    rjmp decrement
    
check2:
    sbrc updated,0
    rjmp displayAll
    
    ldi r28,0x01
    out PORTB,r28
    rjmp decrement
    
displayAll:
    ser r28
    out PORTB,r28
    
decrement:
    dec count    
end:
    rcall wait_x_msec
    rjmp start    
   
ISR1:
    push r23
    push r24
    push r25
    in r24,SREG
    push r24
    
    ; Load delay of 5ms for repeated checks
    ldi r24, low(F2)
    ldi r25, high(F2)
    
repeat:
    ldi r23,(1<<INTF1)
    out EIFR,r23
    
    rcall wait_x_msec
    
    in r23,EIFR
    sbrc r23,INTF1 ; 0 for INT0 1 for INT1???
    rjmp repeat
    
    cpi count,0
    breq skip
    ldi updated,0x01
    
skip:
    ldi count,100
    
finish:    
    pop r24
    out SREG,r24
    pop r25
    pop r24
    pop r23
    
    reti
    
wait_x_msec:
    push r23
    push r24
    push r25
repeat_x:
    rcall wait_one_msec
    sbiw r24,1
    brne repeat_x
    
    pop r25
    pop	r24
    pop r23
    ret

wait_one_msec:
    ldi	r23, 247
repeat_one:
    dec r23
    nop
    brne repeat_one
    
    nop
    ret