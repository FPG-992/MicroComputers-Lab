#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

unsigned char hundreds, tens, units;

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

void display_number(unsigned char input) {
    lcd_data(0b00110000 | (input & 0x0F));
}

void binary_to_bcd(unsigned char input) {
    hundreds = 0;
    tens = 0;
    
    while (input >= 100) {
        hundreds++;
        input -= 100;
    }
    
    while (input >= 10) {
        tens++;
        input -= 10;
    }
    
    units = input;
}

int main(void) {
    // PORTD as output
    DDRD = 0xFF;
    
    // Setup ADC
    ADMUX = (1<<REFS0) | (1<<MUX0);
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);
    
    while (1) {
        // Request ADC data
        ADCSRA |= (1<<ADSC);
        while ((ADCSRA & (1<<ADSC)) != 0);
        
        // Processing
        unsigned int input = ADC;
        unsigned int copy = input;
        
        copy = ADC<<2;
        copy += input;
        
        unsigned char integer = (copy>>10) & 0xFF;
        unsigned long decimal = copy & 0b0000001111111111;
        decimal *= 100;
        decimal = decimal>>10;
        
        // Display
        lcd_clear();
        
        binary_to_bcd(integer);
        display_number(units);
        lcd_data('.');
        
        binary_to_bcd(decimal);
        display_number(tens);
        display_number(units);
        
        lcd_data('V');
        
        // Repeat after 1s
        _delay_ms(1000);
    }
}
