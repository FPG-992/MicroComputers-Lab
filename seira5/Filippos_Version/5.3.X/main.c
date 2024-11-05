/*
 * File:   main.c
 * Author: filip
 *
 * Created on November 5, 2024, 1:24 PM
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

#define PCA9555_0_ADDRESS 0x40 // A0=A1=A2=0 by hardware
#define TWI_READ 1             // Reading from TWI device
#define TWI_WRITE 0            // Writing to TWI device
#define SCL_CLOCK 100000L      // TWI clock in Hz

// LCD Pins
#define RS PD2
#define E  PD3

// LCD Control Bits mapped to PCA9555 Port 1
#define LCD_RS 0 // Bit 0
#define LCD_E  1 // Bit 1
#define LCD_D4 2 // Bit 2
#define LCD_D5 3 // Bit 3
#define LCD_D6 4 // Bit 4
#define LCD_D7 5 // Bit 5

// Fscl = Fcpu / (16 + 2 * TWBR0_VALUE * PRESCALER_VALUE)
#define TWBR0_VALUE ((F_CPU / SCL_CLOCK) - 16) / 2

// PCA9555 REGISTERS
typedef enum {
    REG_INPUT_0 = 0,
    REG_INPUT_1 = 1,
    REG_OUTPUT_0 = 2,
    REG_OUTPUT_1 = 3,
    REG_POLARITY_INV_0 = 4,
    REG_POLARITY_INV_1 = 5,
    REG_CONFIGURATION_0 = 6,
    REG_CONFIGURATION_1 = 7
} PCA9555_REGISTERS;

//----------- Master Transmitter/Receiver -------------------
#define TW_START      0x08
#define TW_REP_START  0x10

//---------------- Master Transmitter ----------------------
#define TW_MT_SLA_ACK  0x18
#define TW_MT_SLA_NACK 0x20
#define TW_MT_DATA_ACK 0x28

//---------------- Master Receiver ------------------------
#define TW_MR_SLA_ACK  0x40
#define TW_MR_SLA_NACK 0x48
#define TW_MR_DATA_NACK 0x58

#define TW_STATUS_MASK 0b11111000
#define TW_STATUS (TWSR0 & TW_STATUS_MASK)

// Initialize TWI clock
void twi_init(void) {
    TWSR0 = 0;            // PRESCALER_VALUE = 1
    TWBR0 = TWBR0_VALUE;  // SCL_CLOCK = 100KHz
}

// Read one byte from the TWI device (request more data from device)
unsigned char twi_readAck(void) {
    TWCR0 = (1 << TWINT) | (1 << TWEN) | (1 << TWEA);
    while (!(TWCR0 & (1 << TWINT)));
    return TWDR0;
}

// Read one byte from the TWI device, read is followed by a stop condition
unsigned char twi_readNak(void) {
    TWCR0 = (1 << TWINT) | (1 << TWEN);
    while (!(TWCR0 & (1 << TWINT)));
    return TWDR0;
}

// Issues a start condition and sends address and transfer direction.
// Return 0 = device accessible, 1 = failed to access device
unsigned char twi_start(unsigned char address) {
    uint8_t twi_status;

    // Send START condition
    TWCR0 = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);

    // Wait until transmission completed
    while (!(TWCR0 & (1 << TWINT)));

    // Check value of TWI Status Register
    twi_status = TW_STATUS & 0xF8;
    if ((twi_status != TW_START) && (twi_status != TW_REP_START)){
        return 1;
    }

    // Send device address
    TWDR0 = address;
    TWCR0 = (1 << TWINT) | (1 << TWEN);

    // Wait until transmission completed and ACK/NACK has been received
    while (!(TWCR0 & (1 << TWINT)));

    // Check value of TWI Status Register
    twi_status = TW_STATUS & 0xF8;
    if ((twi_status != TW_MT_SLA_ACK) && (twi_status != TW_MR_SLA_ACK)) {
        return 1;
    }

    return 0;
}

// Send start condition, address, transfer direction.
// Use ACK polling to wait until device is ready
void twi_start_wait(unsigned char address) {
    uint8_t twi_status;
    while (1) {
        // Send START condition
        TWCR0 = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);

        // Wait until transmission completed
        while (!(TWCR0 & (1 << TWINT)));

        // Check value of TWI Status Register
        twi_status = TW_STATUS & 0xF8;
        if ((twi_status != TW_START) && (twi_status != TW_REP_START)){
            continue;
        }

        // Send device address
        TWDR0 = address;
        TWCR0 = (1 << TWINT) | (1 << TWEN);

        // Wait until transmission completed
        while (!(TWCR0 & (1 << TWINT)));

        // Check value of TWI Status Register
        twi_status = TW_STATUS & 0xF8;
        if ((twi_status == TW_MT_SLA_NACK) || (twi_status == TW_MR_DATA_NACK)) {
            /* Device busy, send STOP condition to terminate write operation */
            TWCR0 = (1 << TWINT) | (1 << TWEN) | (1 << TWSTO);

            // Wait until stop condition is executed and bus released
            while (TWCR0 & (1 << TWSTO));

            continue;
        }
        break;
    }
}

// Send one byte to TWI device, Return 0 if write successful or 1 if write failed
unsigned char twi_write(unsigned char data) {
    // Send data to the previously addressed device
    TWDR0 = data;
    TWCR0 = (1 << TWINT) | (1 << TWEN);

    // Wait until transmission completed
    while (!(TWCR0 & (1 << TWINT)));

    if ((TW_STATUS & 0xF8) != TW_MT_DATA_ACK)
        return 1;

    return 0;
}

// Send repeated start condition, address, transfer direction
// Return: 0 = device accessible, 1 = failed to access device
unsigned char twi_rep_start(unsigned char address) {
    return twi_start(address);
}

// Terminates the data transfer and releases the TWI bus
void twi_stop(void) {
    // Send STOP condition
    TWCR0 = (1 << TWINT) | (1 << TWEN) | (1 << TWSTO);

    // Wait until STOP condition is executed and bus released
    while (TWCR0 & (1 << TWSTO));
}

// Write to PCA9555 register
void PCA9555_0_write(PCA9555_REGISTERS reg, uint8_t value) {
    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);
    twi_write(reg);
    twi_write(value);
    twi_stop();
}

// Read from PCA9555 register
uint8_t PCA9555_0_read(PCA9555_REGISTERS reg) {
    uint8_t ret_val;

    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);
    twi_write(reg);
    twi_rep_start(PCA9555_0_ADDRESS + TWI_READ);
    ret_val = twi_readNak();
    twi_stop();
    return ret_val;
}

// LCD Functions

void write_2_nibbles(uint8_t data){ //4 data lines D4 - D7 | each byte is 8 bits and must be sent in 2 nibbles (4bits)

    //we need to extract the high nibble and the low nibble from the data
    uint8_t high_nibble, low_nibble;
    uint8_t output_data = PCA9555_0_read(REG_OUTPUT_1); // read current data from PCA9555

    //EXTRACT HIGH NIBBLE
    output_data &= (0X3C); // clear D4-D7
    output_data |= ((data & 0xF0) >> 4) << 2; // we shift the high nibble 4 bits to the right and then shift it to the left to match D4-D7
    PCA9555_0_write(REG_OUTPUT_1,output_data); // write high nibble to PCA9555

    //PULSE ENABLE PIN
    PCA9555_0_write(REG_OUTPUT_1,output_data | (1<<LCD_E)); // rising edge
    _delay_us(1);
    PCA9555_0_write(REG_OUTPUT_1,output_data & ~(1<<LCD_E)); // falling edge

    //EXTRACT LOW NIBBLE
    output_data &= (0X3C); // clear D4-D7
    output_data |= (data & 0x0F) << 2; // we shift the low nibble to the left to match D4-D7
    PCA9555_0_write(REG_OUTPUT_1,output_data); // write low nibble to PCA9555

    //PULSE ENABLE PIN
    PCA9555_0_write(REG_OUTPUT_1,output_data | (1<<LCD_E)); // rising edge
    _delay_us(1);
    PCA9555_0_write(REG_OUTPUT_1,output_data & ~(1<<LCD_E)); // falling edge
    _delay_us(1);
}

void lcd_data(uint8_t data){
    uint8_t current_data = PCA9555_0_read(REG_OUTPUT_1); // read current data from PCA9555
    current_data |= (1<<LCD_RS); // set RS to 1
    PCA9555_0_write(REG_OUTPUT_1,current_data); // write data to PCA9555
    write_2_nibbles(data); // write data to LCD
    _delay_us(250); // delay for data write
}

void lcd_command(uint8_t command){
    uint8_t current_data = PCA9555_0_read(REG_OUTPUT_1); // read current data from PCA9555
    current_data &= ~(1<<LCD_RS); // set RS to 0
    PCA9555_0_write(REG_OUTPUT_1,current_data); // write data to PCA9555
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
    lcd_command(0x30);

    //8BIT MODE INITIALIZATION - ENABLE PULSE - 2ND TIME
    lcd_command(0x30);

    //8BIT MODE INITIALIZATION - ENABLE PULSE - 3RD TIME
    lcd_command(0x30);

    //4BIT MODE INITIALIZATION
    lcd_command(0x20);
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

void lcd_string(char *str){
    while(*str){
        lcd_data(*str++);
    }
}

int main(void) {
    
    DDRD = 0xFF; // Set PORTD as output

    twi_init(); // Initialize TWI

    PCA9555_0_write(REG_CONFIGURATION_1, 0x00); // Set PORT1 as output
    
    lcd_init(); // Initialize LCD

    /* Replace with your application code */
    while (1) {
    lcd_command(0x80); // 0x80 is the DDRAM address for first line, position 0
    lcd_string("FILIPPOS"); // 16 characters

    lcd_command(0xC0); // 0xC0 is the DDRAM address for second line, position 0
    lcd_string("GIANNAKOPOULOS"); // 16 characters
    }
}


/*
LCD I2C MAPPING
RS = B0
E = B1
D4 = B2
D5 = B3
D6 = B4
D7 = B5
*/