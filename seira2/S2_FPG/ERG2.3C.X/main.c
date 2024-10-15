#define F_CPU 16000000UL
#include<avr/io.h>
#include<avr/interrupt.h>
#include<util/delay.h>

volatile uint16_t counter = 500;
volatile uint8_t done_both = 1;
volatile uint8_t done = 1;

ISR(INT1_vect){ //external interrupt 1
    counter = 0;
    if (done==0){
        done_both=0;
    }
    done = 0;
EIFR = (1 << INTF1); // Clear the flag of interrupt INTF1


}

int main(){
    EICRA=(1<<ISC11) | (1<<ISC10); //rising edge for INT1

    EIMSK=(1<<INT1); //enable INT1 interrupt, PD3

    sei(); //enable global interrupt

    DDRB=0xFF; //PORTB as output

    PORTB=0x00; //initially all LEDs are off

    while(1){
        if (counter<500 && done_both==0){
            done_both = 0;
            if (counter<450)
            PORTB=0x3F; //turn leds (PB5 to PB0)
            _delay_ms(1);
            counter++;
            if (counter>450 && counter<499){
                PORTB=0x01; //turn on the first LED
                _delay_ms(1);
            }
            if (counter==499) {
                PORTB=0x00;
                done_both = 1;
                done = 1;
            }
            //
        } else if (counter<500 && done == 0){
            done = 0;
            _delay_ms(1);
            counter++;
            if (counter<499 && done == 0){
                PORTB=0x01;
            } else if (counter==499 && done == 0){
                PORTB=0x00;
                done = 1;
            }
            
        }
    }
}