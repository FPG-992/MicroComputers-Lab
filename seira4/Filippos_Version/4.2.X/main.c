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

uint32_t adc_value=0;

void write_2_nibbles(uint8_t data){ //4 data lines D4 - D7 | each byte is 8 bits and must be sent in 2 nibbles (4bits)
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
    write_2_nibbles(data);
    _delay_us(250);
}

void lcd_command(uint8_t command){
    PORTD &= ~(1<<RS); // RS = 0 Command incoming not data
    write_2_nibbles(command);
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

void voltage_to_lcd(uint32_t voltage_mv, *voltage_string){
    uint8_t thousands, hundreds, tens;
    thousands = voltage_mv / 1000; // prwto psifio tou voltage_mv
    hundreds = (voltage_mv % 1000) / 100; //3 teleutea psifia, pianw to prwto psifio apo auta
    tens = (voltage_mv % 100) / 10; //2 teleutea psifia, pianw to prwto psifio apo auta

    voltage_string[0] = thousands + '0';
    voltage_string[1] = '.';
    voltage_string[2] = hundreds + '0';
    voltage_string[3] = tens + '0';
    voltage_string[4] = 'V';
    voltage_string[5] = '\0';
}

uint16_t read_adc(void){
    ADCSRA |= (1<<ADSC); // start conversion
    while(ADCSRA & (1<<ADSC)); // wait for conversion to complete
    return ADC;
}

void lcd_print_string(const char* str) {
    while(*str) {
        lcd_data(*str++);
    }
}

int main(void) {
    
    //LCD INITIALIZATION
    DDRD = 0xFF; // PORTD as output
    lcd_init();

    //ADC INITIALIZATION
    ADMUX = (0<<MUX3) | (0<<MUX2) | (0<<MUX1) | (1<<MUX0) | (0<<REFS1) | (1<<REFS0); // ADC1 | AVCC with external capacitor at AREF pin
    //; ADIE=0 => disable adc interrupt, ADPS[2:0]=111 => fADC=16MHz/128=125KHz | ADIE=1 => enable adc interrupt
    ADCSRA = (1<<ADEN) | (0<<ADSC) | (0<<ADIE) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0); // ADC Enable | ADC Start Conversion | ADC Interrupt Disable | ADC Prescaler 128

    char voltage_string[6]; // 5 digits + null terminator

    while (1) {
        adc_value = read_adc();
        uint32_t voltage_mv = (adc_value * 5000) / 1024;
        voltage_to_lcd(voltage_mv,voltage_string);
        lcd_clear_display();
        lcd_print_string(voltage_string);
    }
}
