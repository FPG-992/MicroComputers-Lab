.include "m328PBdef.inc"        ; ATmega328P microcontroller definitions

.equ FOSC_MHZ=16
.equ DEL_mS=500
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms
.equ DEL_NU=FOSC_MHZ*DEL_mS    ; delay_mS routine: (1000*DEL_NU+6) cycles

.def counter = r30
.def count = r26

.org 0x0
    rjmp reset

.org 0x2
    rjmp isr0

reset:
; Init Stack Pointer
ldi r24, LOW(RAMEND)
out SPL, r24
ldi r24, HIGH(RAMEND)
out SPH, r24

;Interrupt on rising edge of INT0 Pin
ldi r24,(1<<ISC01)|(1<<ISC00)
sts EICRA,r24

;Enable INT0 Interrupt (PD2)
ldi r24,(1<<INT0)
out EIMSK,r24

sei ;Enable Global Interrupts Flag

; Init PORTC as output
ser r20
out DDRC, r20

; Init PortB as Input
clr r20
out DDRB, r20

loop1:
clr count
loop2:
out PORTC, count

ldi r24, low(DEL_NU)           ; Set delay (number of cycles)
ldi r25, high(DEL_NU)
rcall delay_mS

inc count
cpi count, 32                    ; Compare count with 32
breq loop1
rjmp loop2

; delay of 1000*F1+6 cycles (almost equal to 1000*F1 cycles)
delay_mS:
; total delay of next 4 instruction group = 1+(249*4-1) = 996 cycles
ldi r23, 249                    ; (1 cycle)
loop_inn:
dec r23                         ; 1 cycle
nop                             ; 1 cycle
brne loop_inn                   ; 1 or 2 cycles

sbiw r24, 1                     ; 2 cycles
brne delay_mS                   ; 1 or 2 cycles

ret                             ; 4 cycles

; Interrupt Service Routine - Interrupt Vector
isr0: 
push r23
push r24
push r25
in r24, SREG
push r24

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

;Main Code
in r20,PINB ;read PORTB pins to r20

count_pins:
andi r20,0x0F ;mask the 4 LSB bits of r20

clr counter ;clear counter register
ldi r19,4

count_loop:
lsr r20 ;shift right r20
brcc count_next ; if carry is clear, jump to count_next
inc counter ;increment counter

count_next:
dec r19 ;decrement r19
brne count_loop ;if r19 is not zero, repeat count_loop


out PORTC,counter ;show counter in leds

;End Of Main Code

pop r23
pop r24
out SREG, r24
pop r25

reti

;===============
;ISR0 ENDS HERE
;===============

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