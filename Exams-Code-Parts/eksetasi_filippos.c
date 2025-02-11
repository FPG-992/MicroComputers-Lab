#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

#define PB1 1
#define PB2 2
#define PB3 3
#define PB4 4

unsigned char input_data2;
unsigned char f1;
unsigned char f2;
unsigned char A;
unsigned char B;
unsigned char C;
unsigned char D;
char logical_data2[2];
        
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

void lcd_line2() {
    lcd_command(0b11000000);
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(logical_data2[0]);
    lcd_data(logical_data2[1]);
    
}

void read_pins2(){
    input_data2 = PINB & 0x00011110; // Read PORTB0 to PORTB3
    input_data2 = ~input_data2;
}

void logical_functions2(){
    read_pins2();
        unsigned char inputs = input_data2;
        unsigned char A = (inputs >> PB1) & 1; // Read PORTB0
        unsigned char B = (inputs >> PB2) & 1; // Read PORTB1
        unsigned char C = (inputs >> PB3) & 1; // Read PORTB2
        unsigned char D = (inputs >> PB4) & 1; // Read PORTB3
        unsigned char f1 = (~A & D) | (B & (~C));
        unsigned char f2 = (B | (~A)) | ~((~C) | A );
        logical_data2[0] = f2;
        logical_data2[1] = f1;
}

void lcd_line1(){
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(' ');
    lcd_data(A);
    lcd_data(B);
    lcd_data(C);
    lcd_data(D);
}

int main(void) {
    DDRD = 0xFF;

    DDRB = 0X00; // Set PORTB as input
    PORTB = 0xFF; // Enable pull-up resistors 
    
    lcd_init();
    
    
    while(1){
        lcd_line1();
        read_pins2();
        logical_functions2();
        lcd_line2();
        lcd_clear();
    }
}