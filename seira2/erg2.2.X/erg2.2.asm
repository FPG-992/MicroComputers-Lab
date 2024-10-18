.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=2000
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms
    
.def count=r26
    
.org 0x0
    rjmp reset
    
.org 0x2
    rjmp ISR0
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; Set PORTB as input
    clr r24
    out DDRB,r24
    
    ; Set PORTC as output
    ser r24
    out DDRC,r24
    
    ; Setup interrupts
    ldi r24,(1 << ISC01) | (0 << ISC00)
    sts EICRA,r24
    
    ldi r24, (1 << INT0)
    out EIMSK,r24
    
    sei
    
    ; Load delay to r24-r25
    ldi r24, low(F1)
    ldi r25, high(F1)
    
loop1:
    clr count
loop2:
    out PORTC,count
    
    rcall wait_x_msec
    
    inc count
    
    cpi count,32
    breq loop1
    rjmp loop2
   
ISR0:
    push r23
    push r24
    push r25
    in r24,SREG
    push r24
    
    ; Load delay of 5ms for repeated checks
    ldi r24, low(F2)
    ldi r25, high(F2)
    
repeat:
    ldi r23,(1<<INTF0)
    out EIFR,r23
    
    rcall wait_x_msec
    
    in r23,EIFR
    sbrc r23,INTF0
    rjmp repeat
    
    ; Collect PORTB input
    ser r23
    out PORTB, r23
    in r23, PINB
    
    clr r24
        
    ; If PB0 = 1 (unpressed), skip to next
    sbrc r23,0
    rjmp second
    ori r24,1
    
second:
    sbrc r23,1
    rjmp third
    lsl r24
    ori r24,1
    
third:
    sbrc r23,2
    rjmp fourth
    lsl r24
    ori r24,1
    
fourth:
    sbrc r23,3
    rjmp finish
    lsl r24
    ori r24,1
    
    
finish:
    out PORTC, r24
    
    ldi r24,low(16*500)
    ldi r25,high(16*500)
    
    rcall wait_x_msec
    
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


