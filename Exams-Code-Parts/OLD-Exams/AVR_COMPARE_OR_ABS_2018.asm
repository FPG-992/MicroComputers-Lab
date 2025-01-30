.include "m16def.inc"
reset:
		ldi r24 , low(RAMEND)	; initialize stack pointer
		out SPL , r24
		ldi r24 , high(RAMEND)
		out SPH , r24

		clr r24			; r24 = 00
		out DDRB , r24	;initialize PINB for input
		clr r24
		out DDRC , r24	;initialize PINC for input
		ser r24
		out DDRD, r24
start_p:
		ldi r24,0x00
		out PORTD,r24

		in r28,PINB
		andi r28,0x00
		cpi r28,0x00
		breq absol
comp:
		in r27,PINC
		mov r26,r27
		andi r26,0x0F
		andi r27,0xF0
		lsr r27
		lsr r27
		lsr r27
		lsr r27
		cp r26,r27
		brcs big_27
big_26:
		mov r25,r26
		out PORTD,r25		
		jmp start_p
big_27:
		mov r25,r27
		out PORTD,r25
		jmp start_p

absol:
		in r27,PINC
		mov r26,r27
		andi r26,0x0F
		andi r27,0xF0
		lsr r27
		lsr r27
		lsr r27
		lsr r27
		cp r26,r27
		brcs case_a
case_b:
		sub r26,r27
		out PORTD,r26
		jmp start_p
case_a:
		sub r27,r26
		out PORTD,r26				
		jmp start_p