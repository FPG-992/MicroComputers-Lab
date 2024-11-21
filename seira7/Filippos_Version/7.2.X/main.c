#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <stdio.h>
#include <string.h>

#define DS1820_PIN PD4

#define PCA9555_0_ADDRESS 0x40 // A0=A1=A2=0 by hardware
#define TWI_READ 1 // reading from twi device
#define TWI_WRITE 0 // writing to twi device
#define SCL_CLOCK 100000L // twi clock in Hz
// Fscl=Fcpu/(16+2*TWBR0_VALUE*PRESCALER_VALUE)
#define TWBR0_VALUE ((F_CPU/SCL_CLOCK)-16)/2

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
#define TW_START 0x08
#define TW_REP_START 0x10
//---------------- Master Transmitter ----------------------
#define TW_MT_SLA_ACK 0x18
#define TW_MT_SLA_NACK 0x20
#define TW_MT_DATA_ACK 0x28
//---------------- Master Receiver ----------------
#define TW_MR_SLA_ACK 0x40
#define TW_MR_SLA_NACK 0x48
#define TW_MR_DATA_NACK 0x58
#define TW_STATUS_MASK 0b11111000
#define TW_STATUS (TWSR0 & TW_STATUS_MASK)

// Initialize TWI clock
void twi_init(void) {
    TWSR0 = 0; // PRESCALER_VALUE=1
    TWBR0 = TWBR0_VALUE; // SCL_CLOCK 100KHz
}

// Read one byte from the twi device (request more data from device)
unsigned char twi_readAck(void) {
    TWCR0 = (1<<TWINT) | (1<<TWEN) | (1<<TWEA);
    while (!(TWCR0 & (1<<TWINT)));
    return TWDR0;
}

// Read one byte from the twi device, read is followed by a stop condition
unsigned char twi_readNak(void) {
    TWCR0 = (1<<TWINT) | (1<<TWEN);
    while (!(TWCR0 & (1<<TWINT)));
    return TWDR0;
}

// Issues a start condition and sends address and transfer direction.
// return 0 = device accessible, 1 = failed to access device
unsigned char twi_start(unsigned char address) {
    uint8_t twi_status;
    // send START condition
    TWCR0 = (1<<TWINT) | (1<<TWSTA) | (1<<TWEN);
    // wait until transmission completed
    while (!(TWCR0 & (1<<TWINT)));
    // check value of TWI Status Register.
    twi_status = TW_STATUS & 0xF8;
    if ((twi_status != TW_START) && (twi_status != TW_REP_START)) return 1;
    // send device address
    TWDR0 = address;
    TWCR0 = (1<<TWINT) | (1<<TWEN);
    // wait until transmission completed and ACK/NACK has been received
    while (!(TWCR0 & (1<<TWINT)));
    // check value of TWI Status Register.
    twi_status = TW_STATUS & 0xF8;
    if ((twi_status != TW_MT_SLA_ACK) && (twi_status != TW_MR_SLA_ACK)) {
        return 1;
    }
    return 0;
}

// Send start condition, address, transfer direction.
// Use ack polling to wait until device is ready
void twi_start_wait(unsigned char address) {
    uint8_t twi_status;
    while (1) {
        // send START condition
        TWCR0 = (1<<TWINT) | (1<<TWSTA) | (1<<TWEN);
        // wait until transmission completed
        while (!(TWCR0 & (1<<TWINT)));
        // check value of TWI Status Register.
        twi_status = TW_STATUS & 0xF8;
        if ((twi_status != TW_START) && (twi_status != TW_REP_START)) continue;
        // send device address
        TWDR0 = address;
        TWCR0 = (1<<TWINT) | (1<<TWEN);
        // wait until transmission completed
        while (!(TWCR0 & (1<<TWINT)));
        // check value of TWI Status Register.
        twi_status = TW_STATUS & 0xF8;
        if ((twi_status == TW_MT_SLA_NACK) || (twi_status == TW_MR_DATA_NACK)) {
            // device busy, send stop condition to terminate write operation
            TWCR0 = (1<<TWINT) | (1<<TWEN) | (1<<TWSTO);
            // wait until stop condition is executed and bus released
            while (TWCR0 & (1<<TWSTO));
            continue;
        }
        break;
    }
}

// Send one byte to twi device, Return 0 if write successful or 1 if write failed
unsigned char twi_write(unsigned char data) {
    // send data to the previously addressed device
    TWDR0 = data;
    TWCR0 = (1<<TWINT) | (1<<TWEN);
    // wait until transmission completed
    while (!(TWCR0 & (1<<TWINT)));
    if ((TW_STATUS & 0xF8) != TW_MT_DATA_ACK) return 1;
    return 0;
}

// Send repeated start condition, address, transfer direction
// Return: 0 device accessible, 1 failed to access device
unsigned char twi_rep_start(unsigned char address) {
    return twi_start(address);
}

// Terminates the data transfer and releases the twi bus
void twi_stop(void) {
    // send stop condition
    TWCR0 = (1<<TWINT) | (1<<TWEN) | (1<<TWSTO);
    // wait until stop condition is executed and bus released
    while (TWCR0 & (1<<TWSTO));
}

void PCA9555_0_write(PCA9555_REGISTERS reg, uint8_t value) {
    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);
    twi_write(reg);
    twi_write(value);
    twi_stop();
}

uint8_t PCA9555_0_read(PCA9555_REGISTERS reg) {
    uint8_t ret_val;
    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);
    twi_write(reg);
    twi_rep_start(PCA9555_0_ADDRESS + TWI_READ);
    ret_val = twi_readNak();
    twi_stop();
    return ret_val;
}

//lcd functions
// LCD Commands

volatile unsigned char PREVIOUS = 0x00; // ???????????? ??? ?????????? PREVIOUS


void write2(unsigned char input) {
    unsigned char prev = PREVIOUS;
    
    unsigned char write = (input & 0xF0) | (prev & 0x0F);
    PCA9555_0_write(REG_OUTPUT_0, write);
    
    write |= (1<<3);
    PCA9555_0_write(REG_OUTPUT_0, write);
    write &= 0b11110111;
    PCA9555_0_write(REG_OUTPUT_0, write);
        
    write = ((input & 0x0F) << 4) | (prev & 0x0F);
    PCA9555_0_write(REG_OUTPUT_0, write);
    
    write |= (1<<3);
    PCA9555_0_write(REG_OUTPUT_0, write);
    write &= 0b11110111;
    PCA9555_0_write(REG_OUTPUT_0, write);
}

void lcd_data(unsigned char input) {
    unsigned char prev = PREVIOUS;
    prev |= (1<<2);
    
    PCA9555_0_write(REG_OUTPUT_0, prev);
    write2(input);
    _delay_us(250);
}

void lcd_command(unsigned char input) {
    unsigned char prev = PREVIOUS;
    prev &= 0b11111011;
    
    PCA9555_0_write(REG_OUTPUT_0, prev);
    write2(input);
    _delay_us(250);
}

void lcd_nextline() {
    lcd_command(0b11000000);
}

void lcd_clear() {
    lcd_command(0x01);
    _delay_ms(5);
}

void lcd_init() {
    _delay_ms(200);
    
    // Switch to 8bit mode
    unsigned char write = 0x30;
    PCA9555_0_write(REG_OUTPUT_0, write);
    
    unsigned char temp = write;
    
    temp |= (1<<3);
    PCA9555_0_write(REG_OUTPUT_0, temp);
    temp &= 0b11110111;
    PCA9555_0_write(REG_OUTPUT_0, temp);
    _delay_us(250);
    
    temp = write;
    
    // Switch to 8bit mode
    PCA9555_0_write(REG_OUTPUT_0, write);
    
    temp |= (1<<3);
    PCA9555_0_write(REG_OUTPUT_0, temp);
    temp &= 0b11110111;
    PCA9555_0_write(REG_OUTPUT_0, temp);
    _delay_us(250);
    
    temp = write;
    
    // Switch to 8bit mode
    PCA9555_0_write(REG_OUTPUT_0, write);
    
    temp |= (1<<3);
    PCA9555_0_write(REG_OUTPUT_0, temp);
    temp &= 0b11110111;
    PCA9555_0_write(REG_OUTPUT_0, temp);
    _delay_us(250);
    
    // Switch to 8bit mode
    write = 0x20;
    temp = write;
    PCA9555_0_write(REG_OUTPUT_0, write);
    
    temp |= (1<<3);
    PCA9555_0_write(REG_OUTPUT_0, temp);
    temp &= 0b11110111;
    PCA9555_0_write(REG_OUTPUT_0, temp);
    _delay_us(250);
    
    lcd_command(0x28);
    
    lcd_command(0x0c);
    
    lcd_clear();
    
    lcd_command(0x06);
}

uint8_t one_wire_reset(void){
    uint8_t presence;
    DDRD |= (1<<DS1820_PIN);
    PORTD &= ~(1<<DS1820_PIN);
    _delay_us(480);

    DDRD &= ~(1<<DS1820_PIN);
    _delay_us(100);

    presence = PIND & (1<<DS1820_PIN);

    _delay_us(380);

    return (presence==0);
}

uint8_t one_wire_receive_bit(void){
    uint8_t bit = 0;
    DDRD |= (1<<DS1820_PIN);
    PORTD &= ~(1<<DS1820_PIN);
    _delay_us(2);

    DDRD &= ~(1<<DS1820_PIN);
    _delay_us(10);

    if (PIND & (1<<DS1820_PIN)){
        bit = 1;
    } else {
        bit = 0;
    }

    _delay_us(49);

    return bit;
}

void one_wire_transmit_bit(uint8_t bit){
    DDRD |= (1<<DS1820_PIN);
    PORTD &= ~(1<<DS1820_PIN);
    _delay_us(2);

    if(bit & 0x01){
        PORTD |= (1<<DS1820_PIN);      
    }else {
        PORTD &= ~(1<<DS1820_PIN);
    }

    _delay_us(58);

    DDRD &= ~(1<<DS1820_PIN);
    _delay_us(1);
}

uint8_t one_wire_receive_byte(void){
    uint8_t data=0;

    for(uint8_t i=0; i<8; i++){
        uint8_t bit = one_wire_receive_bit();
        data >>= 1;
        if (bit) {
            data |= 0x80;
        }
    }
    return data;
}

void one_wire_transmit_byte(uint8_t data){
    for (uint8_t i=0; i<8; i++){
        uint8_t bit = data & 0x01;
        one_wire_transmit_bit(bit);
        data >>= 1;
    }
}

int16_t read_temperature(void) {
    if (!one_wire_reset()) {
        return 0x8000; // Error: No device connected
    }

    one_wire_transmit_byte(0xCC); // Skip ROM command
    one_wire_transmit_byte(0x44); // Start temperature conversion

    if (!one_wire_reset()) {
        return 0x8000; // Error: No device connected
    }

    one_wire_transmit_byte(0xCC); // Skip ROM command
    one_wire_transmit_byte(0xBE); // Read Scratchpad command

    uint8_t temp_lsb = one_wire_receive_byte();
    uint8_t temp_msb = one_wire_receive_byte();

    int16_t temperature = (int16_t)((temp_msb << 8) | temp_lsb);
    
    return temperature; // Return raw temperature data
}


void lcd_print(const char *str) {
    while (*str) {
        lcd_data(*str++);
    }
}


int main(void) {


    DDRD = 0xFF;
    PORTD = 0x00;

    // Initialize TWI, PCA9555, and LCD
    twi_init();
    PCA9555_0_write(REG_CONFIGURATION_0, 0x00); // Set EXT_PORT1 as output
    lcd_init();


    while (1) {
        int16_t temperature = read_temperature();
        if (temperature==0x8000) {
            lcd_clear();
            lcd_print("No Device Found");
        } else {
            double temperature_cels = temperature * 0.0625f;
            char buffer[16];
            snprintf(buffer, sizeof(buffer), "%+05.1f", temperature_cels);
            strcat(buffer, "\xDF""C"); // Append degree symbol and 'C'
            lcd_clear();
            lcd_print(buffer);
        }
        _delay_ms(1000);
    }

    return 0;
}