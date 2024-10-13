#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

int counter;
char update;

ISR(INT1_vect) {
//    Repeated check
//
//    do {
//        EIFR = (1<<INTF1);
//        _delay_ms(5);
//    } while ((EIFR && 1<<INTF1) != 0);
    
    if (counter != 0) {
        update = 1;
    }
    counter = 5000;
}

int main(void) {
    EICRA = (1<<ISC11)|(1<<ISC10);
    
    EIMSK = (1<<INT1);
    
    sei();
    
    DDRB = 0xFF;
    PORTB = 0x00;
    
    counter = 0;
    update = 0;
    
    while (1) {
        if (counter > 4500 && update == 1) {
            PORTC = 0xFF;
            _delay_ms(1);
            counter--;
        } else if (counter > 0) {
            PORTC = 0x01;
            _delay_ms(1);
            counter--;
        } else {
            PORTB = 0x00;
            update = 0;
        }
    }
}
