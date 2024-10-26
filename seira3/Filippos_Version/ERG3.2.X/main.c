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
volatile uint16_t ADC_Value = 0;
volatile uint16_t ADC_Value_SUM = 0;
volatile uint8_t ADC_Counter = 0;
unsigned int ADC_Measurements[16] = {0};
volatile uint16_t Average_Value = 0; 

ISR(TIMER3_COMPA_vect) {
    ADCSRA |= (1 << ADSC);  // Start ADC conversion
    while ((ADCSRA & (1 << ADSC)) != 0);  // Wait for ADC conversion to complete

    ADC_Value = ADC;  // Read ADC value
    ADC_Measurements[ADC_Counter] = ADC_Value;  // Store ADC value in array
    ADC_Counter++;  // Increment counter    
    ADC_Value_SUM += ADC_Value;  // Add ADC value to sum
    //Moving Average Filter
    //we want to remove the oldest value from the sum
    //starting by the oldest value in the array
    if (ADC_Counter == 16) {
        ADC_Value_SUM -= ADC_Measurements[0];
        //shift all values to the left
        for (int i = 0; i < 15; i++) {
            ADC_Measurements[i] = ADC_Measurements[i + 1];
        }
        ADC_Counter = 15;  // Reset counter

        //Calculate the average of the 16 values by shifting the sum 4 bits to the right
        //This is equivalent to dividing the sum by 16
        Average_Value = ADC_Value_SUM >> 4;
        
        //we want to keep PD7 AND PD6 AS INPUT
        
        //Output
        unsigned char output = 0b11000000;

        if (Average_Value >= 0 && Average_Value <= 200) {
            output |= 0b00001;
        }
        if (Average_Value > 200 && Average_Value <= 400) {
            output |= 0b00010;
        }
        if (Average_Value > 400 && Average_Value <= 600) {
            output |= 0b00100;
        }
        if (Average_Value > 600 && Average_Value <= 800) {
            output |= 0b01000;
        }
        if (Average_Value > 800) {
            output |= 0b10000;
        }

        PORTD = output;

    }


}


int main(void) {
    
    //Timer Setup
    //FAST PWM 8-BIT INPUT NOT INVERTED TO PB1 256 PRESCALER
    TCCR1A = (0<<WGM11) | (1<<WGM10) | (0<<COM1A0) | (1<<COM1A1);
    TCCR1B = (0<<WGM13) | (1<<WGM12) | (1<<CS12) | (0<<CS11) | (0<<CS10);

    //Default value of PWM DC is 50% (128)
    index = 6;
    OCR1AL = Duty_Cycle[index];
    
    //Button Setup | PD0 PD1 PD2 PD3 PD4 As output
    DDRD = 0b11000000;
    //Enable Pull-up resistors
    PORTD = 0b00111111;
    
    //ADC SETUP
    ADMUX = (1 << REFS0) | (1 << MUX0); //AVCC as reference, ADC1 as input
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); //Enable ADC, 128 prescaler (Division Factor 111=128)

    //Timer3 Setup (16bit compared to 8 of Timer2)
    TCCR3B = (0 << WGM33) | (1 << WGM32) | (0 << CS32) | (1 << CS31) | (1 << CS30); //CTC mode, 64 prescaler
    OCR3A = 24999; //24999
    TIMSK3 = (1 << OCIE3A); //Enable interrupt on compare match
    //16000000/64 = 250000 = 250kHz
    //effective clock frequency for Timer3 = 250kHz
    //Interrupt frequency for T3 = 250kHZ/OCR3A+1 = 10Hz = 0.1s => ocr3a = 24999    

    sei(); //Enable global interrupts

    while(1){
        //Increase Duty cycle if button PD7 is pressed and DC is less than 250
        if((PIND & (1<<PD7)) && index < 12){
            index++;
            OCR1AL = Duty_Cycle[index];
            //Wait until button is released - Debounce
            while((PIND & (1<<PD7))){
                _delay_ms(10);
            }
        }
        //Decrease Duty cycle if button PD6 is pressed and DC is more than 5
        if((PIND & (1<<PD6)) && index > 0){
            index--;
            OCR1AL = Duty_Cycle[index];
            //Wait until button is released - Debounce
            while((PIND & (1<<PD6))){
                _delay_ms(10);
            }

        }
    }
    
}
