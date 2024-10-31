/*
 * File:   main.c
 * Author: filip
 *
 * Created on November 1, 2024, 1:03 AM
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

#define RS PD2
#define E  PD3

void write_2_nibles(uint8_t data){ //4 data lines D4 - D7 | each byte is 8 bits and must be sent in 2 nibbles (4bits)
    //read pind
    uint8_t high_nibble, low_nibble;
    high_nibble = data & 0xF0;
    PORTD = (PORTD & 0x0F) | high_nibble;

    PORTD |= (1<<E); // rising edge
    _delay_us(1);
    PORTD &= ~(1<<E); // falling edge
    
    //EXTRACT LOW NIBBLE 
    low_nibble = data << 4 & 0xF0;
    PORTD = (PORTD & 0x0F) | low_nibble;

    //PULSE ENABLE PIN 
    PORTD |= (1<<E); // rising edge
    _delay_us(1);
    PORTD &= ~(1<<E); // falling edge
}

void lcd_data(uint8_t data){
    PORTD |= (1<<RS); // RS = 1 Data incoming not command
    write_2_nibles(data);
    _delay_us(250);
}

void lcd_command(uint8_t command){
    PORTD &= ~(1<<RS); // RS = 0 Command incoming not data
    write_2_nibles(command);
    _delay_us(250);
}

void lcd_clear_display(void){
    lcd_command(0x01); // clear display
    _delay_ms(5); // delay for clear display
}

void lcd_init(void){
    _delay_ms(200); // wait for power up
    
    //8BIT MODE INITIALIZATION - ENABLE PULSE
    PORTD = (PORTD & 0x0F) | 0x30; 
    PORTD |= (1<<E); // rising edge
    _delay_us(1);
    PORTD &= ~(1<<E); // falling edge
    _delay_us(250);

    //8BIT MODE INITIALIZATION - ENABLE PULSE - 2ND TIME
    PORTD = (PORTD & 0x0F) | 0x30; 
    PORTD |= (1<<E); // rising edge
    _delay_us(1);
    PORTD &= ~(1<<E); // falling edge
    _delay_us(250);

    //8BIT MODE INITIALIZATION - ENABLE PULSE - 3RD TIME
    PORTD = (PORTD & 0x0F) | 0x30; 
    PORTD |= (1<<E); // rising edge
    _delay_us(1);
    PORTD &= ~(1<<E); // falling edge
    _delay_us(250);

    //4BIT MODE INITIALIZATION
    PORTD = (PORTD & 0x0F) | 0x20;
    PORTD |= (1<<E); // rising edge
    _delay_us(1);
    PORTD &= ~(1<<E); // falling edge
    _delay_us(250);

    //FUNCTION SET 4BIT MODE | 2 LINES | 5X8 DOTS
    lcd_command(0x28);

    //DISPLAY ON | CURSOR OFF
    lcd_command(0x0C);

    //clear display
    lcd_clear_display();

    //entry mode set: Increment address, no display shift
    lcd_command(0x06);

}

int main(void) {
    DDRD = 0xFF; // PORTD as output
    lcd_init();

    while (1) {
    }
}
