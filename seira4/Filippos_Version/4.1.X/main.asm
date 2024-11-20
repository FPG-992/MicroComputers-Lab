.include "m328PBdef.inc"

.org 0x0
    rjmp reset

.org 0x1A
    rjmp ISR_TIMER1_OVF

.org 0x2A ; ADC Conversion Complete Interrupt
    rjmp ADC_ISR
    
.def ADC_VALUE_LOW = r28
.def ADC_VALUE_HIGH = r29
.def temp = r17

.equ FOSC_MHZ=16
.equ DEL_mS=1000
.equ F1=FOSC_MHZ*DEL_mS

.equ PD0=0
.equ PD1=1
.equ PD2=2
.equ PD3=3
.equ PD4=4
.equ PD5=5
.equ PD6=6
.equ PD7=7

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
    sts TCNT1H, r17
    ldi r17, LOW(49911)
    sts TCNT1L, r17

    ldi r24, (1<<TOIE1) ;ENABLE Interrupt Overflow Timer1 
    sts TIMSK1, r24 

    ; Enable Global Interrupts
    sei

    ; Initialize LCD
    rcall lcd_init

    ; Set PORTD as output
    ldi r24, 0xFF
    out DDRD, r24

    
;===END OF MAIN PROGRAM=== ROUTINES START HERE===

;===ADC INTERRUPT SERVICE ROUTINE===
ISR_TIMER1_OVF: ;We start the ADC conversion and we wait for the result
    lds temp, ADCSRA ;
    ori temp, (1<<ADSC) ; Set ADSC flag of ADCSRA
    sts ADCSRA, temp 
    ldi r17, HIGH(49911)
    sts TCNT1H, r17
    ldi r17, LOW(49911)
    sts TCNT1L, r17
    reti

ADC_ISR: ;When the conversion is complete the interrupt brings us and we read the ADC values
    push r31
    push r30
    push r29
    push r28
    push r20
    push r21
    push r22
    push r23
    lds ADC_VALUE_LOW, ADCL
    lds ADC_VALUE_HIGH, ADCH
    
    ;Adif is set to 1 when the conversion is complete by the vector itself
    ;Until here we have: Setup the ADC, the Overflow Timer, Started the ADC conversion, Wait for the ADC conversion to complete, Read the ADC value
    ;What's left to do below is: Multiply by 5, divide by 1024, and display the result on the LCD
    
    mov r31, ADC_VALUE_HIGH ; Move the high byte of the ADC value to r31
    mov r30, ADC_VALUE_LOW ; Move the low byte of the ADC value to r30

    ; Multiply by 4

    clc
    rol r28
    rol r29
    clc
    rol r28
    rol r29
    
    ; add original value to the result to get MULTIPLY BY 5
    add r28, r30
    adc r29, r31    

    ;we have value multiplied by 5 in r28 and r29
    ;we now want to multiply by 100
    ldi r20,100
    mul r28,r20 
    mov r21,r0
    mov r22,r1
    clr r0
    clr r1
    ;we have value low_value multiplied by 100 in r21 and r22
    clr r23

    mul r29,r20
    add r22,r0
    adc r23,r1
    ;we have value high_value multiplied by 100 in r22 and r23
    ;r23:r22:r21 is the result of the multiplication by 100 of adc_value*5

    ;we now want to divide by 1024
    ldi r20,10 ;right shift 10 times

    div_loop:
        lsr r23    ; Shift MSB
        ror r22    ; Rotate into middle byte
        ror r21    ; Rotate into LSB
        dec r20    ; Decrement counter
        brne div_loop   ; If not done, loop

    ; we now have the result in r22:r21 and we want to get hundreds, tens and units

    clr r19 ;hundreds
    clr r18 ;tens
    clr r17 ;units
    
    ldi r23,low(100)
    ldi r24,high(100)
    mov r25,r21
    mov r26,r22 ;r26:r25 is the result

    div_by_100:
            
        cp r26,r24 ;compare high byte
        cpc r25,r23 ;compare low byte
        brlo div_by_10 ;if result is less than 100 then divide by 10

        ;else divide by 100
        subi r25, low(100)
        sbci r26, high(100)

        ;increment hundreds
        inc r19

        ;initiate loop
        rjmp div_by_100

    div_by_10:
        ldi r23,low(10)
        ldi r24,high(10)
        cp r26,r24 ;compare high byte
        cpc r25,r23 ;compare low byte
        brlo div_by_1 ;if result is less than 10 then divide by 1

        ;else divide by 10
        subi r25, low(10)
        sbci r26, high(10)

        ;increment tens
        inc r18

        ;initiate loop
        rjmp div_by_10

    div_by_1:
    ldi r23,low(1)
    ldi r24,high(1)

    cp r26,r24 ;compare high byte
    cpc r25,r23 ;compare low byte
    brlo display_result ;if result is less than 1 then display result

    ;else divide by 1
    subi r25, low(1)
    sbci r26, high(1)

    ;increment units
    inc r17

    ;initiate loop
    rjmp div_by_1

    display_result:
    ; Convert digits to ASCII
    ldi r23, '0'      ; ASCII value of '0' (0x30)

    add r19, r23      ; Hundreds digit to ASCII
    add r18, r23      ; Tens digit to ASCII
    add r17, r23      ; Units digit to ASCII

    mov r24, r19      ; Hundreds digit to r24
    rcall lcd_data    ; Display hundreds digit

    ldi r24, '.'      ; Display '.' character
    rcall lcd_data

    mov r24, r18      ; Tens digit to r24
    rcall lcd_data    ; Display tens digit
    
    mov r24, r17      ; Units digit to r24
    rcall lcd_data    ; Display units digit

    ; Display 'V' character
    ldi r24, 'V'
    rcall lcd_data
    
    pop r23
    pop r22
    pop r21
    pop r20
    pop r29
    pop r28
    pop r30
    pop r31

    reti

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
    rcall wait_x_msec 
    ret 

lcd_command: 
    cbi PORTD ,PD2         ; LCD_RS=0(PD2=0), Instruction  
    rcall write_2_nibbles    ; send Instruction 
    ldi r24 ,250                  ; 
    ldi r25 ,0                   ; Wait 250uSec 
    rcall wait_x_msec 
    ret 

lcd_clear_display: 
     
    ldi r24 ,0x01                ; clear display command 
    rcall lcd_command 
     
    ldi r24 ,low(5)  ; 
    ldi r25 ,high(5)  ; Wait 5 mSec 
    rcall wait_x_msec  ; 
     
    ret


lcd_init: 
 
    ldi r24 ,low(200)   ; 
    ldi r25 ,high(200)  ; Wait 200 mSec 
    rcall wait_x_msec  ; 
    
    ldi r24 ,0x30    ; command to switch to 8 bit mode 
    out PORTD ,r24  ; 
    sbi PORTD ,PD3  ; Enable  Pulse 
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250   ; 
    ldi r25 ,0   ; Wait 250uSec  
    rcall wait_x_msec            ; 
     
    ldi r24 ,0x30    ; command to switch to 8 bit mode 
    out PORTD ,r24  ; 
    sbi PORTD ,PD3  ; Enable  Pulse  
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250   ; 
    ldi r25 ,0   ; Wait 250uSec  
    rcall wait_x_msec            ; 
     
    ldi r24 ,0x30    ; command to switch to 8 bit mode 
    out PORTD ,r24  ; 
    sbi PORTD ,PD3  ; Enable  Pulse  
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250                  ; 
    ldi r25 ,0                    ; Wait 250uSec 
    rcall wait_x_msec 
     
    ldi r24 ,0x20                ; command to switch to 4 bit mode 
    out PORTD ,r24 
    sbi PORTD ,PD3  ; Enable  Pulse 
    nop 
    nop 
    cbi PORTD ,PD3 
    ldi r24 ,250                  ; 
    ldi r25 ,0                    ; Wait 250uSec 
    rcall wait_x_msec 
     
    ldi r24 ,0x28              ;  5x8 dots, 2 lines 
    rcall lcd_command 
 
    ldi r24 ,0x0c                ; dislay on, cursor off 
    rcall lcd_command      
    rcall lcd_clear_display       
 
    ldi r24 ,0x06                ; Increase address, no display shift 
    rcall lcd_command         ;
    ret

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