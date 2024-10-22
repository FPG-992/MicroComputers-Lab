#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

const unsigned char DC_VALUE[] = { 5, 26, 46, 66, 87, 108, 128, 148, 168, 189, 209, 230, 250 };

int main(void) {
    unsigned char index = 6;
    unsigned char status = 0x00;
    unsigned char temp;
    
    // Set TMR1A in Fast PWM 8bit mode with non-inverted output to PB1
    TCCR1A = (0<<WGM11) | (1<<WGM10) | (0<<COM1A0) | (1<<COM1A1);
    // Also load CLK/1
    TCCR1B = (0<<WGM13) | (1<<WGM12) | (0<<CS12) | (0<<CS11) | (1<<CS10);
    // Initial value at 50%
    OCR1AL = DC_VALUE[index];
    
    DDRB |= 0b00111111;
    
    // set PORTD to an input
    DDRD = 0x00;
    
    // Setup ADC
    ADMUX = (1<<REFS0);
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);
    
    sei();
    
    while (1) {
        if (status == 0xFF) {
            ADCSRA |= (1<<ADSC);
            while ((ADCSRA & (1<<ADSC)) != 0);

            unsigned int read = ADC>>2;
            OCR1AL = read;
        } else {
            temp = PIND;
            if ((temp & (1<<PIND3)) == 0) {
                _delay_ms(5);
                while ((PIND & (1<<PIND3)) == 0) {
                    _delay_ms(5);
                }
                if (index < 12) {
                    index++;
                    OCR1AL = DC_VALUE[index];
                }
            } else if ((temp & (1<<PIND4)) == 0) {
                _delay_ms(5);
                while ((PIND & (1<<PIND4)) == 0) {
                    _delay_ms(5);
                }
                if (index > 0) {
                    index--;
                    OCR1AL = DC_VALUE[index];
                }
            }
        }
        temp = PIND;
        if ((temp & (1<<PIND6)) == 0) {
            _delay_ms(5);
            while ((PIND & (1<<PIND6)) == 0) {
                _delay_ms(5);
            }
            status = 0x00;
            OCR1AL = DC_VALUE[index];
        } else if ((temp & (1<<PIND7)) == 0) {
            _delay_ms(5);
            while ((PIND & (1<<PIND7)) == 0) {
                _delay_ms(5);
            }
            status = 0xFF;
        }
    }
}
