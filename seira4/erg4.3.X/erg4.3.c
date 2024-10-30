#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

unsigned int last_measure = 0;

void write2(unsigned char input) {
    unsigned char prev = PIND;
    
    PORTD = (input & 0xF0) | (prev & 0x0F);
    
    PORTD |= (1<<3);
    PORTD &= 0b11110111;
    
    PORTD = ((input & 0x0F) << 4) | (prev & 0x0F);
            
    PORTD |= (1<<3);
    PORTD &= 0b11110111;
}

void lcd_data(unsigned char input) {
    PORTD |= (1<<2);
    write2(input);
    _delay_us(250);
}

void lcd_command(unsigned char input) {
    PORTD &= 0b11111011;
    write2(input);
    _delay_us(250);
}

void lcd_clear() {
    lcd_command(0x01);
    _delay_ms(5);
}

void lcd_init() {
    _delay_ms(200);
    
    // Switch to 8bit mode
    PORTD = 0x30;
    PORTD |= (1<<3);
    PORTD &= 0b11110111;
    _delay_us(250);
    
    // Switch to 8bit mode
    PORTD = 0x30;
    PORTD |= (1<<3);
    PORTD &= 0b11110111;
    _delay_us(250);
    
    // Switch to 8bit mode
    PORTD = 0x30;
    PORTD |= (1<<3);
    PORTD &= 0b11110111;
    _delay_us(250);
    
    // Switch to 8bit mode
    PORTD = 0x20;
    PORTD |= (1<<3);
    PORTD &= 0b11110111;
    _delay_us(250);
    
    lcd_command(0x28);
    
    lcd_command(0x0c);
    
    lcd_clear();
    
    lcd_command(0x06);
}

ISR(TIMER3_COMPA_vect) {
    ADCSRA |= (1<<ADSC);
    while ((ADCSRA & (1<<ADSC)) != 0);
    
    double input = ADC * 5;
    input = input / 1024;
    input = input - 0.1;
    input = input * 77.519;
    last_measure = input;
}

void display_gas_detected() {
    lcd_data('G');
    lcd_data('A');
    lcd_data('S');
    lcd_data(' ');
    lcd_data('D');
    lcd_data('E');
    lcd_data('T');
    lcd_data('E');
    lcd_data('C');
    lcd_data('T');
    lcd_data('E');
    lcd_data('D');
}

void display_clear() {
    lcd_data('C');
    lcd_data('L');
    lcd_data('E');
    lcd_data('A');
    lcd_data('R');
}

int main(void) {
    // PORTD as output
    DDRD = 0xFF;
    
    // PORTB as output
    DDRB = 0xFF;
    
    // Setup ADC
    ADMUX = (1<<REFS0) | (1<<MUX1);
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);
    
    // Timer 3 for interrupts to get DC data (CLK/64)
    TCCR3A = 0;
    TCCR3B = (0<<WGM33) | (1<<WGM32) | (0<<CS32) | (1<<CS31) | (1<<CS30);
    // 16MHz / (64 * 10Hz) - 1
    OCR3A = 24999;
    TIMSK3 = (1<<OCIE3A);
    
    lcd_init();
    
    sei();
    
    while (1) {
        if (last_measure <= 10) {
            PORTB = 0x00;
        } else if (last_measure <= 20) {
            PORTB = 0b00000001;
        } else if (last_measure <= 30) {
            PORTB = 0b00000011;
        } else if (last_measure <= 40) {
            PORTB = 0b00000111;
        } else if (last_measure <= 50) {
            PORTB = 0b00001111;
        } else if (last_measure <= 60) {
            PORTB = 0b00011111;
        } else if (last_measure <= 70) {
            PORTB = 0b00111111;
        } else {
            lcd_clear();
            display_gas_detected();
            while (last_measure >= 70) {
                PORTB = 0xFF;
                for (unsigned char i = 255; i >= last_measure; i--) {
                    _delay_ms(1);
                }
                PORTB = 0x00;
                for (unsigned char i = 255; i >= last_measure; i--) {
                    _delay_ms(1);
                }
            }
            lcd_clear();
            display_clear();
        }
    }
}
