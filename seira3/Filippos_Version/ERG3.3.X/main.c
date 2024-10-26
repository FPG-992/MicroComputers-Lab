/*
 * File:   main.c
 * Author: filip
 *
 * Created on October 24, 2024, 9:42 PM
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

const unsigned char DC_VALUE[] = { 5, 26, 46, 66, 87, 108, 128, 148, 168, 189, 209, 230, 250 };
volatile uint8_t index;
volatile uint8_t mode = 0;

void adc_init(){
    //ADC SETUP
    //We need to setup the potensiometer as input | POT1
    //01 AVCC with external capacitor at AREF pin
    //Analog input 0 of adc can either be connected with POT1 or analog filter PD6_PWM
    //Enable ADC, Set Prescaler to 128
    //ADEN = ADC Enable
    //ADPS2:0 = 111 -> Prescaler 128
    // What this does is that it sets the ADC prescaler to 128 which means that the ADC clock is 16MHz/128 = 125kHz which is in the range of 50-200kHz we are asked to have
    ADMUX = (1 << REFS0); //AVCC as reference
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); //Enable ADC, 128 prescaler (Division Factor 111=128)
}

uint8_t ADC_Read(uint8_t channel) {
    // Select the ADC channel (0-7)
    ADMUX = (ADMUX & 0xF0) | (channel & 0x0F); // Clear the channel bits | We select channel ADC0 (0000) 
    ADCSRA |= (1 << ADSC); // Start the conversion
    while (ADCSRA & (1 << ADSC)); // Wait for conversion to complete
    return ADC >> 2; // Return the 8-bit value (10-bit result right-shifted)
}



int main(void) {
    
    //Timer Setup
    //FAST PWM 8-BIT INPUT NOT INVERTED TO PB1 256 PRESCALER
    TCCR1A = (0<<WGM11) | (1<<WGM10) | (0<<COM1A0) | (1<<COM1A1);
    TCCR1B = (0<<WGM13) | (1<<WGM12) | (1<<CS12) | (0<<CS11) | (0<<CS10);

    //Default value of PWM DC is 50% (128)
    index = 6;
    OCR1AL = DC_VALUE[index];
    
    //Set PD6 and PD7 as input
    DDRD = 0X00;
    //Enable Pull-up resistors
    PORTD = 0XFF;
    
    //ADC SETUP
    adc_init();

    while(1){
        //read value of PD6 and PD7
        //if PD6 is set , we select mode 1
        if((PIND & (1<<PD6))){
            mode = 1;
        }
        //if PD7 is set, we select mode 2
        if((PIND & (1<<PD7))){
            mode = 2;
        }
        //Increase Duty cycle if button PD1 is pressed and DC is less than 250 && mode 1 is selected
        if((PIND & (1<<PD1)) && index < 12 && mode == 1){
            index++;
            OCR1AL = DC_VALUE[index];
            //Wait until button is released - Debounce
            while((PIND & (1<<PD7))){
                _delay_ms(10);
            }
        }
        //Decrease Duty cycle if button PD2 is pressed and DC is more than 5 && mode 1 is selected
        if((PIND & (1<<PD2)) && index > 0 && mode == 1){
            index--;
            OCR1AL = DC_VALUE[index];
            //Wait until button is released - Debounce
            while((PIND & (1<<PD6))){
                _delay_ms(10);
            }

        }
        //IN mode 2 we read the value of the potensiometer and set the duty cycle to the value of the potensiometer
        if(mode == 2){
            OCR1AL = ADC_Read(0);
        }
    }
    
}