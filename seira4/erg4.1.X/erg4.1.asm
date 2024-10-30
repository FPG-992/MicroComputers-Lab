.include "m328PBdef.inc"
    
.def drem16uL=r14
.def drem16uH=r15
.def dres16uL=r16
.def dres16uH=r17
.def dd16uL=r16
.def dd16uH=r17
.def dv16uL=r18
.def dv16uH=r19
.def dcnt16u=r20
    
.def BIN = r16         ; Input: 8-bit binary number
.def HUNDREDS = r17    ; Output: BCD hundreds digit
.def TENS = r18        ; Output: BCD tens digit
.def UNITS = r19       ; Output: BCD units digit
    
.equ FOSC_MHZ=16
.equ DEL_mS=1000
.equ F1=FOSC_MHZ*DEL_mS
    
.org 0x0
    rjmp reset
    
.org 0x2A
    rjmp ADC_DONE
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; PORTD as output
    ser r24
    out DDRD, r24
    
    ; Setup LCD
    rcall lcd_init
    
    ; Setup ADC
    ldi r24, (1<<REFS0) | (1<<MUX0)
    sts ADMUX, r24
    
    ldi r24, (1<<ADEN) | (1<<ADIE) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)
    sts ADCSRA, r24
    
    ; Setup wait time
    ldi r24, low(F1)
    ldi r25, high(F1)
    
    sei
main:    
    lds r20, ADCSRA
    ori r20, (1<<ADSC)
    sts ADCSRA, r20
    rcall wait_x_msec
    rjmp main
    
ADC_DONE:
    push r20
    push r21
    push r22
    push r23
    push r24
    push r25
    
    lds r28, ADCL
    lds r29, ADCH
    mov r30, r28
    mov r31, r29
    
    ; Rotate left twice to multiply by 4
    clc
    rol r28
    rol r29
    clc
    rol r28
    rol r29
    
    ; Add one
    add r28, r30
    adc r29, r31
    
    ; Copy integer part and shift right twice
    mov r30, r29
    lsr r30
    lsr r30
    
    ; Isolate decimal part
    andi r29, 0b00000011
    
    ; Multiply by 100
    ldi r20, 100
    mul r28, r20
    
    mov r21, r0
    mov r22, r1
    mul r29, r20
    
    ldi r23, 0
    
    add r22, r0
    adc r23, r1
    
    ; Divide by 1024
    ldi r20, 10
repeat:
    clc
    ror r23
    ror r22
    ror r21
    dec r20
    brne repeat
    
    ldi dv16uL, LOW(10)
    ldi dv16uH, HIGH(10)
    mov dd16uL, r21
    mov dd16uH, r22
    
    rcall div16u
    
    mov r21, dres16uL
    mov r22, drem16uL
    
    ; BCD
    mov BIN, r30
    rcall binary_to_bcd
    ori TENS, 0b00110000
    ori UNITS, 0b00110000
    
    ; Display to LCD
    rcall lcd_clear_display
    
    mov r24, UNITS
    rcall lcd_data
    
    ldi r24, '.'
    rcall lcd_data
    
    ; BCD for Decimals
    mov BIN, r21
    rcall binary_to_bcd
    ori UNITS, 0b00110000
    mov r24, UNITS
    rcall lcd_data
    
    mov BIN, r22
    rcall binary_to_bcd
    ori UNITS, 0b00110000
    mov r24, UNITS
    rcall lcd_data
    
    ldi r24, 'V'
    rcall lcd_data

    pop r25
    pop r24
    pop r23
    pop r22
    pop r21
    pop r20
    reti
    
lcd_init:
    ldi r24, low(200*16)
    ldi r25, high(200*16)
    rcall wait_x_msec
    
    ; Switch to 8bit mode
    ldi r24, 0x30
    out PORTD, r24
    sbi PORTD, 3
    nop
    nop
    cbi PORTD, 3
    ; Wait 250usec = 0.25ms -> 0.25msec * 16 = 4
    ldi r24, HIGH(4)
    ldi r25, LOW(4)
    rcall wait_x_msec
    
    ; Switch to 8bit mode
    ldi r24, 0x30
    out PORTD, r24
    sbi PORTD, 3
    nop
    nop
    cbi PORTD, 3
    ; Wait 250usec = 0.25ms -> 0.25msec * 16 = 4
    ldi r24, HIGH(4)
    ldi r25, LOW(4)
    rcall wait_x_msec
    
    ; Switch to 8bit mode
    ldi r24, 0x30
    out PORTD, r24
    sbi PORTD, 3
    nop
    nop
    cbi PORTD, 3
    ; Wait 250usec = 0.25ms -> 0.25msec * 16 = 4
    ldi r24, HIGH(4)
    ldi r25, LOW(4)
    rcall wait_x_msec
    
    ; Switch to 4bit mode
    ldi r24, 0x20
    out PORTD, r24
    sbi PORTD, 3
    nop
    nop
    cbi PORTD, 3
    ; Wait 250usec = 0.25ms -> 0.25msec * 16 = 4
    ldi r24, HIGH(4)
    ldi r25, LOW(4)
    rcall wait_x_msec
    
    ; 5x8 dots, 2 lines
    ldi r24, 0x28
    rcall lcd_command
    
    ldi r24, 0x0c
    rcall lcd_command
    
    rcall lcd_clear_display
    
    ; Increase address, no display shift
    ldi r24, 0x06
    rcall lcd_command
    
    ret
    
    
lcd_clear_display:
    ldi r24, 0x01
    rcall lcd_command
    
    ldi r24, low(5*16)
    ldi r25, high(5*16)
    rcall wait_x_msec
    
    ret
    
lcd_data:
    sbi PORTD, 2	    ; LCD_RS=1(PD2=1), Data
    rcall write_2_nibbles   ; send data
    ; Wait 250usec = 0.25ms -> 0.25msec * 16 = 4
    ldi r24, HIGH(4)
    ldi r25, LOW(4)
    rcall wait_x_msec
    ret
    
lcd_command:
    cbi PORTD, 2	    ; LCD_RS=1(PD2=1), Data
    rcall write_2_nibbles   ; send data
    ; Wait 250usec = 0.25ms -> 0.25msec * 16 = 4
    ldi r24, HIGH(4)
    ldi r25, LOW(4)
    rcall wait_x_msec
    ret
    
write_2_nibbles:
    push r24
    
    in r25, PIND
    andi r25, 0x0F
    andi r24, 0xF0
    add r24, r25
    out PORTD, r24
    
    sbi PORTD, 3
    nop
    nop
    cbi PORTD, 3
    
    pop r24
    swap r24
    
    andi r24, 0xF0
    add r24, r25
    out PORTD, r24
    
    sbi PORTD, 3
    nop
    nop
    cbi PORTD, 3
    
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

div16u:	clr	drem16uL	;clear remainder Low byte
	sub	drem16uH,drem16uH;clear remainder High byte and carry
	ldi	dcnt16u,17	;init loop counter
d16u_1:	rol	dd16uL		;shift left dividend
	rol	dd16uH
	dec	dcnt16u		;decrement counter
	brne	d16u_2		;if done
	ret			;    return
d16u_2:	rol	drem16uL	;shift dividend into remainder
	rol	drem16uH
	sub	drem16uL,dv16uL	;remainder = remainder - divisor
	sbc	drem16uH,dv16uH	;
	brcc	d16u_3		;if result negative
	add	drem16uL,dv16uL	;    restore remainder
	adc	drem16uH,dv16uH
	clc			;    clear carry to be shifted into result
	rjmp	d16u_1		;else
d16u_3:	sec			;    set carry to be shifted into result
	rjmp	d16u_1

binary_to_bcd:
    ; Clear result registers
    clr HUNDREDS        ; Clear hundreds place
    clr TENS            ; Clear tens place
    clr UNITS           ; Clear units place

    ; Step 1: Extract Hundreds Digit
    ldi r20, 100        ; Load divisor (100)
loop_hundreds:
    cp BIN, r20         ; Compare BIN to 100
    brlo done_hundreds  ; If BIN < 100, skip to next step
    sub BIN, r20        ; BIN -= 100
    inc HUNDREDS        ; Increment hundreds digit
    rjmp loop_hundreds  ; Repeat until BIN < 100
done_hundreds:
    ; Step 2: Extract Tens Digit
    ldi r20, 10         ; Load divisor (10)
loop_tens:
    cp BIN, r20         ; Compare BIN to 10
    brlo done_tens      ; If BIN < 10, skip to next step
    sub BIN, r20        ; BIN -= 10
    inc TENS            ; Increment tens digit
    rjmp loop_tens      ; Repeat until BIN < 10
done_tens:
    ; Step 3: The remaining value in BIN is the Units Digit
    mov UNITS, BIN      ; Store remaining BIN value in UNITS

    ret                 ; Return with HUNDREDS, TENS, UNITS containing BCD digits