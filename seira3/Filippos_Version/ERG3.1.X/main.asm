.include "m328PBdef.inc"

.def DC_VALUE=r20
.def TablePointer=r21


.org 0x0 ; Start the code at address 0x0
    rjmp reset

ldi r24, (0<<WGM11) | (1<<WGM10) | (0<<COM1A0) | (1<<COM1A1) ; Fast PWM mode 8 Bit on TCCR1A
sts TCCR1A, r24 ; Store the value of r24 to TCCR1A ;PB1 Connection Non inverted pwm

ldi r24, (0<<WGM13) | (1<<WGM12) | (1<<CS12) | (0<<CS11) | (0<<CS10) ; Clock prescaler 256
sts TCCR1B, r24 ; Store the value of r24 to TCCR1B ; 16MHz / 256 = 62500Hz 

 ; Set PORTB outputs for the LEDs | PB only has 6 leds on the board
ldi r24, 0b00111111
out DDRB, r24

; Set PORTD as input for pd3 & pd4
clr r24
out DDRD,r24


;pd3 increases by 8%
;pd4 decreases by 8%
;max DT is 98% and min DT is 2%

main:

in r24,PIND ;get input to check if PD3 or PD4 is pressed

cpi r24,0b00001000
breq DT_increase

cpi r24,0b00010000
breq DT_decrease

rjmp main


reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24

