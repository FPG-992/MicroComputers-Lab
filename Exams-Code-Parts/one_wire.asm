one_wire_reset:

sbi DDRD, PD4 ; set PD4 as output
cbi PORTD, PD4 ;
ldi r24, low(480) ; 480 usec reset pulse
ldi r25, high(480) ;
rcall wait_usec ;
cbi DDRD, PD4 ; set PD4 as input
cbi PORTD, PD4 ; disable pull-up
ldi r24 ,100 ; wait 100 usec for connected devices
ldi r25 ,0 ; to transmit the presence pulse
rcall wait_usec ;
in r24, PIND ; read PORTD
push r24 ; save PORTD
ldi r24, low(380) ;
ldi r25, high(380) ; wait for 380 usec
rcall wait_usec ;
pop r25 ; retrieve PORTD
clr r24 ; if a connected device is
sbrs r25, PD4 ; detected(PD4=0) return 1
ldi r24 ,0x01 ; else return 0
ret

one_wire_receive_bit:
sbi DDRD, PD4 ; set PD4 as output
cbi PORTD, PD4 ;
ldi r24, 0x02 ; time slot 2 usec
ldi r25, 0x00 ;
rcall wait_usec ;
cbi DDRD, PD4 ; set PD4 as input
cbi PORTD, PD4 ; disable pull-up
ldi r24 ,10 ;
ldi r25 ,0 ; wait 10 usec
rcall wait_usec ;
clr r24 ;
sbic PIND, PD4 ; r24 = PD4
ldi r24, 1 ;
push r24
ldi r24, 49 ;
ldi r25, 0 ; delay 49 usec to meet the standards
rcall wait_usec ;
pop r24
ret

one_wire_transmit_bit:
push r24 ; save output bit
sbi DDRD, PD4 ; set PD4 as output
cbi PORTD, PD4 ;
ldi r24, 0x02 ; time slot 2 usec
ldi r25, 0x00 ;
rcall wait_usec ;
pop r24 ; retrieve output bit
sbrc r24, 0 ;
sbi PORTD, PD4 ; PD4 = r24[0]
sbrs r24, 0 ;
cbi PORTD, PD4 ;
ldi r24, 58 ; wait 58 usec for connected
ldi r25, 0 ; device to sample the line
rcall wait_usec ;
cbi DDRD, PD4 ; set PD4 as input
cbi PORTD, PD4 ; disable pull-up
ldi r24 ,0x01 ;
ldi r25 ,0x00 ; recovery time 1 usec
rcall wait_usec ;
ret

one_wire_receive_byte:
ldi r27 ,8 ; 8 repetitions
clr r26
loop_:
rcall one_wire_receive_bit ; r24[0] holds the received bit
lsr r26
sbrc r24, 0 ; logical or with 0x00 if returned bit is 0,
ldi r24 ,0x80 ; or
or r26, r24 ; with 0x80 if returned bit is 1
dec r27
brne loop_
mov r24, r26
ret

one_wire_transmit_byte:
mov r26, r24
ldi r27, 8 ; 8 repetitions
_one_more_:
clr r24 ;
sbrc r26 ,0 ; load r24[0] with the transmitted bit
ldi r24 ,0x01 ;
rcall one_wire_transmit_bit
lsr r26
dec r27
brne _one_more_
ret