.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=10
.equ F1=FOSC_MHZ*DEL_mS

.def DC_VALUE=r20
.def TablePointer=r21

.DutyCycleTable: .DB 5, 26, 46, 66, 87, 108, 128, 148, 168, 189, 209, 230, 250, 0 

.org 0x0 ; Start the code at address 0x0
    rjmp reset ; Jump to the reset label


reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24

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

    ; Set the initial duty cycle to 50% which is in the 6th position of the table (128)
    ldi TablePointer, 6
    ldi XL, LOW(DutyCycleTable*2) ; Load the low byte of the table address into XL (etsi gia allagh)
    ldi XH, HIGH(DutyCycleTable*2) ; Load the high byte of the table address into XH (16bit pair register X )
    add XL, TablePointer
    adc XH, r16
    lpm DC_VALUE, X ; Load the value pointed by X from the table into DC_VALUE
    STS OCR1A, DC_VALUE ; Store the value of DC_VALUE to OCR1A


main:

    in r24,PIND ;get input to check if PD3 or PD4 is pressed

    cpi r24,0b00001000
    breq DT_increase

    cpi r24,0b00010000
    breq DT_decrease

    rjmp main

DT_increase:
    ;debouncing solution
    rcall wait_x_msec
    in r24, PIND 
    cpi r24, 0xFF ;are all buttons unpressed?
    brne DT_increase ;if not, then we have a bounce, so we ignore the press and check again
    
    cpi DC_VALUE, 250 ; Check if the duty cycle is at 98%
    breq main ; If it is, do nothing

    inc TablePointer
    ldi XL, LOW(DutyCycleTable*2) ; Load the low byte of the table address into XL
    ldi XH, HIGH(DutyCycleTable*2) ; Load the high byte of the table address into XH
    add XL, TablePointer
    adc XH, r16
    lpm DC_VALUE, X ; Load the value pointed by X from the table into DC_VALUE
    STS OCR1A, DC_VALUE ; Store the value of DC_VALUE to OCR1A

    rjmp main

DT_decrease:
    ; we implement a solution for debouncing
    rcall wait_x_msec
    in r24, PIND 
    cpi r24, 0xFF ;are all buttons unpressed?
    brne DT_decrease ;if not, then we have a bounce, so we ignore the press and check again

    cpi DC_VALUE, 5 ; Check if the duty cycle is at 2%
    breq main ; If it is, do nothing

    dec TablePointer
    ldi XL, LOW(DutyCycleTable*2) ; Load the low byte of the table address into XL
    ldi XH, HIGH(DutyCycleTable*2) ; Load the high byte of the table address into XH
    add XL, TablePointer
    adc XH, r16
    lpm DC_VALUE, X ; Load the value pointed by X from the table into DC_VALUE
    STS OCR1A, DC_VALUE ; Store the value of DC_VALUE to OCR1A

    rjmp main

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

;Exercise instructions + useful information
;pd3 increases by 8%
;pd4 decreases by 8%
;max DT is 98% and min DT is 2%
;as per instructions TOP value is 0x00FF which is 255 and BOTTOM=0x0000 which is 0
; X%/100 * TOP = DC_VALUE in table
;The .DB directive is used to initialize a table of constant values that the program can easily reference. 
;These constants represent specific OCR1A register values that will control the PWM duty cycle. 
;Each value in the table corresponds to a different percentage of the duty cycle for the PWM signal.
;DutyCycleTable*2?: It’s because the AVR microcontroller uses word-addressed memory in flash, but the data in the DutyCycleTable is stored as bytes. 
;To access the correct byte, we need to double the table’s base address, since each word consists of two bytes.
;Registers R26 through R31 have some added functions to their general-purpose usage. 
;These registers are 16-bit address pointers for indirect addressing of the data space. 
;The three indirect address registers (X, Y, and Z) are defined as described in the accompanying figure.
;XH XL, ZH ZL , YH YL