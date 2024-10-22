.include "m328PBdef.inc"
    
.def DC_VALUE=r20
.def TablePointer=r21
    
.org 0x0
    rjmp reset
    
DCtable: .DB 5, 26, 46, 66, 87, 108, 128, 148, 168, 189, 209, 230, 250, 0

reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; Set TMR1A in Fast PWM 8bit mode with non-inverted output to PB1
    ldi r24, (0<<WGM11) | (1<<WGM10) | (0<<COM1A0) | (1<<COM1A1)
    sts TCCR1A, r24
    
    ; Also load CLK/256 configuration (16MHz / 256 = 62500Hz)
    ldi r24, (0<<WGM13) | (1<<WGM12) | (1<<CS12) | (0<<CS11) | (0<<CS10)
    sts TCCR1B, r24
    
    ; Set PORTB outputs
    ldi r24, 0b00111111
    out DDRB, r24
    
    ; !TEMP!
    ser r24
    out DDRC, r24
    
    ; Set PORTD as input
    clr r24
    out DDRD,r24
    
    ; Set r16 as a zero register for adding with carry
    ldi r16, 0
    
    ; Initial DC_VALUE
    ldi TablePointer, 6
    ldi ZL, LOW(DCtable*2)    ; Possible that it needs DCtable*2
    ldi ZH, HIGH(DCtable*2)
    add ZL, TablePointer
    adc ZH, r16
    lpm DC_VALUE, Z
        
    ; Write DC_VALUE to OCR1A
    sts OCR1AL, DC_VALUE
    out PORTC, DC_VALUE
    
main:
    ; Read PORTD
    in r24, PIND
    
    ; If PD3 is pressed (PD3=0), handle increase
    sbrs r24, 3
    rjmp handleInc
    
    ; If PD4 is pressed (PD4=0), handle decrease
    sbrs r24, 4
    rjmp handleDec
    
    rjmp main
    
handleInc:
    cpi TablePointer, 12
    breq freeze
    
    inc TablePointer
    
    ldi ZL, LOW(DCtable*2)
    ldi ZH, HIGH(DCtable*2)
    add ZL, TablePointer
    adc ZH, r16
    lpm DC_VALUE, Z
    
    sts OCR1AL, DC_VALUE
    out PORTC, DC_VALUE
    
    rjmp freeze
    
handleDec:
    cpi TablePointer, 0
    breq freeze
    
    dec TablePointer
    
    ldi ZL, LOW(DCtable*2)
    ldi ZH, HIGH(DCtable*2)
    add ZL, TablePointer
    adc ZH, r16
    lpm DC_VALUE, Z
    
    sts OCR1AL, DC_VALUE
    out PORTC, DC_VALUE
    
; Freezes further execution until all PORTD buttons are unpressed
freeze:
    in r24, PIND
    
    cpi r24, 0xFF
    brne freeze
    rjmp main