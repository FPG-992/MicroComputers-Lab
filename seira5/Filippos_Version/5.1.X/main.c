/*
 * File:   main.c
 * Author: filip
 *
 * Created on November 4, 2024, 7:02 PM
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

#define PCA9555_0_ADDRESS 0x40 // A0=A1=A2=0 by hardware
#define TWI_READ 1             // Reading from TWI device
#define TWI_WRITE 0            // Writing to TWI device
#define SCL_CLOCK 100000L      // TWI clock in Hz

#define PB0 0
#define PB1 1
#define PB2 2
#define PB3 3

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

int main(void) {
    twi_init();

    PCA9555_0_write(REG_CONFIGURATION_0, 0x00); // Set EXT_PORT0 as output

    DDRB &= 0XF0; // Set PORTB0-PORTB3 as input

    PORTB |= 0x0F; // Enable pull-up resistors on PORTB0-PORTB3

    PCA9555_0_write(REG_CONFIGURATION_1, 0xFF); // All IO1_x as inputs

    while (1) {
    uint8_t inputs = PINB & 0x0F; // Read PORTB0 to PORTB3

    uint8_t A = (inputs >> PB0) & 1; // Read PORTB0
    uint8_t B = (inputs >> PB1) & 1; // Read PORTB1
    uint8_t C = (inputs >> PB2) & 1; // Read PORTB2
    uint8_t D = (inputs >> PB3) & 1; // Read PORTB3


    uint8_t F0 = !( (!A && B && C) || (B && !D) );

    uint8_t F1 = (A || B || C) && (B && !D);

    uint8_t output = 0x00;
    output |= (F0 << 0); // Set EXT_PORT0_0
    output |= (F1 << 1); // Set EXT_PORT0_1

    PCA9555_0_write(REG_OUTPUT_0, output);

    _delay_ms(200); // Delay 200ms so we can see the output


    }
}
