.include "m328PBdef.inc"        ; ATmega328P microcontroller definitions

.equ FOSC_MHZ=16               ; Microcontroller operating frequency in MHz
.equ DEL_mS=20               ; Delay in mS (valid number from 1 to 4095)
.equ DEL_NU=FOSC_MHZ*DEL_mS    ; delay_mS routine: (1000*DEL_NU+6) cycles

.def counter = r30

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
ser r26
out DDRC, r26

; Init PortB as Input
clr r26
out DDRB, r26

loop1:
clr r26
loop2:
out PORTC, r26

ldi r24, low(DEL_NU)           ; Set delay (number of cycles)
ldi r25, high(DEL_NU)
rcall delay_mS

inc r26
cpi r26, 32                    ; Compare r26 with 32
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
