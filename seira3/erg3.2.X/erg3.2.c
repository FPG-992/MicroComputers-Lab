#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

const unsigned char DC_VALUE[] = { 5, 26, 46, 66, 87, 108, 128, 148, 168, 189, 209, 230, 250 };
unsigned int PREV[16] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
unsigned char PREV_INDEX = 0;
unsigned int sum = 0;

ISR(TIMER3_COMPA_vect) {
    ADCSRA |= (1<<ADSC);
    while ((ADCSRA & (1<<ADSC)) != 0);
    
    unsigned int read = ADC;
    
    sum += read;
    sum -= PREV[PREV_INDEX];
    PREV[PREV_INDEX] = read;
    PREV_INDEX++;
    if (PREV_INDEX == 16)
        PREV_INDEX = 0;
    
    read = sum>>4;
    
    unsigned char temp = 0b11000000;
    
    if (read >= 0 && read <= 200) {
        temp |= 1;
    }
    if (read >= 200 && read <= 400) {
        temp |= 1<<1;
    }
    if (read >= 400 && read <= 600) {
        temp |= 1<<2;
    }
    if (read >= 600 && read <= 800) {
        temp |= 1<<3;
    }
    if (read >= 800) {
        temp |= 1<<4;
    }
    
    PORTD = temp;
}

int main(void) {
    unsigned char index = 6;
    
    // Set TMR1A in Fast PWM 8bit mode with non-inverted output to PB1
    TCCR1A = (0<<WGM11) | (1<<WGM10) | (0<<COM1A0) | (1<<COM1A1);
    // Also load CLK/1
    TCCR1B = (0<<WGM13) | (1<<WGM12) | (0<<CS12) | (0<<CS11) | (1<<CS10);
    // Initial value at 50%
    OCR1AL = DC_VALUE[index];
    
    // Timer 3 for interrupts to get DC data (CLK/64)
    TCCR3A = 0;
    TCCR3B = (0<<WGM33) | (1<<WGM32) | (0<<CS32) | (1<<CS31) | (1<<CS30);
    // 16MHz / (64 * 10Hz) - 1
    OCR3A = 24999;
    TIMSK3 = (1<<OCIE3A);
    
    DDRB |= 0b00111111;
    
    // set PORTD to an output
    DDRD = 0b00111111;
    PORTD = 0b11000000;
    
    // Setup ADC
    ADMUX = (1<<REFS0) | (1<<MUX0);
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);
    
    sei();
    
    while (1) {
        unsigned char temp = PIND;
        if (!(temp & (1<<PIND6))) {
            if (index < 12) {
                index++;
                OCR1AL = DC_VALUE[index];
            }
            
            while (!(PIND & (1<<PIND6))) {
                _delay_ms(10);
            }
        } else if (!(temp & (1<<PIND7))) {
            if (index > 0) {
                index--;
                OCR1AL = DC_VALUE[index];
            }
            
            while (!(PIND & (1<<PIND7))) {
                _delay_ms(10);
            }
        }
    }
}
