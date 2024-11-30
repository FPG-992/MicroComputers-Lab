/*
 * File:   main.c
 * Author: filip
 *
 * Created on November 20, 2024, 4:40 PM
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

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

uint8_t scan_row(uint8_t row){
    uint8_t output, input, keys;

    //set specified row to 0, others to 1
    output = ~(1 << row) & 0X0F;

    //read current output values
    uint8_t current_output = PCA9555_0_read(REG_OUTPUT_1);  
    
    //update output register with new values
    current_output = (current_output & 0xF0) | output;

    _delay_ms(20);

    //write back to outpt register
    PCA9555_0_write(REG_OUTPUT_1, current_output);

    //read input register - column values
    input = PCA9555_0_read(REG_INPUT_1);

    //extract column values (bits 7-4)
    input = (input & 0xF0) >> 4;

    //we have active low so we need to invert the bits
    keys = ~input & 0x0F;

    return keys;
}

uint16_t scan_keypad(void){
    uint16_t keys = 0;
    uint8_t row_keys;
    uint8_t row;

    for(row = 0; row < 4; row++){
        row_keys = scan_row(row);
        keys |= ((uint16_t)row_keys << (row * 4));
    }
    
    //this is a 16 bit value with 16 bits representing the keys
    return keys;

}

uint16_t pressed_keys = 0;

void scan_keypad_rising_edge(void){
    static uint16_t pressed_keys_temp = 0;
    uint16_t keys_first, keys_second, stable_keys, new_keys;

    keys_first = scan_keypad();
    _delay_ms(20);

    keys_second = scan_keypad();
    
    //stable keys
    stable_keys = keys_first & keys_second;

    //update pressed keys temp
    pressed_keys_temp = stable_keys;

    new_keys = pressed_keys_temp & (~pressed_keys);

    pressed_keys = pressed_keys_temp;
}

const char key_map[16] = {
    '1', '2', '3', 'A',
    '4', '5', '6', 'B',
    '7', '8', '9', 'C',
    '*', '0', '#', 'D'
};

char keypad_to_ascii(void){
    uint16_t keys = pressed_keys; //get the pressed keys
    uint8_t i;
    for(i = 0; i < 16; i++){
        if(keys & (1 << i)){
            return key_map[i];
        }
    }
    //no key pressed
    return '\0';
}


int main(void){

    twi_init();

    //SET PB as output
    DDRB = 0xFF;
    PORTB = 0x00;

    //SET EXT_PORT0 as output
    PCA9555_0_write(REG_CONFIGURATION_1, 0xF0);

    while(1){
        scan_keypad_rising_edge();
        uint16_t keys = pressed_keys;

        // Map keys to LEDs
        if (keys & (1 << 3)) { // 'A' is at index 3
            PORTB |= (1 << 0); // LED on PB0
        }
        if (keys & (1 << 9)) { // '8' is at index 9
            PORTB |= (1 << 1); // LED on PB1
        }
        if (keys & (1 << 6)) { // '6' is  at index 6
            PORTB |= (1 << 2); // LED on PB2
        }
        if (keys & (1 << 12)) { // '*' is  at index 12
            PORTB |= (1 << 3); // LED on PB3
        }

        // Small delay
        _delay_ms(10);
    }
}