#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

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

int main(void) {

    lcd_init();
    lcd_clear();
    display_clear();
        
}