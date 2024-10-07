.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=100
.equ F1=FOSC_MHZ*DEL_mS
    
    
.def TEMP=r30
.def POS=r31

ldi POS,1
    
clr temp
SER TEMP ; TEMP = 11111111
OUT DDRD,TEMP ;SET DDRD AS OUTPUT    
    
reset:
    ; Initialize Stack
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    ldi r24, low(F1)
    ldi r25, high(F1)
    
START: ;THIS IS EXECUTED ONLY ONE TIME
OUT PORTD,POS ;output position
CALL DELAY
CALL DELAY
    
RJMP TO_LEFT

TO_LEFT:
LSL POS ;SHIFT LEFT
OUT PORTD,POS ;output position
CALL DELAY ; 1s delay
CALL DELAY ; 1s delay
SBRC POS,7; SKIP IF 7NTH BIT IS 0
RJMP CHANGE_DIRECTION ;Change_direction

RJMP TO_LEFT
    
TO_RIGHT:
LSR POS ;SHIFT LEFT
OUT PORTD,POS ;output position
CALL DELAY ; 1s delay
CALL DELAY ; 1s delay
SBRC POS,0; SKIP IF 0TH BIT IS 0
RJMP CHANGE_DIRECTION ;Change_direction

RJMP TO_RIGHT


CHANGE_DIRECTION:
CALL DELAY ;1 MORE SECOND 
SBRC POS,7 ;IF 7NTH BIT IS 1
RJMP TO_RIGHT ;THEN JMP TO RIGHT
RJMP TO_LEFT 
        
    
DELAY:
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