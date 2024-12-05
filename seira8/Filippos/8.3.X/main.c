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

// Temperature Offset
#define TEMP_OFFSET 9.0  // Calibration offset for temperature sensor

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

void display_buffer() {
    // Display the contents of the buffer on the LCD
    for (uint8_t i = 0; i < buffer_pointer; i++) {
        lcd_data(buffer[i]);
    }
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
    UBRR0H = (unsigned char)(ubrr >> 8);   // Set baud rate high byte
    UBRR0L = (unsigned char)ubrr;          // Set baud rate low byte
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

void twi_start_wait(unsigned char address) {
    // Send START condition and wait until device is ready
    uint8_t twi_status;

    while (1) {
        // Send START condition
        TWCR0 = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);
        while (!(TWCR0 & (1 << TWINT)));  // Wait for TWINT Flag set

        // Check TWI Status
        twi_status = TW_STATUS;
        if ((twi_status != TW_START) && (twi_status != TW_REP_START))
            continue;  // START condition failed, retry

        // Send device address
        TWDR0 = address;
        TWCR0 = (1 << TWINT) | (1 << TWEN);
        while (!(TWCR0 & (1 << TWINT)));  // Wait for TWINT Flag set

        // Check TWI Status
        twi_status = TW_STATUS;
        if ((twi_status != TW_MT_SLA_ACK) && (twi_status != TW_MR_SLA_ACK)) {
            // Device busy, send STOP condition
            TWCR0 = (1 << TWINT) | (1 << TWEN) | (1 << TWSTO);
            while (TWCR0 & (1 << TWSTO));  // Wait for STOP condition
            continue;  // Retry
        }
        break;  // Device ready
    }
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

unsigned char twi_rep_start(unsigned char address) {
    // Send repeated START condition
    return twi_start(address);
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
    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);  // Start TWI communication
    twi_write(reg);                                 // Write register address
    twi_write(value);                               // Write data
    twi_stop();                                     // Stop TWI communication
}

uint8_t PCA9555_0_read(PCA9555_REGISTERS reg) {
    // Read from PCA9555 register
    uint8_t ret_val;

    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);  // Start TWI communication
    twi_write(reg);                                 // Write register address
    twi_rep_start(PCA9555_0_ADDRESS + TWI_READ);    // Repeated start for read
    ret_val = twi_readNak();                        // Read data with NAK
    twi_stop();                                     // Stop TWI communication

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

// **Temperature Sensor Functions (One-Wire Protocol)**

uint8_t one_wire_reset() {
    // Reset One-Wire bus and detect presence of device
    DDRD |= (1 << 4);  // Set PD4 as output
    PORTD &= ~(1 << 4);  // Pull line low
    _delay_us(480);     // Keep line low for reset pulse

    DDRD &= ~(1 << 4);  // Release line (input mode)
    PORTD &= ~(1 << 4); // Disable pull-up resistor
    _delay_us(100);     // Wait for presence pulse

    uint8_t temp = PIND & (1 << 4);  // Read presence pulse
    _delay_us(380);  // Wait for end of timeslot

    return (temp == 0) ? 1 : 0;  // Return 1 if device is present
}

uint8_t one_wire_receive_bit() {
    // Receive a bit from One-Wire device
    DDRD |= (1 << 4);   // Set PD4 as output
    PORTD &= ~(1 << 4); // Pull line low
    _delay_us(2);       // Short low pulse

    DDRD &= ~(1 << 4);  // Release line (input mode)
    PORTD &= ~(1 << 4); // Disable pull-up resistor
    _delay_us(10);      // Wait before reading

    uint8_t temp = (PIND & (1 << 4)) ? 1 : 0;  // Read bit
    _delay_us(49);  // Wait for end of timeslot

    return temp;
}

void one_wire_transmit_bit(uint8_t bit) {
    // Transmit a bit to One-Wire device
    DDRD |= (1 << 4);  // Set PD4 as output
    PORTD &= ~(1 << 4);  // Pull line low
    _delay_us(2);      // Short low pulse

    if (bit) {
        PORTD |= (1 << 4);  // Release line for '1' bit
    } else {
        PORTD &= ~(1 << 4); // Keep line low for '0' bit
    }

    _delay_us(58);  // Hold bit duration
    DDRD &= ~(1 << 4);  // Release line
    PORTD &= ~(1 << 4); // Disable pull-up resistor
    _delay_us(1);   // Recovery time
}

uint8_t one_wire_receive_byte() {
    // Receive a byte from One-Wire device
    uint8_t output = 0x00;

    for (uint8_t i = 0; i < 8; i++) {
        output >>= 1;
        if (one_wire_receive_bit()) {
            output |= 0x80;  // Set MSB if bit is '1'
        }
    }

    return output;
}

void one_wire_transmit_byte(uint8_t byte) {
    // Transmit a byte to One-Wire device
    for (uint8_t i = 0; i < 8; i++) {
        one_wire_transmit_bit(byte & 0x01);
        byte >>= 1;
    }
}

uint16_t temp() {
    // Read temperature from DS18B20 sensor
    if (!one_wire_reset()) {
        return 0x8000;  // Error: device not present
    }

    one_wire_transmit_byte(0xCC);  // Skip ROM command
    one_wire_transmit_byte(0x44);  // Convert T command

    while (!one_wire_receive_bit());  // Wait for conversion to complete

    if (!one_wire_reset()) {
        return 0x8000;  // Error: device not present
    }

    one_wire_transmit_byte(0xCC);  // Skip ROM command
    one_wire_transmit_byte(0xBE);  // Read Scratchpad command

    uint16_t output = one_wire_receive_byte();       // Read LSB
    output |= ((uint16_t)one_wire_receive_byte()) << 8;  // Read MSB

    return output;  // Return raw temperature reading
}

double get_temp() {
    // Convert raw temperature to degrees Celsius
    uint16_t reading = temp();
    if (reading == 0x8000) return 0;  // Error reading

    int16_t val = (int16_t)reading;  // Convert to signed integer
    double temperature_val = val / 16.0;  // DS18B20 provides 1/16°C resolution

    return temperature_val + TEMP_OFFSET;  // Apply calibration offset
}

// **Keypad Functions**

const uint8_t rows[] = {0b11111110, 0b11111101, 0b11111011, 0b11110111};  // Row patterns
const char characters[] = {'1','2','3','A','4','5','6','B','7','8','9','C','*','0','#','D'};  // Key mapping
uint16_t pressed_keys = 0x0000;  // Stores pressed keys

uint8_t scan_row(uint8_t row) {
    // Scan a single row of the keypad
    PCA9555_0_write(REG_OUTPUT_1, rows[row]);  // Set row pattern
    uint8_t input = PCA9555_0_read(REG_INPUT_1);  // Read columns
    input = ~input;  // Invert bits (active low)
    return input >> 4;  // Return column bits
}

uint16_t scan_keypad() {
    // Scan the entire keypad
    uint16_t output = 0x0000;
    uint8_t temp;
    for (uint8_t i = 0; i < 4; i++) {
        output <<= 4;
        temp = scan_row(i) & 0x0F;
        output |= temp;
    }
    return output;
}

void scan_keypad_rising_edge() {
    // Detect rising edge (new key presses)
    uint16_t pressed_keys_tempo = scan_keypad();
    _delay_ms(10);  // Debounce delay
    pressed_keys_tempo &= scan_keypad();  // Confirm key press
    pressed_keys = pressed_keys_tempo & (~pressed_keys);  // Store new presses
}

char keypad_to_ascii(uint16_t keys) {
    // Convert key press to ASCII character
    uint16_t test = 1;
    for (uint8_t i = 0; i < 16; i++) {
        if (keys & test) {
            return characters[i];  // Return corresponding character
        }
        test <<= 1;
    }
    return '\0';  // No key pressed
}

// **ADC Functions (Pressure Sensor)**

double get_pressure() {
    // Read pressure value from ADC
    ADCSRA |= (1 << ADSC);  // Start ADC conversion
    while (ADCSRA & (1 << ADSC));  // Wait for conversion to complete

    // Calculate pressure in appropriate units
    double pressure = ADC * 20.0 / 1024.0;  // Scale ADC value

    return pressure;
}

// **Helper Functions for Data Transmission**

unsigned char thousands, hundreds, tens, units;

void binary_to_bcd(uint16_t input) {
    // Convert binary number to BCD digits
    thousands = input / 1000;
    input %= 1000;

    hundreds = input / 100;
    input %= 100;

    tens = input / 10;
    units = input % 10;
}

void transmit_temp(double input) {
    // Transmit temperature value over UART
    uint8_t negative_sign = (input < 0) ? 1 : 0;

    if (negative_sign) input = -input;

    uint16_t integer = (uint16_t)input;
    uint16_t decimal = (uint16_t)((input - integer) * 10000);

    binary_to_bcd(integer);

    if (negative_sign) {
        usart_transmit('-');
    }

    if (hundreds != 0) usart_transmit(hundreds + '0');
    if (tens != 0 || hundreds != 0) usart_transmit(tens + '0');
    usart_transmit(units + '0');
    usart_transmit('.');

    binary_to_bcd(decimal);
    usart_transmit(units + '0');
}

void transmit_pressure(double input) {
    // Transmit pressure value over UART
    uint16_t integer = (uint16_t)input;
    uint16_t decimal = (uint16_t)((input - integer) * 10000);

    binary_to_bcd(integer);

    if (tens != 0) usart_transmit(tens + '0');
    usart_transmit(units + '0');
    usart_transmit('.');

    binary_to_bcd(decimal);
    usart_transmit(thousands + '0');
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

    // Initialize buffer
    init_buffer();

    // ADC Setup for Pressure Sensor (POT0)
    ADMUX = (1 << REFS0);  // Reference voltage: AVcc
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);  // Enable ADC, prescaler=128

    // Initialize UART
    usart_init(UBRR_VALUE);

    uint8_t nurseStatus = 0;  // Variable to track nurse call status

    // Restart ESP8266
    transmit_string("ESP:restart\n");
    char letter = usart_receive();
    while (letter != '\n') {
        letter = usart_receive();
    }
    letter = usart_receive();
    while (letter != '\n') {
        letter = usart_receive();
    }

    while (1) {
        lcd_clear();  // Clear LCD display

        // Send connect command to ESP8266
        transmit_string("ESP:connect\n");

        // Receive response and check for success or fail
        if (!receive_success_fail()) {
            display_string("1.Fail");  // Display "1.Fail" on LCD
            lcd_nextline();
            display_string("Rec:");
            display_buffer();  // Show received buffer
            _delay_ms(1000);
            transmit_string("ESP:connect\n");
            if (receive_success_fail()) {
                lcd_clear();
            } else {
                continue;  // Retry
            }
        }
        display_string("1.Success");  // Display "1.Success" on LCD
        lcd_nextline();
        display_string("Rec:");
        display_buffer();  // Show received buffer

        _delay_ms(1000);

        // Send URL command to ESP8266
        transmit_string("ESP:url:\"");
        transmit_string(URL);
        transmit_string("\"\n");

        lcd_clear();

        if (receive_success_fail()) {
            display_string("2.Success");  // Display "2.Success"
        } else {
            display_string("2.Fail");     // Display "2.Fail"
            lcd_nextline();
            display_string("Rec:");
            display_buffer();
            _delay_ms(1000);
            continue;
        }

        lcd_nextline();
        display_string("Rec:");
        display_buffer();

        _delay_ms(1000);

        // Read temperature and pressure
        double temp = get_temp();
        double pressure = get_pressure();

        // Check keypad input for nurse call
        char pressed_char = keypad_to_ascii(scan_keypad());
        if (pressed_char == '7') {
            nurseStatus = 1;  // Nurse call activated
        } else if (pressed_char == '#') {
            nurseStatus = 0;  // Nurse call deactivated
        }

        // Prepare payload for ESP8266
        transmit_string("ESP:payload:[{\"name\": \"temperature\", \"value\": \"");
        transmit_temp(temp);
        transmit_string("\"},{\"name\": \"pressure\", \"value\": \"");
        transmit_pressure(pressure);
        transmit_string("\"},{\"name\": \"team\", \"value\": \"17\"},{\"name\": \"status\", \"value\": \"");

        // Determine status message
        if (nurseStatus) {
            transmit_string("NURSE CALL");
        } else if (pressure > 12 || pressure < 4) {
            transmit_string("CHECK PRESSURE");
        } else if (temp > 37 || temp < 34) {
            transmit_string("CHECK TEMP");
        } else {
            transmit_string("OK");
        }

        transmit_string("\"}]\n");

        lcd_clear();

        if (receive_success_fail()) {
            display_string("3.Success");  // Display "3.Success"
        } else {
            display_string("3.Fail");     // Display "3.Fail"
            _delay_ms(1000);
            continue;
        }

        lcd_nextline();
        display_string("Rec:");
        display_buffer();

        _delay_ms(1000);

        // Send transmit command to ESP8266
        transmit_string("ESP:transmit\n");

        lcd_clear();

        display_string("4.Success");
        lcd_nextline();
        init_buffer();

        // Receive and display response
        char readChar = usart_receive();
        while (readChar != '\n') {
            write_buffer(readChar);
            readChar = usart_receive();
        }

        display_buffer();

        _delay_ms(5000);  // Wait to allow reading the message
    }
}
