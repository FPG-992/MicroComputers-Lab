Ldi r16,(1<<TWINT) | (1<<TWSTA) | (1<<TWEN)
out TWCR0, r16z

Call wait1
Wait1:
in r16, TWCR0
sbrs r16, TWINT
rjmp wait1
ret

in r16, TWSR0
andi r16, 0xF8
cpi r16, START
brne ERROR

ldi r16, SLA_W
out TWDR0, r16
ldi r16, (1<<TWINT) | (1<<TWEN)
out TWCR0, r16

Call wait1

in r16, TWSR0
andi r16, 0xF8
cpi r16, MT_SLA_ACK
brne ERROR

ldi r16, DATA
out TWDR0, r16
ldi r16, (1<<TWINT) | (1<<TWEN)
out TWCR, r16

Call wait1

in r16, TWSR0
andi r16, 0xF8
cpi r16, MT_DATA_ACK
brne ERROR

ldi r16, (1<<TWINT) | (1<<TWEN) |
(1<<TWSTO)
out TWCR0, r16