===============================
Από keypad 4x4,εισάγεται αριθμός χ ανήκει (0-D).Έξοδος στο PORTB,αν 0<=x<=4 ανάβουν τα bit 0-3 και εμφανίζει στην οθόνη LCD "BIT03",
αν 5<=x<=9 ανάβει led 4-7 και εμφανίζει στην LCD "BIT47".Όταν 10<=x<=13 ολα τα led αναβοσβήνουν με ορατό ρυθμό και εμφανίζεται στη LCD "EKTOS".
===============================



	.include "m16def.inc"	

	; arxh tmhmatos dedomenwn
	.DSEG
	_tmp_: .byte 2

	; arxh tmhmatos kwdika

	.CSEG

	ldi r26, low(RAMEND)	 ;stack pointer			
	out SPL, r26						
	ldi r26, high(RAMEND)
	out SPH, r26
	
	ser r24
	out DDRB,r24
			
	ldi r24 ,252
	out DDRD, r24
	ldi r18,'0'

	ldi r24 ,(1 << PC7) | (1 << PC6) | (1 << PC5) | (1 << PC4) ; 8etei ws e3odous ta 4 MSB
	out DDRC ,r24 			; ths 8uras PORTC

	                        ;katagrafoume tous diakoptes pou exoun molis piestei
	ldi r26 ,low(_tmp_) 	; fortwse thn katastash twn diakoptwn sthn
	ldi r27 ,high(_tmp_) 	; prohgoumenh klhsh ths routinas stous r27:r26
	ldi r24 ,0x00
	ldi r25 ,0x00
	adiw r26,1
	st X ,r24 				; apo8hkeuse sth RAM th nea katastash
	st -X ,r25 				; twn diakoptwn
	rcall lcd_init
	clr r19
start:
	ldi r24,20
	rcall scan_keypad_rising_edge
	cpi r24,0x00
	brne cont
	cpi r25,0x00
	breq start

cont:
	rcall keypad_to_hex
	cpi r24,5
	brlo first_case
	cpi r24,10
	brlo second_case
	cpi r24,14
	brlo third_case
	jmp start

first_case:
	ldi r20,0x0F
	out PORTB,r20
	rcall lcd_init
	ldi r24,'B'
	rcall lcd_data
	ldi r24,'I'
	rcall lcd_data
	ldi r24,'T'
	rcall lcd_data
	ldi r24,'0'
	rcall lcd_data
	ldi r24,'3'
	rcall lcd_data
	jmp start


second_case:
	ldi r20,0xF0
	out PORTB,r20
	rcall lcd_init
	ldi r24,'B'
	rcall lcd_data
	ldi r24,'I'
	rcall lcd_data
	ldi r24,'T'
	rcall lcd_data
	ldi r24,'4'
	rcall lcd_data
	ldi r24,'7'
	rcall lcd_data
	jmp start

third_case:
	rcall lcd_init
	ldi r24,'E'
	rcall lcd_data
	ldi r24,'K'
	rcall lcd_data
	ldi r24,'T'
	rcall lcd_data
	ldi r24,'0'
	rcall lcd_data
	ldi r24,'S'
	rcall lcd_data

		on_off:
		ldi r24 ,low(400)				;anavosvhne ta leds sunexeia. 
		ldi r25 ,high(400)
		ser r21
		out PORTB,r21
		rcall wait_msec                 ; 0,4 sec anammena
		ldi r24 ,100                    ; 0,1 sec svhsta
		ldi r25 ,0
		clr r21
		out PORTB,r21
		rcall wait_msec
		rjmp on_off	




first:
	ldi r24,20
	rcall scan_keypad_rising_edge  ;elegxos tou plhktrologiou gia diakoptes pou den htan piesmenoi
	cpi r24,0x00                   ;thn teleutaia fora pou klh8hke h rourina kai twra einai
	brne cont              
	cpi r25,0x00              
	breq first                    ;an den exoume parei kati apo to plhktrologio perimenoume
cont:
	rcall keypad_to_hex          ;epistrefei th 16dikh timh twn pshfiwn
	mov r16,r24
	swap r16                     ;vazoume ta shmantika pshfia stis 4 ARISTEROTERES 8eseis
second:
	ldi r24,20
	rcall scan_keypad_rising_edge
	cpi r24,0x00              
	brne cont2              
	cpi r25,0x00              
	breq second
cont2:
	rcall keypad_to_hex
	add r16,r24
third:
	ldi r24,20
	rcall scan_keypad_rising_edge
	cpi r24,0x00              
	brne cont3              
	cpi r25,0x00              
	breq third
cont3:
	rcall keypad_to_hex
	mov r17,r24
	swap r17
fourth:
	ldi r24,20
	rcall scan_keypad_rising_edge
	cpi r24,0x00              
	brne cont4              
	cpi r25,0x00              
	breq fourth
cont4:
	rcall keypad_to_hex
	add r17,r24	
mov r25,r16
mov r24,r17

	
	cpi r25,0x80
	brne device_found
	cpi r24,0x00
	breq no_device

wait_forever:
	rjmp wait_forever



device_found:
	cpi r25,0xff
	breq negative
	rjmp positive

no_device:
	ldi r24,'N'
	rcall lcd_data
	ldi r24,'O'
	rcall lcd_data
	ldi r24,' '
	rcall lcd_data
	ldi r24,'D'
	rcall lcd_data
	ldi r24,'e'
	rcall lcd_data
	ldi r24,'v'
	rcall lcd_data
	ldi r24,'i'
	rcall lcd_data
	ldi r24,'c'
	rcall lcd_data
	ldi r24,'e'
	rcall lcd_data
	rjmp wait_forever


printed_number:
	cpi r19,0x01
	brne rest
	ldi r24,'.'
	rcall lcd_data
	ldi r24,'5'
	rcall lcd_data
rest:	
	ldi r24,0xb2			; BATHMOI (MIKRO o)
	rcall lcd_data
	ldi r24,'C'
	rcall lcd_data
	rjmp wait_forever


negative:
	neg r24
	lsr r24
	adc r19,r19
	mov r20,r24
	rcall convert_bcd
	add r22,r18
	add r23,r18			; GIA NA GINEI ASCII !!!!!
	add r20,r18
	ldi r24, '-'
	rcall lcd_data
	cpi r22,'0'
	breq skip_hund
	mov r24,r22
	rcall lcd_data
	rjmp print_rest_h 
skip_hund:	
	cpi r23, '0'      ;elegxoume an oi dekades einai mhden
	breq skip_ten
	mov r24,r23
	rcall lcd_data
skip_ten:
	mov r24,r20
	rcall lcd_data	
	rjmp printed_number

print_rest_h:
	mov r24,r23
	rcall lcd_data
	mov r24,r20
	rcall lcd_data
	rjmp printed_number

positive:
	cpi r24,0x00
	breq print_zero
	lsr r24
	adc r19,r19
	mov r20,r24
	rcall convert_bcd
	add r22,r18           ;pros8etontas to '0' kratame telika
	add r23,r18           ;tous xarakthres pou antistoixoun sta pshfia
	add r20,r18
	ldi r24, '+'
	rcall lcd_data
	cpi r22,'0'           ;elegxoume an to ari8mos periexei ekatontades
	breq skip_hund
	mov r24,r22           ;an nai, tis ektupwnoume
	rcall lcd_data
	rjmp print_rest_h     ;pame sthn antistoixh etiketa gia ektupwsh twn upoloipwn
	
print_zero:
	ldi r24,'0'
	rcall lcd_data
	rjmp printed_number



convert_bcd:				; r22 = EKATONTADES , r23 = DEKADES, r20 = MONADES
	ldi r23,0
	ldi r22,0
count_hund:
	subi r20,100
	brcs counted_hund
	inc r22
	rjmp count_hund	
counted_hund:
	subi r20,-100	
count_dec:
	subi r20,10
	brcs count_mon
	inc r23
	rjmp count_dec

count_mon:
	subi r20,-10
ret



write_2_nibbles:
push r24 				; stelnei ta 4 MSB
in r25 ,PIND 			; diavazontai ta LSB kai ta 3anastelnoume
andi r25 ,0x0f 			; gia na mh xalasoume thn opoia prohgoumenh katastash
andi r24 ,0xf0 			; apomonwnntai ta 4 MSB kai
add r24 ,r25 			; sunduazontai me ta proyparxonta 4 LSB
out PORTD ,r24 			; kai dinontai sthn e3odo
 sbi PORTD ,PD3 		; dhmiourgeitai palmos Enable ston akrodekth PD3
cbi PORTD ,PD3 			; PD3=1 kai meta PD3=0
pop r24					; stelnei ta 4 LSB. Anaktatai to byte.
 swap r24 				; enallassontai ta 4 MSB me ta 4 LSB
andi r24 ,0xf0 			; pou me th seira tous apostellontai
add r24 ,r25
out PORTD ,r24
 sbi PORTD ,PD3 		; Neos palmos Enable
cbi PORTD ,PD3
ret

lcd_data:
sbi PORTD ,PD2 			; epilogh tou kataxwrhth dedomenwn (PD2=1)
rcall write_2_nibbles 	; apostolh tou  byte
ldi r24 ,43 			; anamonh 43µsec mexri na oloklhrw8ei h lhpsh
ldi r25 ,0 				; twn dedomenwn apo ton elegkth ths lcd
rcall wait_usec
ret

lcd_command:
cbi PORTD ,PD2 			; epilogh tou kataxwrhth entolwn (PD2=1)
rcall write_2_nibbles 	; apostolh ths entolhs kai anamonh 39µsec
ldi r24 ,39 			; gia thn oloklhrwsh ths ekteleshs ths apo ton elegkth ths lcd.
ldi r25 ,0 				; SHM: uparxoun 2 entoles, oi clear display kai return home,
rcall wait_usec 		; pou apaitoun shmantika megalutero xroniko diasthma.
ret

lcd_init:
ldi r24 ,40 			; Otan o elegkths ths lcd trofodoteitai me
ldi r25 ,0 				; reuma ektelei th dikh tou arxikopoihsh
rcall wait_msec 		; Anamonh 40msec mexri auth na oloklhrw8ei.

ldi r24 ,0x30 			; entolh metavashs se 8 bit mode
out PORTD ,r24 			; epeidi den mporoume na eimaste vevaioi
 sbi PORTD ,PD3 		; gia th diamorfwsh eisodou tou elegkth
cbi PORTD ,PD3 			; ths o8onhs, h entolh apostelletai 2 fores
ldi r24 ,39
ldi r25 ,0 				; ean o elegkths ths o8onhs vrisketai se 8-bit mode
rcall wait_usec 		; de 8a sumvei tipota, alla an o elegkths exei diamorfwsh
 						; eisodou 4 bit 8a metavei se diamorfwsh 8 bit
 ldi r24 ,0x30
out PORTD ,r24
 sbi PORTD ,PD3
cbi PORTD ,PD3
ldi r24 ,39
ldi r25 ,0
rcall wait_usec
ldi r24 ,0x20 			; allagh se 4-bit mode
out PORTD ,r24
 sbi PORTD ,PD3
cbi PORTD ,PD3
ldi r24 ,39
ldi r25 ,0
rcall wait_usec
 ldi r24 ,0x28 			; epilogh xarakthrwn mege8ous 5x8 koukidwn
 rcall lcd_command 		; kai emfanish 2 grammwn sthn o8onh
ldi r24 ,0x0c 			; energopoihsh ths o8onhs, apokrypsh tou kersora
 rcall lcd_command
 ldi r24 ,0x01 			; ka8arismos ths o8onhs
rcall lcd_command
ldi r24 ,low(1530)
ldi r25 ,high(1530)
rcall wait_usec
 ldi r24 ,0x06 			; energopoihsh automaths ay3hshs kata 1 ths dieu8unshs
rcall lcd_command 		; pou einai apo8hkeumenh ston metrhth dieu8unsewn kai 
 						; apenergopoihsh ths olis8hshs oloklhrhs ths o8onhs
ret

scan_row:
 ldi r25 , 0x08 		; a?????p???s? µe ‘0000 1000’
back_: lsl r25 			; a??ste?? ???s??s? t?? ‘1’ t?se? ??se??
dec r24 				; ?s?? e??a? ? a???µ?? t?? ??aµµ??
 brne back_
out PORTC , r25 		; ? a?t?st???? ??aµµ? t??eta? st? ?????? ‘1’
nop
nop 					; ?a??st???s? ??a ?a p????ße? ?a ???e? ? a??a?? ?at?stas??
in r24 , PINC 			; ep?st??f??? ?? ??se?? (st??e?) t?? d?a??pt?? p?? e??a? p?esµ????
andi r24 ,0x0f 			; ap?µ??????ta? ta 4 LSB ?p?? ta ‘1’ de?????? p?? e??a? pat?µ????
ret 					; ?? d?a??pte?.

scan_keypad:
ldi r24 , 0x01 			; ??e??e t?? p??t? ??aµµ? t?? p???t????????
rcall scan_row 
swap r24 				; ap????e?se t? ap?t??esµa
mov r27 , r24 			; sta 4 msb t?? r27
ldi r24 ,0x02 			; ??e??e t? de?te?? ??aµµ? t?? p???t????????
rcall scan_row
add r27 , r24 			; ap????e?se t? ap?t??esµa sta 4 lsb t?? r27
ldi r24 , 0x03 			; ??e??e t?? t??t? ??aµµ? t?? p???t????????
rcall scan_row
swap r24 				; ap????e?se t? ap?t??esµa
mov r26 , r24 			; sta 4 msb t?? r26
ldi r24 ,0x04 			; ??e??e t?? t?ta?t? ??aµµ? t?? p???t????????
rcall scan_row
add r26 , r24 			; ap????e?se t? ap?t??esµa sta 4 lsb t?? r26
movw r24 , r26 			; µet?fe?e t? ap?t??esµa st??? ?ata????t?? r25:r24
ret

scan_keypad_rising_edge:
mov r22 ,r24 			; ap????e?se t? ????? sp??????sµ?? st?? r22
rcall scan_keypad 		; ??e??e t? p???t??????? ??a p?esµ????? d?a??pte? 
push r24 				; ?a? ap????e?se t? ap?t??esµa
push r25
mov r24 ,r22 			; ?a??st???se r22 ms (t?p???? t?µ?? 10-20 msec p?? ?a?????eta? ap? t??
ldi r25 ,0 				; ?atas?e?ast? t?? p???t???????? – ?????d????e?a sp??????sµ??)
rcall wait_msec
rcall scan_keypad 		; ??e??e t? p???t??????? ?a?? ?a? ap?????e
pop r23 				; ?sa p???t?a eµfa?????? sp??????sµ?
pop r22
and r24 ,r22
and r25 ,r23
ldi r26 ,low(_tmp_) 	; f??t?se t?? ?at?stas? t?? d?a??pt?? st??
ldi r27 ,high(_tmp_) 	; p??????µe?? ???s? t?? ???t??a? st??? r27:r26
ld r23 ,X+
ld r22 ,X
st X ,r24 				; ap????e?se st? RAM t? ??a ?at?stas?
st -X ,r25 				; t?? d?a??pt??
com r23
com r22 				; ß?e? t??? d?a??pte? p?? ????? «µ????» pat??e?
and r24 ,r22
and r25 ,r23
ret

keypad_to_hex:  ;logiko 1 stis 8eseis tou kataxwrhth r26 dhlwnoun
movw r26 ,r24   ; ta parakatw sumvola kai ari8mous
ldi r24 ,0x0E  
sbrc r26 ,0
ret
ldi r24 ,0x00
sbrc r26 ,1
ret
ldi r24 ,0x0F
sbrc r26 ,2
ret
ldi r24 ,0x0D
sbrc r26 ,3 ; an den einai 1 parakamptei thn ret, alliws (an einai ‘1’)
ret         ; epistrefei me ton kataxwrhth r24 thn ASCII timh tou D
ldi r24 ,0x07
sbrc r26 ,4
ret
ldi r24 ,0x08
sbrc r26 ,5
ret
ldi r24 ,0x09
sbrc r26 ,6
ret
ldi r24 ,0x0C
sbrc r26 ,7
 ret
ldi r24 ,0x04 ; logiko 1 stis 8eseis tou kataxwrhth r27 dhlwnoun
sbrc r27 ,0 ; ta parakatw sumvola kai ari8mous
ret
ldi r24 ,0x05
sbrc r27 ,1
ret
ldi r24 ,0x06
sbrc r27 ,2
ret
ldi r24 ,0x0B
sbrc r27 ,3
ret
ldi r24 ,0x01
sbrc r27 ,4
ret
ldi r24 ,0x02
sbrc r27 ,5
ret
ldi r24 ,0x03
sbrc r27 ,6
ret
ldi r24 ,0x0A
sbrc r27 ,7
ret
clr r24
ret

wait_msec:							

    push r24                        

    push r25                        

    ldi r24 , low(998) 	        	

    ldi r25 , high(998)	      	    

    rcall wait_usec   	        	

    pop r25           	            

    pop r24           	            

    sbiw r24 , 1      	  	        

    brne wait_msec    	        	

ret                                 





wait_usec:  			            

    sbiw r24 ,1  	   	            

    nop       	          	        

    nop      	           	        

    nop       	           	        

    nop       	          	        

    brne wait_usec 	                

ret         	     

