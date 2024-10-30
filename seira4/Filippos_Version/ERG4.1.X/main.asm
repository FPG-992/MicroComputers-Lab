.include "m328PBdef.inc"

.org 0x0
    rjmp reset

.org 0x1A
    rjmp ISR_TIMER1_OVF

.org 0x2A ; ADC Conversion Complete Interrupt
    rjmp ADC_ISR
    
.def ADC_VALUE_LOW = r16
.def ADC_VALUE_HIGH = r17

reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24

main:
    ; Initialize ADC
    ldi r17,(0<<MUX3) | (0<<MUX2) | (0<<MUX1) | (1<<MUX0) | (0<<REFS1) | (1<<REFS0) ;ADC1 | AVCC with external capacitor at AREF pin
    sts ADMUX, r17
    
    ; ADEN=1 => ADC Enable, ADCS=0 => No Conversion,
    ; ADIE=0 => disable adc interrupt, ADPS[2:0]=111 => fADC=16MHz/128=125KHz | ADIE=1 => enable adc interrupt
    ; Enable ADC, enable ADC interrupt, and set prescaler to 128 (16MHz/128 = 125kHz)
    ldi r17, (1<<ADEN) | (0<<ADSC) | (1<<ADIE) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)
    sts ADCSRA, r17

    
    ; We will configure the timer for an interrupt per/ one second | prescaler 1024
    ldi r17, (1<<CS12) | (0<<CS11) | (1<<CS10) 
    sts TCCR1B, r17

    ; Enable Timer1 Overflow Interrupt | We want one interrupt each second
    ;65536-15625=49911=0xC287
    ldi r17, HIGH(49911)
    out TCNT1H, r17
    ldi r17, LOW(49911)
    out TCNT1L, r17

    ldi r24, (1<<TOIE1) ;ENABLE Interrupt Overflow Timer1 
    sts TIMSK1, r24 

    ; Enable Global Interrupts
    sei

    ; Initialize LCD
    rcall lcd_init

    
;===END OF MAIN PROGRAM=== ROUTINES START HERE===

;===ADC INTERRUPT SERVICE ROUTINE===
ISR_TIMER1_OVF: ;We start the ADC conversion and we wait for the result
    sbi ADCSRA, ADSC ; Start ADC conversion
    ldi r17, HIGH(49911)
    out TCNT1H, r17
    ldi r17, LOW(49911)
    out TCNT1L, r17
    reti

ADC_ISR: ;When the conversion is complete the interrupt brings us and we read the ADC values
    lds ADC_VALUE_LOW, ADCL
    lds ADC_VALUE_HIGH, ADCH
    
    ;Adif is set to 1 when the conversion is complete by the vector itself
    ;Until here we have: Setup the ADC, the Overflow Timer, Started the ADC conversion, Wait for the ADC conversion to complete, Read the ADC value
    ;What's left to do below is: Multiply by 5, divide by 1024, and display the result on the LCD


write_2_nibbles: 
    push r24          ; save r24(LCD_Data) 
     
    in r25 ,PIND       ; read PIND 
     
    andi r25 ,0x0f  ;  
    andi r24 ,0xf0       ; r24[3:0] Holds previus PORTD[3:0] 
    add r24 ,r25     ; r24[7:4] <-- LCD_Data_High_Byte 
    out PORTD ,r24  ; 
     
    sbi PORTD ,PD3  ; Enable  Pulse 
    nop 
    nop 
    cbi PORTD ,PD3 
     
    pop r24     ; Recover r24(LCD_Data) 
    swap r24   ; 
    andi r24 ,0xf0  ; r24[3:0] Holds previus PORTD[3:0]   
    add r24 ,r25    ; r24[7:4] <-- LCD_Data_Low_Byte 
    out PORTD ,r24 
     
    sbi PORTD ,PD3  ; Enable  Pulse 
    nop 
    nop 
    cbi PORTD ,PD3 
     
    ret

lcd_data: 
    sbi PORTD ,PD2  ; LCD_RS=1(PD2=1), Data 
    rcall write_2_nibbles     ; send data 
    ldi r24 ,250                  ; 
    ldi r25 ,0                    ; Wait 250uSec 
    rcall wait_usec 
    ret 

lcd_command: 
    cbi PORTD ,PD2         ; LCD_RS=0(PD2=0), Instruction  
    rcall write_2_nibbles    ; send Instruction 
    ldi r24 ,250                  ; 
    ldi r25 ,0                   ; Wait 250uSec 
    rcall wait_usec 
    ret 

lcd_clear_display: 
     
    ldi r24 ,0x01                ; clear display command 
    rcall lcd_command 
     
    ldi r24 ,low(5)  ; 
    ldi r25 ,high(5)  ; Wait 5 mSec 
    rcall wait_msec  ; 
     
    ret


lcd_init: 
 
    ldi r24 ,low(200)   ; 
    ldi r25 ,high(200)  ; Wait 200 mSec 
    rcall wait_msec  ; 
    
    ldi r24 ,0x30    ; command to switch to 8 bit mode 
    out PORTD ,r24  ; 
    sbi PORTD ,PD3  ; Enable  Pulse 
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250   ; 
    ldi r25 ,0   ; Wait 250uSec  
    rcall wait_usec            ; 
     
    ldi r24 ,0x30    ; command to switch to 8 bit mode 
    out PORTD ,r24  ; 
    sbi PORTD ,PD3  ; Enable  Pulse  
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250   ; 
    ldi r25 ,0   ; Wait 250uSec  
    rcall wait_usec            ; 
     
    ldi r24 ,0x30    ; command to switch to 8 bit mode 
    out PORTD ,r24  ; 
    sbi PORTD ,PD3  ; Enable  Pulse  
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250                  ; 
    ldi r25 ,0                    ; Wait 250uSec 
    rcall wait_usec 
     
    ldi r24 ,0x20                ; command to switch to 4 bit mode 
    out PORTD ,r24 
    sbi PORTD ,PD3  ; Enable  Pulse 
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250                  ; 
    ldi r25 ,0                    ; Wait 250uSec 
    rcall wait_usec 
     
    ldi r24 ,0x28              ;  5x8 dots, 2 lines 
    rcall lcd_command 
 
    ldi r24 ,0x0c                ; dislay on, cursor off 
    rcall lcd_command      
    rcall lcd_clear_display       
 
    ldi r24 ,0x06                ; Increase address, no display shift 
    rcall lcd_command         ;
    ret