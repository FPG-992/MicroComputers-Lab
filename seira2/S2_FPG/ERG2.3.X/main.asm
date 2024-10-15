.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=5000
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms

.def leds = r21

.org 0x0
    rjmp reset
    
.org 0x4
    rjmp ISR1
    
reset:
; Init Stack Pointer
ldi r24, LOW(RAMEND)
out SPL, r24
ldi r24, HIGH(RAMEND)
out SPH, r24    

; Init PORTB as output
ser r20
out DDRB, r20

;interrupt on rising edge of INT1 pin
ldi r24, (1<<ISC11) | (1<<ISC10)
sts EICRA, r24

;enable INT1 interrupt (EXTERNAL!!!)
ldi r24, (1<<INT1)
out EIMSK, r24

sei ;enable global interrupts

Main_Loop:
clr leds
out PORTB, leds
rjmp Main_Loop


isr1:
push r23
push r24
push r25

in r25, SREG
push r25 ; save r23, r24, 25, SREG to stack

;code to solve the debouncing issue for the button
debouncing:
ldi r24, (1 << INTF1) ; Clear INT F1 flag
out EIFR, r24

;DELAY 5MS
ldi r24, low(F2) ; Set delay (number of cycles)
ldi r25, high(F2)

rcall wait_x_msec
;END OF DELAY

in r17, EIFR    ; Read EIFR
sbrc r17, INTF1  ; Check if INTF1 is set
rjmp debouncing  ; If not, jump to debouncing

;=Main program starts here=
ldi leds, 0x01 ;LOAD VALUE FOR PB0
out PORTB, leds ;FLASH LEDS

;DELAY 5000MS
ldi r24, low(F1) ; Set delay (number of cycles)
ldi r25, high(F1)
rcall wait_x_msec   ;END OF DELAY

ldi leds, 0x00 ;LOAD VALUE FOR ALL LEDS OFF
out PORTB, leds ;TURN OFF LEDS


;=Main program ends here=

pop r25
out SREG, r25
pop r25
pop r24
pop r23 ; Retrieve r23, r24, 25, SREG from stack

reti

;==== SECOND DELAY FUNCTION STARTS HERE ====

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

;==== SECOND DELAY FUNCTION ENDS HERE ====