.include "m328PBdef.inc"      ; ATmega328P microcontroller definitions

.equ FOSC_MHZ=16
.equ DEL_mS=500
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms
.equ DEL_NU=FOSC_MHZ*DEL_mS    ; delay_mS routine: (1000*DEL_NU+6) cycles

.def counter = r30
.def count = r26

.org 0x0 ; Start the code at address 0x0
rjmp reset

.org 0x4 ; Interrupt vector for INT1
rjmp isr1

clr counter

reset:
; Init Stack Pointer
ldi r24, LOW(RAMEND)
out SPL, r24
ldi r24, HIGH(RAMEND)
out SPH, r24

; Init Port B as output
ldi r20, 0xFF
out DDRB, r20

; Init Port D as input
ldi r20, 0x00
out DDRD, r20

; Init Port C as output
ldi r20, 0xFF
out DDRC, r20

;interrupt on rising edge of INT1 pin
ldi r24, (1<<ISC11) | (1<<ISC10)
sts EICRA, r24

;enable INT1 interrupt (EXTERNAL!!!)
ldi r24, (1<<INT1)
out EIMSK, r24

sei ;enable global interrupts

out PORTC,counter ;show counter in leds

;==== Delay FUNCTION STARTS HERE ====

loop1:
    clr count
loop2:
    out PORTB, count

    ldi r24, low(DEL_NU)          ; Set delay (number of cycles)
    ldi r25, high(DEL_NU)

    rcall delay_mS

    inc count

    cpi count, 16                   ; Compare count with 16
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

;==== DELAY FUNCTION ENDS HERE ====



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