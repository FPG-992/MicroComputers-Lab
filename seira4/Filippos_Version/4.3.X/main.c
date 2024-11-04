/*
 * File:   main.c
 * Author: filip
 *
 * Created on November 4, 2024, 1:37 PM
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdio.h>

volatile uint16_t adc_result = 0; //10bit result
volatile uint8_t adc_conversion_complete = 0; //flag
volatile uint16_t ppm = 0; //ppm value

#define RS PD2
#define E  PD3
#define threshold_ppm 70
#define Vgas_0 0.1
#define M 0.000129

void init_adc(){ // Initialize ADC
    ADMUX = (1<<REFS0) | (1<<MUX1); // AVCC as reference, ADC2 as input
    ADCSRA = (1 << ADEN) | (1 << ADIE) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); // Enable ADC, Enable ADC interrupt, Prescaler 128

}

void init_timer1(){ // Timer1 for ADC conversion every 100 ms
    TCCR1B = (1 << WGM12) | (1 << CS12) | (1 << CS10);  // CTC mode, prescaler 1024
    OCR1A = 1562;  // 100 ms interrupt
    TIMSK1 = (1 << OCIE1A);  // Enable Timer1 Compare A interrupt
}

ISR(TIMER1_COMPA_vect) {
    ADCSRA |= (1 << ADSC);  // Start ADC conversion
}

ISR(ADC_vect) { // ADC conversion complete
    adc_result = ADC;
    adc_conversion_complete = 1;
}

float adc_to_voltage(uint16_t adc_result) {
    return (adc_result * 5.0) / 1024.0;
}

float voltage_to_ppm(float voltage) {
    return ((voltage-Vgas_0)/M) ;
}

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

    DDRD = 0xFF; // Set PORTD as output
    DDRB = 0xFF; // Set PORTB as output
    
    lcd_init();
    init_adc();
    init_timer1();
    sei();  // Enable global interrupts

    while (1){
        if(adc_conversion_complete){
            adc_conversion_complete = 0;
            float voltage = adc_to_voltage(adc_result);
            ppm = voltage_to_ppm(voltage);
            if(ppm<=20){
                PORTB=0x00;
            } else if(ppm<=30){
                PORTB=0x01;
            } else if(ppm<=40){
                PORTB=0x03;
            } else if(ppm<=50){
                PORTB=0x07;
            } else if(ppm<=60){
                PORTB=0x0F;
            } else if (ppm<=70){
                PORTB=0x1F;
            }
            else{
                lcd_clear_display();
                display_gas_detected();
                while(ppm>70){
                PORTB = 0xFF;
                for (unsigned char i = 255; i >= ppm; i--) {
                    _delay_ms(1);
                }
                PORTB = 0x00;
                for (unsigned char i = 255; i >= ppm; i--) {
                    _delay_ms(1);
                }
                }
                lcd_clear_display();
                display_clear();
            }
        }
    }
}
//else + displays are implemented from Chris' Solution
