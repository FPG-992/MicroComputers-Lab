// **Includes and Definitions**
#define F_CPU 16000000UL  // Define CPU frequency as 16 MHz

#include <avr/io.h>         // AVR I/O definitions
#include <util/delay.h>     // Delay functions
#include <avr/interrupt.h>  // Interrupt functions

// UART Definitions
#define UBRR_VALUE 103  // UART Baud Rate Register value for 9600 bps
#define URL "http://192.168.1.250:5000/data"  // URL to set in ESP8266

// TWI (I2C) Definitions
#define PCA9555_0_ADDRESS 0x40  // I2C address of PCA9555 (A0=A1=A2=0)
#define TWI_READ 1              // Read operation
#define TWI_WRITE 0             // Write operation
#define SCL_CLOCK 100000L       // TWI clock frequency in Hz

// Calculate TWI Bit Rate Register value
// Fscl = Fcpu / (16 + 2 * TWBR * Prescaler)
#define TWBR0_VALUE ((F_CPU / SCL_CLOCK) - 16) / 2

// Buffer Definitions
char buffer[50];            // Buffer to store incoming UART data
uint8_t buffer_pointer = 0; // Pointer to current position in buffer

const char success[] = "\"Success\"";  // Expected success response

// **Buffer Handling Functions**

void init_buffer() {
    // Initialize the buffer pointer
    buffer_pointer = 0;
}

void write_buffer(char c) {
    // Write a character to the buffer and increment the pointer
    buffer[buffer_pointer] = c;
    buffer_pointer++;

    // Prevent buffer overflow
    if (buffer_pointer == 50) buffer_pointer = 0;
}

uint8_t success_fail_buffer() {
    // Check if buffer contains "Success" at the beginning
    if (buffer_pointer < 2) return 0;
    for (uint8_t i = 0; i < 2; i++) {
        if (buffer[i] != success[i]) {
            return 0;
        }
    }
    return 1;  // Return 1 if "Success" is found
}

// **UART Functions**

void usart_init(uint16_t ubrr) {
    // Initialize UART with given UBRR value
    UCSR0A = 0;  // Reset UART status register
    UCSR0B = (1 << RXEN0) | (1 << TXEN0);  // Enable receiver and transmitter
    UBRR0H = (uint8_t)(ubrr >> 8);  // Set baud rate high byte
    UBRR0L = (uint8_t)ubrr;         // Set baud rate low byte
    UCSR0C = (3 << UCSZ00);  // Set frame format: 8 data bits, no parity, 1 stop bit
}

void usart_transmit(uint8_t data) {
    // Transmit a single byte over UART
    while (!(UCSR0A & (1 << UDRE0)));  // Wait until transmit buffer is empty
    UDR0 = data;  // Load data into UART data register
}

char usart_receive() {
    // Receive a single byte over UART
    while (!(UCSR0A & (1 << RXC0)));  // Wait until data is received
    return UDR0;  // Return received data
}

void transmit_string(char arr[]) {
    // Transmit a string over UART until '\n' or '\0' is encountered
    uint8_t i = 0;
    while (arr[i] != '\n' && arr[i] != '\0') {
        usart_transmit(arr[i]);
        i++;
    }
    if (arr[i] != '\0') usart_transmit(arr[i]);  // Transmit '\n' if present
}

uint8_t receive_success_fail() {
    // Receive response and check for "Success" or "Fail"
    init_buffer();
    char letter = usart_receive();
    while (letter != '\n') {
        write_buffer(letter);
        letter = usart_receive();
    }
    return success_fail_buffer();
}

// **TWI (I2C) Functions**

// TWI Status Codes
#define TW_START 0x08
#define TW_REP_START 0x10
#define TW_MT_SLA_ACK 0x18
#define TW_MT_SLA_NACK 0x20
#define TW_MT_DATA_ACK 0x28
#define TW_MR_SLA_ACK 0x40
#define TW_MR_SLA_NACK 0x48
#define TW_MR_DATA_NACK 0x58

#define TW_STATUS_MASK 0xF8
#define TW_STATUS (TWSR0 & TW_STATUS_MASK)

uint8_t PREVIOUS = 0;  // Store previous output value

void twi_init() {
    // Initialize TWI clock
    TWSR0 = 0;  // Prescaler = 1
    TWBR0 = TWBR0_VALUE;  // Set TWI bit rate
}

unsigned char twi_start(unsigned char address) {
    // Send START condition and address
    uint8_t twi_status;

    // Send START condition
    TWCR0 = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);
    while (!(TWCR0 & (1 << TWINT)));  // Wait for TWINT Flag set

    // Check TWI Status
    twi_status = TW_STATUS;
    if ((twi_status != TW_START) && (twi_status != TW_REP_START))
        return 1;  // START condition failed

    // Send device address
    TWDR0 = address;
    TWCR0 = (1 << TWINT) | (1 << TWEN);
    while (!(TWCR0 & (1 << TWINT)));  // Wait for TWINT Flag set

    // Check TWI Status
    twi_status = TW_STATUS;
    if ((twi_status != TW_MT_SLA_ACK) && (twi_status != TW_MR_SLA_ACK))
        return 1;  // SLA+W or SLA+R failed

    return 0;  // Success
}

unsigned char twi_write(unsigned char data) {
    // Send data to TWI device
    TWDR0 = data;
    TWCR0 = (1 << TWINT) | (1 << TWEN);
    while (!(TWCR0 & (1 << TWINT)));  // Wait for TWINT Flag set

    // Check TWI Status
    if ((TW_STATUS & TW_STATUS_MASK) != TW_MT_DATA_ACK)
        return 1;  // Data ACK failed

    return 0;  // Success
}

void twi_stop() {
    // Send STOP condition
    TWCR0 = (1 << TWINT) | (1 << TWEN) | (1 << TWSTO);
    while (TWCR0 & (1 << TWSTO));  // Wait for STOP condition to be executed
}

// **PCA9555 Functions**

// PCA9555 Registers Enumeration
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

void PCA9555_0_write(PCA9555_REGISTERS reg, uint8_t value) {
    // Write to PCA9555 register
    PREVIOUS = value;
    twi_start(PCA9555_0_ADDRESS + TWI_WRITE);  // Start TWI communication
    twi_write(reg);                            // Write register address
    twi_write(value);                          // Write data
    twi_stop();                                // Stop TWI communication
}

uint8_t PCA9555_0_read(PCA9555_REGISTERS reg) {
    // Read from PCA9555 register
    uint8_t ret_val;

    twi_start(PCA9555_0_ADDRESS + TWI_WRITE);  // Start TWI communication
    twi_write(reg);                            // Write register address
    twi_start(PCA9555_0_ADDRESS + TWI_READ);   // Repeated start for read
    TWCR0 = (1 << TWINT) | (1 << TWEN);        // Start TWI read
    while (!(TWCR0 & (1 << TWINT)));           // Wait for TWINT Flag set
    ret_val = TWDR0;                           // Read data
    twi_stop();                                // Stop TWI communication

    return ret_val;
}

// **LCD Functions**

void write2(unsigned char input) {
    // Write data to LCD in 4-bit mode
    unsigned char prev = PREVIOUS;
    unsigned char write;

    // Send higher nibble
    write = (input & 0xF0) | (prev & 0x0F);
    PCA9555_0_write(REG_OUTPUT_0, write);

    // Toggle Enable pin
    write |= (1 << 3);  // Set E high
    PCA9555_0_write(REG_OUTPUT_0, write);
    write &= ~(1 << 3); // Set E low
    PCA9555_0_write(REG_OUTPUT_0, write);

    // Send lower nibble
    write = ((input & 0x0F) << 4) | (prev & 0x0F);
    PCA9555_0_write(REG_OUTPUT_0, write);

    // Toggle Enable pin
    write |= (1 << 3);  // Set E high
    PCA9555_0_write(REG_OUTPUT_0, write);
    write &= ~(1 << 3); // Set E low
    PCA9555_0_write(REG_OUTPUT_0, write);
}

void lcd_data(unsigned char input) {
    // Send data to LCD
    unsigned char prev = PREVIOUS;
    prev |= (1 << 2);  // Set RS high for data
    PCA9555_0_write(REG_OUTPUT_0, prev);
    write2(input);     // Write data
    _delay_us(250);    // Delay for processing
}

void lcd_command(unsigned char input) {
    // Send command to LCD
    unsigned char prev = PREVIOUS;
    prev &= ~(1 << 2);  // Set RS low for command
    PCA9555_0_write(REG_OUTPUT_0, prev);
    write2(input);      // Write command
    _delay_us(250);     // Delay for processing
}

void lcd_nextline() {
    // Move cursor to next line on LCD
    lcd_command(0xC0);  // Command to move to second line
}

void lcd_clear() {
    // Clear LCD display
    lcd_command(0x01);  // Clear display command
    _delay_ms(5);       // Delay for command execution
}

void lcd_init() {
    // Initialize LCD
    _delay_ms(200);  // Wait for LCD to power up

    // Function set: 8-bit mode (sent three times as per initialization sequence)
    for (uint8_t i = 0; i < 3; i++) {
        lcd_command(0x30);
        _delay_us(250);
    }

    // Function set: 4-bit mode
    lcd_command(0x20);
    _delay_us(250);

    // Function set: 4-bit mode, 2 lines, 5x8 font
    lcd_command(0x28);
    _delay_us(250);

    // Display ON, Cursor OFF, Blink OFF
    lcd_command(0x0C);
    _delay_us(250);

    // Clear display
    lcd_clear();

    // Entry mode set: Increment cursor, No shift
    lcd_command(0x06);
    _delay_us(250);
}

void display_string(char arr[]) {
    // Display a string on LCD
    uint8_t i = 0;
    while (arr[i] != '\0') {
        lcd_data(arr[i]);  // Send each character to LCD
        i++;
    }
}

// **Main Function**

int main(void) {
    // Initialize TWI (I2C) communication
    twi_init();

    // Configure PCA9555 ports
    PCA9555_0_write(REG_CONFIGURATION_0, 0x00);  // Set all pins of Port 0 as outputs
    PCA9555_0_write(REG_CONFIGURATION_1, 0xF0);  // Set lower 4 bits of Port 1 as outputs

    // Initialize LCD
    lcd_init();

    // Initialize UART
    usart_init(UBRR_VALUE);

    // Initialize buffer
    init_buffer();

    while (1) {
        lcd_clear();  // Clear LCD display

        // Send connect command to ESP8266
        transmit_string("ESP:connect\n");

        // Receive response and check for success or fail
        if (!receive_success_fail()) {
            display_string("1.Fail");  // Display "1.Fail" on LCD

            // Retry sending connect command
            transmit_string("ESP:connect\n");
            if (receive_success_fail()) {
                lcd_clear();
            } else {
                _delay_ms(5000);  // Wait before retrying
                continue;
            }
        }

        display_string("1.Success");  // Display "1.Success" on LCD
        lcd_nextline();               // Move to next line

        // Send URL command to ESP8266
        transmit_string("ESP:url:\"");
        transmit_string(URL);
        transmit_string("\"\n");

        // Receive response and display result
        if (receive_success_fail()) {
            display_string("2.Success");  // Display "2.Success"
        } else {
            display_string("2.Fail");     // Display "2.Fail"
        }

        _delay_ms(5000);  // Wait to allow reading the message
    }
}
