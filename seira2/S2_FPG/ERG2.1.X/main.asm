.include "m328PBdef.inc"      ; ATmega328P microcontroller definitions

.equ FOSC_MHZ=16              ; Microcontroller operating frequency in MHz

.equ DEL_mS=500              ; Delay in mS (valid number from 1 to 4095)

.equ DEL_NU=FOSC_MHZ*DEL_mS   ; Delay_mS routine: (1000*DEL_NU+6) cycles

.def counter = r30

.org 0x0 ; Start the code at address 0x0
rjmp reset

.org 0x4 ; Interrupt vector for INT1
rjmp isr1

reset:
; Init Stack Pointer
ldi r24, LOW(RAMEND)
ldi r24, HIGH(RAMEND)
out SPL, r24
out SPH, r24

; Init PORTB as output
ldi r26, 0xFF
out DDRB, r26

; Init port D as input
ldi r26, 0x00
out DDRD, r26

; Init port c as output
ldi r26, 0xFF
out DDRC, r26

;interrupt on rising edge of INT1 pin

ldi r24, (1<<ISC11) | (1<<ISC10)
sts EICRA, r24

;enable INT1 interrupt (EXETERNAL!!!)
ldi r24, (1<<INT1)
out EIMSK, r24

sei ;enable global interrupts

out PORTC, counter ;show counter in leds

;==== Delay FUNCTION STARTS HERE ====

loop1:
clr r26
loop2:
out PORTB, r26
ldi r24, low(DEL_NU)          ; Set delay (number of cycles)
ldi r25, high(DEL_NU)
rcall delay_mS
inc r26
cpi r26, 16                   ; Compare r26 with 16
breq loop1
rjmp loop2


; Delay of 1000*F1+6 cycles (almost equal to 1000*F1 cycles)
delay_mS:
ldi r23, 249                  ; 1 cycle

loop_inn:
dec r23                       ; 1 cycle
nop                           ; 1 cycle
brne loop_inn                 ; 1 or 2 cycles
sbiw r24, 1                   ; 2 cycles
brne delay_mS                 ; 1 or 2 cycles

ret                            ; 4 cycles

==== DELAY FUNCTION ENDS HERE ====



;======
;Counts (INT1=PD3) interrupts from 0 to 63 included
;When the counter reaches 63 , counter is reseted to 0
;While PD5 is pressed, counter doesn't counter
;Interrupts in binary form in leds PC5-PC0

;external interrupt 1 service routine
isr1:

push r23
push r24
push r25

in r25, SREG
push r25 ; save r23, r24, 25, SREG to stack

;code to solve the debouncing issue for the button

;program starts here;
in r16,PIND
andi r16,0x20 ;if bit (PD5) is set dont count
breq skip_next
    
;increase count and show   
inc counter
skip_next:

;if counter becomes 63, we reset
cpi counter,63
brne skip_reset
ldi counter,0

skip_reset:
ldi r24,(1<<INTF1)
out EIFR, r24 ; Clear INTF1 flag

pop r25
out SREG, r25
pop r25
pop r24
pop r23 ; Retrieve r23, r24, 25, SREG from stack

reti

;===============
;ISR1 ENDS HERE
;===============