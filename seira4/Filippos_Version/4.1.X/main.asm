.include "m328PBdef.inc"

.org 0x0
    rjmp reset

.org 0x1A
    rjmp ISR_TIMER1_OVF

.org 0x2A ; ADC Conversion Complete Interrupt
    rjmp ADC_ISR
    
.def ADC_VALUE_LOW = r30
.def ADC_VALUE_HIGH = r31

.equ FOSC_MHZ=16
.equ DEL_mS=1000
.equ F1=FOSC_MHZ*DEL_mS

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

    ; Set PORTD as output
    ldi r24, 0xFF
    out DDRD, r24

    
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
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23
    push r24   
    push r27
    push r28
    push r29
    push r30
    push r31

    lds ADC_VALUE_LOW, ADCL
    lds ADC_VALUE_HIGH, ADCH
    
    ;Adif is set to 1 when the conversion is complete by the vector itself
    ;Until here we have: Setup the ADC, the Overflow Timer, Started the ADC conversion, Wait for the ADC conversion to complete, Read the ADC value
    ;What's left to do below is: Multiply by 5, divide by 1024, and display the result on the LCD
    ;r31:r30 holds the ADC value r31 High Byte r30 Low Byte
    ;Multiply by 5

    mov r29, ADC_VALUE_HIGH ;r29:r28 = ADC_VALUE
    mov r28 , ADC_VALUE_LOW ;r29:r28 = ADC_VALUE

    lsl r28 ;r28=r28*2
    rol r29 ;r29=r29*2 + carry
    lsl r28 ;r28=r28*4
    rol r29 ;r29=r29*4 + carry

    add r28, r30 ;r28=r28+ADC_VALUE_LOW
    adc r29, r31 ;r29=r29+ADC_VALUE_HIGH + carry

    ;Multiplication by 5 has been done

    ;Multiplying by 8 is the same as multiplying by 2 three times
    ;So we will multiply by 2 three times
    lsl r28 ;r28=r28*2
    rol r29 ;r29=r29*2 + carry
    lsl r28 ;r28=r28*4
    rol r29 ;r29=r29*4 + carry
    lsl r28 ;r28=r28*8
    rol r29 ;r29=r29*8 + carry

    ;Multiplication by 8 has been done
    ;Now we need to multiply by 125 to get 5*8*125=5000
    ;stored in pair r29:r28
    ;we move r29 to r26 and r28 to r25 and we keep r27 for the higher byte of the result
    mov r26, r29
    mov r25, r28
    clr r27

    ldi r24, 7

    multiply_by_128_loop:
    lsl r25                 ; Shift left
    rol r26                ; Rotate through carry
    rol r27                 ; Rotate through carry
    dec r24                 ; Decrement shift counter
    brne multiply_by_128_loop ; Repeat until 7 shifts are done
    
    ; Now, r27:r26:r25 holds ADC_VALUE * 40 * 128

    ; Now we need to divide by 1024
    
    ; Initialize shift counter for division by 1024 (10 shifts)
    ldi r24, 10              ; Load immediate value 10 into r24

    divide_by_1024_loop:
    lsr r25                  ; Logical Shift Right r25
    ror r26                  ; Rotate Right r26 through carry
    ror r27                  ; Rotate Right r27 through carry
    dec r24                  ; Decrement shift counter
    brne divide_by_1024_loop ; Branch if not equal to zero
    
    clr r27                 ; Clear r27 to zero because we don't need it anymore because max value fits 2 registers

    ; Now, r26:r25 holds the result of ADC_VALUE * 40 * 128 / 1024 = ADC_VALUE * 5
    ;move the result to r11:
    mov r11, r26
    mov r10, r25

    ; Now we need to display the result on the LCD
    ; We will display the result in format x.yy
    ; We call routine to calculate the integer part of the result, and then the fractional part
    ; and then display
    ; r10:r11 holds the result
    rcall convert_and_display

    pop r31
    pop r30
    pop r29
    pop r28
    pop r27
    pop r24
    pop r23
    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
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

; === convert_and_display Routine ===
; Description:
;   - Converts a 16-bit scaled value in r11:r10 into thousands (X), hundreds (Y), tens (Z)
;     and formats it as "X.YZV" on the LCD.
; Registers Used:
;   - r16: Thousands digit (X)
;   - r17: Hundreds digit (Y)
;   - r18: Tens digit (Z)
;   - r19: Temporary for remainder
;   - r20: Temporary for calculations
;   - r21: Temporary for calculations
;   - r22: Temporary for calculations
;   - r23: Temporary for calculations
;   - r24: Holds current character to send to LCD
;   - r25: Temporary register
; Assumptions:
;   - r11:r10 contains the scaled 16-bit value (e.g., 511 represents 5.11V)
;   - lcd_data routine is available to send a single ASCII character to the LCD

convert_and_display:
    ; Preserve used registers
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23
    push r24
    push r25

    ; Initialize digit registers to 0
    clr r16        ; X = Thousands digit
    clr r17        ; Y = Hundreds digit
    clr r18        ; Z = Tens digit

    ; Load the scaled value into temporary registers
    mov r22, r11    ; High byte of scaled value
    mov r23, r10    ; Low byte of scaled value

    ; === Step 1: Extract Thousands Digit (X) ===
divide_by_1000:
    ; Compare r22:r23 with 1000 (0x03E8)
    ldi r20, 0x03       ; High byte of 1000
    ldi r21, 0xE8       ; Low byte of 1000
    cp r22, r20
    cpc r23, r21
    brlo done_divide_1000 ; If r22:r23 < 1000, skip subtraction

    ; Subtract 1000 from r22:r23
    subi r23, 0xE8        ; r23 = r23 - 0xE8
    sbci r22, 0x03        ; r22 = r22 - 0x03 - borrow
    inc r16               ; X = X + 1
    rjmp divide_by_1000    ; Repeat until r22:r23 < 1000

done_divide_1000:
    ; === Step 2: Extract Hundreds Digit (Y) ===
divide_by_100:
    ; Compare r22:r23 with 100 (0x0064)
    ldi r20, 0x00       ; High byte of 100
    ldi r21, 0x64       ; Low byte of 100
divide_hundreds_loop:
    cp r22, r20
    cpc r23, r21
    brlo done_divide_100   ; If r22:r23 < 100, skip subtraction

    ; Subtract 100 from r22:r23
    subi r23, 0x64        ; r23 = r23 - 0x64
    sbci r22, 0x00        ; r22 = r22 - 0x00 - borrow
    inc r17               ; Y = Y + 1
    rjmp divide_hundreds_loop ; Repeat until r22:r23 < 100

done_divide_100:
    ; === Step 3: Extract Tens Digit (Z) ===
divide_by_10:
    ; Compare r22:r23 with 10 (0x000A)
    ldi r20, 0x00       ; High byte of 10
    ldi r21, 0x0A       ; Low byte of 10
divide_tens_loop:
    cp r22, r20
    cpc r23, r21
    brlo done_divide_10     ; If r22:r23 < 10, skip subtraction

    ; Subtract 10 from r22:r23
    subi r23, 0x0A        ; r23 = r23 - 0x0A
    sbci r22, 0x00        ; r22 = r22 - 0x00 - borrow
    inc r18               ; Z = Z + 1
    rjmp divide_tens_loop  ; Repeat until r22:r23 < 10

done_divide_10:
    ; Now, r22:r23 holds the remainder after dividing by 10 (units digit, not used here)

    ; === Step 4: Convert Digits to ASCII ===
    ; Convert Thousands Digit (X) to ASCII
    add r16, '0'          ; X += ASCII '0'
    mov r24, r16          ; Move to r24 for lcd_data
    rcall lcd_data        ; Send 'X' to LCD

    ; Send Decimal Point '.'
    ldi r24, '.'          ; ASCII for '.'
    rcall lcd_data        ; Send '.' to LCD

    ; Convert Hundreds Digit (Y) to ASCII
    add r17, '0'          ; Y += ASCII '0'
    mov r24, r17          ; Move to r24 for lcd_data
    rcall lcd_data        ; Send 'Y' to LCD

    ; Convert Tens Digit (Z) to ASCII
    add r18, '0'          ; Z += ASCII '0'
    mov r24, r18          ; Move to r24 for lcd_data
    rcall lcd_data        ; Send 'Z' to LCD

    ; Append 'V' for Voltage
    ldi r24, 'V'          ; ASCII for 'V'
    rcall lcd_data        ; Send 'V' to LCD

    ; === Optional: Handle Units Digit if Needed ===
    ; If you want to display units (e.g., X.YZ), you can extract and display them similarly.
    ; For this implementation, only X.YZ is displayed.

    ; === Step 5: Restore Preserved Registers ===
    pop r25
    pop r24
    pop r23
    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16

    ret                   ; Return from routine


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