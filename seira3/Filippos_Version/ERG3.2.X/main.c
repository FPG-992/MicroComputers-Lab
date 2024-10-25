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

const unsigned char Duty_Cycle[] = { 5, 26, 46, 66, 87, 108, 128, 148, 168, 189, 209, 230, 250 };
volatile uint8_t index;



int main(void) {
    
    //Timer Setup
    //FAST PWM 8-BIT INPUT NOT INVERTED TO PB1 256 PRESCALER
    TCCR1A = (0<<WGM11) | (1<<WGM10) | (0<<COM1A0) | (1<<COM1A1);
    TCCR1B = (0<<WGM13) | (1<<WGM12) | (1<<CS12) | (0<<CS11) | (0<<CS10);

    //Default value of PWM DC is 50% (128)
    index = 6;
    OCR1A = Duty_Cycle[index];
    

    while(1){
        //Increase Duty cycle if button PD7 is pressed and DC is less than 250
        if((PIND & (1<<PD7)) && index < 12){
            index++;
            OCR1A = Duty_Cycle[index];
            //Wait until button is released
            while((PIND & (1<<PD7))){
                _delay_ms(10);
            }
        }
        //Decrease Duty cycle if button PD6 is pressed and DC is more than 5
        if((PIND & (1<<PD6)) && index > 0){
            index--;
            OCR1A = Duty_Cycle[index];
            //Wait until button is released
            while((PIND & (1<<PD6))){
                _delay_ms(10);
            }
        }
    }
    
}
