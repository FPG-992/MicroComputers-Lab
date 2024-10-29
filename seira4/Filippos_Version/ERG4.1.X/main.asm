.include "m328PBdef.inc"

.org 0x0
    rjmp reset

.org 0x2A ;ADC Conversion Complete Interrupt
    reti
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24

main:
    ; Initialize ADC
    ldi r17,(0<<MUX3) | (0<<MUX2) | (0<<MUX1) | (1<<MUX0) | (0<<REFS1) | (1<<REFS0) ;ADC1 | AVCC with external capacitor at AREF pin
    sts ADMUX, r17
    
    ; ADEN=1 => ADC Enable, ADCS=0 => No Conversion,
    ; ADIE=0 => disable adc interrupt, ADPS[2:0]=111 => fADC=16MHz/128=125KHz
    ldi r17, (1<<ADEN) | (0<<ADSC) | (0<<ADIE) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0) 
    sts ADCSRA, r17
    
    ; We will configure the timer for an interrupt per/ one second 
    ldi r17, (1<<CS12) | (0<<CS11) | (1<<CS10) 
    sts TCCR1B, r17


;to afinw edw gia xrisi meta, thelei metatropes
Start_conv:
lds temp, ADCSRA ;
ori temp, (1<<ADSC) sts ADCSRA, temp ;
; Set ADSC flag of ADCSRA
wait_adc:
lds temp, ADCSRA ;
sbrc temp,ADSC rjmp wait_adc ;
; Wait until ADSC flag of ADCSRA becomes 0
lds ADC_L,ADCL lds ADC_H,ADCH ;
; Read ADC result(Left adjusted)
out PORTD, ADC_H ; Output ADCH to PORTD
rjmp Start_conv