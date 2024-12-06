## **Σκοπός της Άσκησης 8.1**

Η άσκηση ζητάει να γράψουμε ένα πρόγραμμα για τον μικροελεγκτή ATmega328PB που θα:

1. Στείλει την εντολή `ESP:connect` μέσω UART στο ESP8266.
2. Διαβάσει την απάντηση του ESP8266 ("Success" ή "Fail").
3. Εμφανίσει το αποτέλεσμα στην LCD οθόνη ως "1.Success" ή "1.Fail".
4. Στη συνέχεια, θα επαναλάβει την ίδια διαδικασία για την εντολή `ESP:url:"http://192.168.1.250:5000/data"` και θα εμφανίσει "2.Success" ή "2.Fail".
5. Προσθέτει μια καθυστέρηση πριν την αποστολή της δεύτερης εντολής για να δειτε τα μηνύματα στην LCD.

Ας δούμε αναλυτικά τον κώδικα που επιτυγχάνει αυτό το σκοπό.

---

## **Επικεφαλίδες και Ορισμοί (Preprocessor Directives and Definitions)**

```c
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

#define UBRR_VALUE 103
#define URL "http://192.168.1.250:5000/data"

#define PCA9555_0_ADDRESS 0x40  // A0=A1=A2=0 by hardware
#define TWI_READ 1              // reading from twi device
#define TWI_WRITE 0             // writing to twi device
#define SCL_CLOCK 100000L       // twi clock in Hz

//Fscl=Fcpu/(16+2*TWBR0_VALUE*PRESCALER_VALUE)
#define TWBR0_VALUE ((F_CPU/SCL_CLOCK)-16)/2
```

### **1. Ορισμός Συχνότητας Κύκλου Ρολογιού**

```c
#define F_CPU 16000000UL
```

- **F_CPU**: Καθορίζει τη συχνότητα λειτουργίας του μικροελεγκτή σε Hertz. Εδώ είναι 16 MHz, που είναι η συχνότητα του ATmega328PB.

### **2. Συμπερίληψη Βιβλιοθηκών**

```c
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
```

- **avr/io.h**: Παρέχει ορισμούς για είσοδοι/έξοδοι του AVR.
- **util/delay.h**: Παρέχει συναρτήσεις καθυστέρησης όπως `_delay_ms()`.
- **avr/interrupt.h**: Διαχείριση των διακοπών (interrupts).

### **3. Ορισμοί για UART και TWI (I²C)**

```c
#define UBRR_VALUE 103
#define URL "http://192.168.1.250:5000/data"

#define PCA9555_0_ADDRESS 0x40  // A0=A1=A2=0 by hardware
#define TWI_READ 1              // reading from twi device
#define TWI_WRITE 0             // writing to twi device
#define SCL_CLOCK 100000L       // twi clock in Hz

//Fscl=Fcpu/(16+2*TWBR0_VALUE*PRESCALER_VALUE)
#define TWBR0_VALUE ((F_CPU/SCL_CLOCK)-16)/2
```

- **UBRR_VALUE**: Ορίζει την τιμή του καταχωρητή baud rate για UART. Η τιμή 103 αντιστοιχεί σε BAUD=9600 με F_CPU=16MHz.
- **URL**: Η διεύθυνση URL που θα χρησιμοποιηθεί στην εντολή `ESP:url`.
- **PCA9555_0_ADDRESS**: Η διεύθυνση του TWI (I²C) εξαρτημένου PCA9555. Το PCA9555 είναι ένας εξωτερικός εκτατικός οδηγός (I/O expander) που χρησιμοποιείται για τον έλεγχο της LCD.
- **TWI_READ και TWI_WRITE**: Καθορίζουν την κατεύθυνση της επικοινωνίας (ανάγνωση ή εγγραφή).
- **SCL_CLOCK**: Η συχνότητα του ρολογιού για το TWI (100kHz).
- **TWBR0_VALUE**: Υπολογισμός του καταχωρητή baud rate για TWI. Χρησιμοποιείται ο τύπος για τον υπολογισμό του TWBR0.

---

## **Διαχείριση Buffer για UART Επικοινωνία**

```c
char buffer[50];
uint8_t buffer_pointer = 0;

const char success[] = "\"Success\"";

void init_buffer() {
    buffer_pointer = 0;
}

void write_buffer(char c) {
    buffer[buffer_pointer] = c;
    buffer_pointer++;
    
    if (buffer_pointer == 50) buffer_pointer = 0;
}

void display_buffer() {
    for (uint8_t i = 0; i < buffer_pointer; i++) {
        lcd_data(buffer[i]);
    }
}

uint8_t success_fail_buffer() {
    if (buffer_pointer < 2) return 0;
    for (uint8_t i = 0; i < 2; i++) {
        if (buffer[i] != success[i]) {
            return 0;
        }
    }
    return 1;
}
```

### **1. Ορισμός Buffer**

```c
char buffer[50];
uint8_t buffer_pointer = 0;
```

- **buffer**: Ένας πίνακας χαρακτήρων που χρησιμοποιείται για την αποθήκευση της λήψης από την UART.
- **buffer_pointer**: Δείκτης που κρατάει την τρέχουσα θέση στο buffer για την αποθήκευση χαρακτήρων.

### **2. Σταθερά Success**

```c
const char success[] = "\"Success\"";
```

- **success**: Μια σταθερά που περιέχει το αναμενόμενο μήνυμα από το ESP8266. Είναι σημαντικό να περιλαμβάνει τα εισαγωγικά όπως αναφέρεται στις απαιτήσεις.

### **3. Συνάρτηση Αρχικοποίησης Buffer**

```c
void init_buffer() {
    buffer_pointer = 0;
}
```

- **init_buffer()**: Επαναφέρει τον δείκτη του buffer στην αρχή, καθιστώντας τον έτοιμο για νέα δεδομένα.

### **4. Συνάρτηση Εγγραφής σε Buffer**

```c
void write_buffer(char c) {
    buffer[buffer_pointer] = c;
    buffer_pointer++;
    
    if (buffer_pointer == 50) buffer_pointer = 0;
}
```

- **write_buffer(char c)**: Προσθέτει έναν χαρακτήρα στο buffer και αυξάνει τον δείκτη. Αν ο δείκτης φτάσει στο μέγιστο (50), επαναφέρεται στην αρχή για αποφυγή υπερχείλισης.

### **5. Συνάρτηση Εμφάνισης Buffer στην LCD**

```c
void display_buffer() {
    for (uint8_t i = 0; i < buffer_pointer; i++) {
        lcd_data(buffer[i]);
    }
}
```

- **display_buffer()**: Εμφανίζει τα περιεχόμενα του buffer στην LCD, χαρακτήρας-κατά-χαρακτήρα.

### **6. Συνάρτηση Ελέγχου Success ή Fail**

```c
uint8_t success_fail_buffer() {
    if (buffer_pointer < 2) return 0;
    for (uint8_t i = 0; i < 2; i++) {
        if (buffer[i] != success[i]) {
            return 0;
        }
    }
    return 1;
}
```

- **success_fail_buffer()**: Ελέγχει αν τα πρώτα δύο στοιχεία του buffer αντιστοιχούν στην σταθερά `success`. Επιστρέφει `1` αν ταιριάζουν, αλλιώς `0`. Αυτό βοηθά στον έλεγχο αν η απάντηση είναι "Success" ή "Fail".

---

## **Συναρτήσεις UART**

### **1. Αρχικοποίηση UART**

```c
void usart_init(uint16_t ubrr) {
    UCSR0A = 0;
    UCSR0B = (1<<RXEN0) | (1<<TXEN0);
    UBRR0H = (uint8_t) (ubrr>>8);
    UBRR0L = (uint8_t) ubrr;
    UCSR0C = (3 << UCSZ00);    
}
```

- **usart_init(uint16_t ubrr)**: Αρχικοποιεί την UART με τις καθορισμένες παραμέτρους.
    - **UCSR0A = 0**: Καθαρίζει το καταχωρητή κατάστασης.
    - **UCSR0B**: Ενεργοποιεί τον δέκτη (`RXEN0`) και τον πομπό (`TXEN0`).
    - **UBRR0H και UBRR0L**: Ορίζει το baud rate μέσω του καταχωρητή UBRR0 (103 για BAUD=9600).
    - **UCSR0C**: Ρυθμίζει την UART σε 8-bit δεδομένα (UCSZ00 και UCSZ01 = 1).

### **2. Συναρτήσεις Αποστολής και Λήψης Δεδομένων**

```c
void usart_transmit(uint8_t data) {
    while (!(UCSR0A & (1<<UDRE0)));
    UDR0 = data;
}

char usart_receive() {
    while (!(UCSR0A & (1<<RXC0)));
    return UDR0;
}
```

- **usart_transmit(uint8_t data)**: Περιμένει μέχρι το UART να είναι έτοιμο για αποστολή (UDRE0 = 1) και στέλνει έναν χαρακτήρα μέσω του UDR0.
- **usart_receive()**: Περιμένει μέχρι να ληφθεί ένας χαρακτήρας (RXC0 = 1) και επιστρέφει τον χαρακτήρα από το UDR0.

### **3. Συνάρτηση Αποστολής Αλφαριθμητικού**

```c
void transmit_string(char arr[]) {
    uint8_t i = 0;
    while (arr[i] != '\n' && arr[i] != '\0') {
        usart_transmit(arr[i]);
        i++;
    }
    if (arr[i] != '\0') usart_transmit(arr[i]);
}
```

- **transmit_string(char arr[])**: Στέλνει μια αλφαριθμητική συμβολοσειρά μέσω UART μέχρι να συναντήσει χαρακτήρα αλλαγής γραμμής `\n` ή τον τερματισμό της συμβολοσειράς `\0`.
    - Εάν συναντήσει `\n`, τον στέλνει επίσης.
    - Αυτό εξασφαλίζει ότι η τελευταία εντολή έχει το σωστό χαρακτήρα αλλαγής γραμμής όπως απαιτείται.

### **4. Συνάρτηση Λήψης και Ελέγχου Success/Fail**

```c
uint8_t receive_success_fail() {
    init_buffer();
    char letter = usart_receive();
    while (letter != '\n') {
        write_buffer(letter);
        letter = usart_receive();
    }
    return success_fail_buffer();
}
```

- **receive_success_fail()**:
    1. **init_buffer()**: Επαναφέρει το buffer για νέα δεδομένα.
    2. **usart_receive()**: Λαμβάνει χαρακτήρες μέχρι να συναντήσει `\n`.
    3. **write_buffer(letter)**: Αποθηκεύει τους χαρακτήρες στο buffer.
    4. **success_fail_buffer()**: Ελέγχει αν τα πρώτα δύο στοιχεία του buffer είναι `"Success"`.

- **Επιστρέφει**:
    - `1` αν η απάντηση είναι "Success".
    - `0` αν η απάντηση είναι "Fail" ή κάτι άλλο.

---

## **Συναρτήσεις για τον Έλεγχο I²C μέσω PCA9555**

### **1. Ορισμός Καταχωρητών PCA9555**

```c
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
```

- **PCA9555_REGISTERS**: Ορισμός των καταχωρητών του PCA9555 που θα χρησιμοποιηθούν για την επικοινωνία μέσω I²C.

### **2. Ορισμοί Καταστάσεων TWI**

```c
#define TW_START 0x08
#define TW_REP_START 0x10
#define TW_MT_SLA_ACK 0x18
#define TW_MT_SLA_NACK 0x20
#define TW_MT_DATA_ACK 0x28
#define TW_MR_SLA_ACK 0x40
#define TW_MR_SLA_NACK 0x48
#define TW_MR_DATA_NACK 0x58

#define TW_STATUS_MASK 0b11111000
#define TW_STATUS (TWSR0 & TW_STATUS_MASK)
```

- **TW_START και TW_REP_START**: Καταστάσεις που υποδεικνύουν την αποστολή αρχικής ή επαναληπτικής σήμανσης.
- **TW_MT_SLA_ACK/NACK και TW_MR_SLA_ACK/NACK**: Καταστάσεις που υποδεικνύουν αν η αποστολή της διεύθυνσης SLA ήταν επιτυχής ή όχι.
- **TW_MT_DATA_ACK/NACK και TW_MR_DATA_NACK**: Καταστάσεις για την επιβεβαίωση της λήψης δεδομένων.
- **TW_STATUS_MASK και TW_STATUS**: Μασκάρει και ανακτά την κατάσταση του TWI από τον καταχωρητή TWSR0.

### **3. Διαχείριση TWI (I²C)**

#### **Αρχικοποίηση TWI**

```c
void twi_init() {
    TWSR0 = 0;              // Prescaler = 1
    TWBR0 = TWBR0_VALUE;    // SCL clock 100kHz
}
```

- **twi_init()**: Αρχικοποιεί το TWI (I²C) με prescaler=1 και καθορίζει το ρολόι SCL στα 100kHz χρησιμοποιώντας τον υπολογισμένο TWBR0_VALUE.

#### **Συναρτήσεις Ανάγνωσης (Read)**

```c
unsigned char twi_readAck() {
    TWCR0 = (1<<TWINT) | (1<<TWEN) | (1<<TWEA);
    while (!(TWCR0 & (1<<TWINT)));
    
    return TWDR0;
}

unsigned char twi_readNak() {
    TWCR0 = (1<<TWINT) | (1<<TWEN);
    while (!(TWCR0 & (1<<TWINT)));
    
    return TWDR0;
}
```

- **twi_readAck()**: Διαβάζει έναν byte δεδομένων και στέλνει ACK (Acknowledgment).
- **twi_readNak()**: Διαβάζει έναν byte δεδομένων και στέλνει NACK (Not Acknowledgment).

#### **Συναρτήσεις Αποστολής και Έναρξης (Start)**

```c
unsigned char twi_start(unsigned char address) {
    uint8_t twi_status;
    
    // Send START
    TWCR0 = (1<<TWINT) | (1<<TWSTA) | (1<<TWEN);
    
    // Wait till START transmission is completed
    while (!(TWCR0 & (1<<TWINT)));
    
    // Check TWI Status
    twi_status = TW_STATUS & 0xF8;
    if ((twi_status != TW_START) && (twi_status != TW_REP_START))
        return 1;
    
    // Send device address
    TWDR0 = address;
    TWCR0 = (1<<TWINT) | (1<<TWEN);
    
    // Wait till address transmission is completed and ACK/NACK has been received.
    while (!(TWCR0 & (1<<TWINT)));
    
    // Check TWI Status
    twi_status = TW_STATUS & 0xF8;
    if ((twi_status != TW_MT_SLA_ACK) && (twi_status != TW_MR_SLA_ACK))
        return 1;
    
    return 0;
}

unsigned char twi_rep_start(unsigned char address) {
    return twi_start(address);
}
```

- **twi_start(unsigned char address)**: Στέλνει την αρχική σήμανση START, τη διεύθυνση της συσκευής (address) και ελέγχει την απόκριση (ACK/NACK). Επιστρέφει `0` για επιτυχία και `1` για αποτυχία.
- **twi_rep_start(unsigned char address)**: Χρησιμοποιεί την ίδια συνάρτηση `twi_start` για επαναληπτική σήμανση START.

#### **Συναρτήσεις Εγγραφής και Τερματισμού (Stop)**

```c
unsigned char twi_write(unsigned char data) {
    // Send data to the (already addressed) device
    TWDR0 = data;
    TWCR0 = (1<<TWINT) | (1<<TWEN);
    
    // Wait till transmission finishes
    while (!(TWCR0 & (1<<TWINT)));
    
    if ((TW_STATUS & 0xF8) != TW_MT_DATA_ACK)
        return 1;
    return 0;
}

void twi_stop() {
    // Send STOP condition
    TWCR0 = (1<<TWINT) | (1<<TWEN) | (1<<TWSTO);
    
    // Wait till STOP condition is executed and bus released
    while (!(TWCR0 & (1<<TWSTO)));
}
```

- **twi_write(unsigned char data)**: Στέλνει έναν byte δεδομένων στη συσκευή και περιμένει για ACK. Επιστρέφει `0` για επιτυχία και `1` για αποτυχία.
- **twi_stop()**: Στέλνει την σήμανση STOP για να τερματίσει την επικοινωνία και περιμένει να ολοκληρωθεί.

---

### **4. Συνάρτηση Σταθερής Αναμονής (Wait)**

```c
void twi_start_wait(unsigned char address) {
    uint8_t twi_status;
    
    while (1) {
        // Send START
        TWCR0 = (1<<TWINT) | (1<<TWSTA) | (1<<TWEN);

        // Wait till START transmission is completed
        while (!(TWCR0 & (1<<TWINT)));

        // Check TWI Status
        twi_status = TW_STATUS & 0xF8;
        if ((twi_status != TW_START) && (twi_status != TW_REP_START))
            continue;

        // Send device address
        TWDR0 = address;
        TWCR0 = (1<<TWINT) | (1<<TWEN);

        // Wait till address transmission is completed and ACK/NACK has been received
        while (!(TWCR0 & (1<<TWINT)));

        // Check TWI Status
        twi_status = TW_STATUS & 0xF8;
        if ((twi_status != TW_MT_SLA_ACK) && (twi_status != TW_MR_SLA_ACK)) {
            // Device is busy, send STOP condition
            TWCR0 = (1<<TWINT) | (1<<TWEN) | (1<<TWSTO);
            
            // Wait till STOP condition is executed and bus released
            while (!(TWCR0 & (1<<TWSTO)));
            
            continue;
        }
        
        break;
    }
}
```

- **twi_start_wait(unsigned char address)**: Προσπαθεί συνεχώς να στείλει την σήμανση START και τη διεύθυνση της συσκευής μέχρι να λάβει ACK. Εάν η συσκευή είναι απασχολημένη, στέλνει STOP και προσπαθεί ξανά.

---

### **5. Συνάρτηση Εγγραφής PCA9555**

```c
void PCA9555_0_write(PCA9555_REGISTERS reg, uint8_t value) {
    PREVIOUS = value;
    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);
    twi_write(reg);
    twi_write(value);
    twi_stop();
}
```

- **PCA9555_0_write(PCA9555_REGISTERS reg, uint8_t value)**:
    1. Αποθηκεύει την προηγούμενη τιμή (`PREVIOUS`) για μελλοντική χρήση.
    2. Στέλνει σήμανση START και διεύθυνση για εγγραφή.
    3. Στέλνει την διεύθυνση του καταχωρητή (`reg`).
    4. Στέλνει την τιμή (`value`) στον καταχωρητή.
    5. Στέλνει σήμανση STOP για να τερματίσει την επικοινωνία.

### **6. Συνάρτηση Ανάγνωσης PCA9555**

```c
uint8_t PCA9555_0_read(PCA9555_REGISTERS reg) {
    uint8_t ret_val;
    
    twi_start_wait(PCA9555_0_ADDRESS + TWI_WRITE);
    twi_write(reg);
    twi_rep_start(PCA9555_0_ADDRESS + TWI_READ);
    ret_val = twi_readNak();
    twi_stop();
    
    return ret_val;
}
```

- **PCA9555_0_read(PCA9555_REGISTERS reg)**:
    1. Στέλνει σήμανση START και διεύθυνση για εγγραφή.
    2. Στέλνει την διεύθυνση του καταχωρητή που θέλουμε να διαβάσουμε.
    3. Στέλνει επαναληπτική σήμανση START και διεύθυνση για ανάγνωση.
    4. Διαβάζει ένα byte δεδομένων με NACK.
    5. Στέλνει σήμανση STOP.
    6. Επιστρέφει την τιμή που διαβάστηκε.

### **7. Συνάρτηση Εγγραφής Δεδομένων (write2)**

```c
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
```

- **write2(unsigned char input)**:
    - Χρησιμοποιείται για να γράψει δεδομένα στην LCD μέσω του PCA9555.
    - Διαιρεί τον χαρακτήρα σε δύο νήματα (high nibble και low nibble) για την αποστολή στην LCD.
    - Ενεργοποιεί και απενεργοποιεί το σήμα E (Enable) για την εκχώρηση των δεδομένων στην LCD.

### **8. Συναρτήσεις Ελέγχου LCD**

#### **lcd_data**

```c
void lcd_data(unsigned char input) {
    unsigned char prev = PREVIOUS;
    prev |= (1<<2);
    
    PCA9555_0_write(REG_OUTPUT_0, prev);
    write2(input);
    _delay_us(250);
}
```

- **lcd_data(unsigned char input)**:
    - Ενεργοποιεί τον δείκτη (RS = 1) για να στείλει δεδομένα στην LCD.
    - Καλεί τη `write2` για την αποστολή του χαρακτήρα.
    - Προσθέτει μια μικρή καθυστέρηση για την εκτέλεση της εντολής.

#### **lcd_command**

```c
void lcd_command(unsigned char input) {
    unsigned char prev = PREVIOUS;
    prev &= 0b11111011;
    
    PCA9555_0_write(REG_OUTPUT_0, prev);
    write2(input);
    _delay_us(250);
}
```

- **lcd_command(unsigned char input)**:
    - Απενεργοποιεί τον δείκτη (RS = 0) για να στείλει εντολές στην LCD.
    - Καλεί τη `write2` για την αποστολή της εντολής.
    - Προσθέτει μια μικρή καθυστέρηση για την εκτέλεση της εντολής.

#### **lcd_nextline, lcd_clear, lcd_init**

```c
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
```

- **lcd_nextline()**: Στέλνει την εντολή για μετάβαση στη δεύτερη γραμμή της LCD.
- **lcd_clear()**: Στέλνει την εντολή για καθαρισμό της LCD και περιμένει 5 ms για να ολοκληρωθεί.
- **lcd_init()**:
    - Εκτελεί τις απαραίτητες εντολές για την αρχικοποίηση της LCD.
    - Στέλνει τις εντολές για το 8-bit mode, την κατεύθυνση του cursor, και τον καθαρισμό της οθόνης.
    - Περιλαμβάνει αρκετές καθυστερήσεις για να διασφαλιστεί η σωστή εκτέλεση των εντολών από την LCD.

#### **Πρόσθετες Συναρτήσεις Εμφάνισης**

```c
void display_number(uint8_t input) {
    lcd_data(0b00110000 | (input & 0x0F));
}

void display_string(char arr[]) {
    uint8_t i = 0;
    while (arr[i] != '\0') {
        lcd_data(arr[i]);
        i++;
    }
}
```

- **display_number(uint8_t input)**: Εμφανίζει έναν αριθμό στην LCD μετατρέποντας τον σε ASCII χαρακτήρα.
- **display_string(char arr[])**: Εμφανίζει μια αλφαριθμητική συμβολοσειρά στην LCD χαρακτήρας-κατά-χαρακτήρα.

---

## **Κύρια Συνάρτηση (main)**

```c
int main(void) {
    // Enable TWI Communication for LCD
    twi_init();
        
    // Configure EXT_PORT1 as output
    PCA9555_0_write(REG_CONFIGURATION_0, 0x00);
    PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000);
    
    // Enable LCD
    lcd_init();
    
    usart_init(UBRR_VALUE);
    
    init_buffer();
    
    while (1) {
        lcd_clear();
        transmit_string("ESP:connect\n");

        if (!receive_success_fail()) {
            display_string("1.Fail");
            transmit_string("ESP:connect\n");
            if (receive_success_fail()) {
                lcd_clear();
            } else {
                _delay_ms(5000);
                continue;
            }
        }
        display_string("1.Success");
        lcd_nextline();
        
        transmit_string("ESP:url:\"");
        
        transmit_string(URL);
        
        transmit_string("\"\n");
        
        if (receive_success_fail()) {
            display_string("2.Success");
        } else {
            display_string("2.Fail");
        }
        
        _delay_ms(5000);
    }
}
```

### **1. Αρχικοποίηση TWI και PCA9555**

```c
twi_init();

// Configure EXT_PORT1 as output
PCA9555_0_write(REG_CONFIGURATION_0, 0x00);
PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000);
```

- **twi_init()**: Αρχικοποιεί το TWI για την επικοινωνία με τον PCA9555.
- **PCA9555_0_write(REG_CONFIGURATION_0, 0x00)**: Ρυθμίζει το EXT_PORT0 ως έξοδο.
- **PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000)**: Ρυθμίζει το EXT_PORT1 με τα πρώτα 4 pins ως έξοδο και τα υπόλοιπα ως είσοδο (λόγω της τιμής 0b11110000).

### **2. Αρχικοποίηση LCD και UART**

```c
lcd_init();
usart_init(UBRR_VALUE);
init_buffer();
```

- **lcd_init()**: Εκτελεί την αρχικοποίηση της LCD.
- **usart_init(UBRR_VALUE)**: Αρχικοποιεί την UART με το baud rate 9600.
- **init_buffer()**: Επαναφέρει τον δείκτη του buffer για νέες λήψεις δεδομένων.

### **3. Βρόχος Επανάληψης (Main Loop)**

```c
while (1) {
    lcd_clear();
    transmit_string("ESP:connect\n");

    if (!receive_success_fail()) {
        display_string("1.Fail");
        transmit_string("ESP:connect\n");
        if (receive_success_fail()) {
            lcd_clear();
        } else {
            _delay_ms(5000);
            continue;
        }
    }
    display_string("1.Success");
    lcd_nextline();
    
    transmit_string("ESP:url:\"");
    
    transmit_string(URL);
    
    transmit_string("\"\n");
    
    if (receive_success_fail()) {
        display_string("2.Success");
    } else {
        display_string("2.Fail");
    }
    
    _delay_ms(5000);
}
```

#### **Βήμα 1: Εκκαθάριση LCD και Αποστολή Εντολής "ESP:connect"**

```c
lcd_clear();
transmit_string("ESP:connect\n");
```

- **lcd_clear()**: Καθαρίζει την οθόνη της LCD.
- **transmit_string("ESP:connect\n")**: Στέλνει την εντολή `ESP:connect` στο ESP8266 μέσω UART, με το χαρακτήρα αλλαγής γραμμής `\n` στο τέλος όπως απαιτείται.

#### **Βήμα 2: Λήψη και Έλεγχος Απάντησης του ESP8266**

```c
if (!receive_success_fail()) {
    display_string("1.Fail");
    transmit_string("ESP:connect\n");
    if (receive_success_fail()) {
        lcd_clear();
    } else {
        _delay_ms(5000);
        continue;
    }
}
display_string("1.Success");
lcd_nextline();
```

- **if (!receive_success_fail())**: Αν η απάντηση δεν είναι "Success":
    - **display_string("1.Fail")**: Εμφανίζει "1.Fail" στην LCD.
    - **transmit_string("ESP:connect\n")**: Προσπαθεί ξανά να στείλει την εντολή `ESP:connect`.
    - **if (receive_success_fail())**:
        - Αν η δεύτερη προσπάθεια είναι επιτυχής, **lcd_clear()** καθαρίζει την LCD.
    - **else**:
        - Αν αποτύχει ξανά, **_delay_ms(5000)** προσθέτει καθυστέρηση 5 δευτερολέπτων και συνεχίζει τον βρόχο (`continue`).
- **display_string("1.Success")**: Αν η απάντηση είναι "Success", εμφανίζει "1.Success" στην LCD.
- **lcd_nextline()**: Μεταβαίνει στη δεύτερη γραμμή της LCD για την επόμενη εντολή.

#### **Βήμα 3: Αποστολή Εντολής "ESP:url"**

```c
transmit_string("ESP:url:\"");
transmit_string(URL);
transmit_string("\"\n");
```

- **transmit_string("ESP:url:\"")**: Στέλνει την αρχή της εντολής `ESP:url:"`.
- **transmit_string(URL)**: Στέλνει την διεύθυνση URL `http://192.168.1.250:5000/data`.
- **transmit_string("\"\n")**: Στέλνει το κλείσιμο των εισαγωγικών και τον χαρακτήρα αλλαγής γραμμής `\n`. Συνολικά, η εντολή που στέλνεται είναι `ESP:url:"http://192.168.1.250:5000/data"\n`.

#### **Βήμα 4: Λήψη και Έλεγχος Απάντησης για "ESP:url"**

```c
if (receive_success_fail()) {
    display_string("2.Success");
} else {
    display_string("2.Fail");
}

_delay_ms(5000);
```

- **if (receive_success_fail())**:
    - Αν η απάντηση είναι "Success", **display_string("2.Success")** εμφανίζει "2.Success" στην LCD.
    - Αλλιώς, **display_string("2.Fail")** εμφανίζει "2.Fail".
- **_delay_ms(5000)**: Προσθέτει καθυστέρηση 5 δευτερολέπτων πριν επαναλάβει τον βρόχο.

---

## **Συνολική Λειτουργία του Προγράμματος**

1. **Αρχικοποίηση**:
    - Το TWI αρχικοποιείται για επικοινωνία με τον PCA9555 (I/O expander).
    - Η PCA9555 ρυθμίζεται για να ελέγχει την LCD.
    - Η LCD αρχικοποιείται για εμφάνιση μηνυμάτων.
    - Η UART αρχικοποιείται για επικοινωνία με το ESP8266.
    - Το buffer αρχικοποιείται για νέα λήψη δεδομένων.

2. **Κύριος Βρόχος (Loop)**:
    - **Εντολή "ESP:connect"**:
        - Στέλνει `ESP:connect` μέσω UART.
        - Περιμένει την απάντηση ("Success" ή "Fail").
        - Εμφανίζει "1.Success" ή "1.Fail" στην LCD.
        - Αν αποτύχει, προσπαθεί ξανά να στείλει την εντολή.
        - Αν συνεχιστεί η αποτυχία, προσθέτει καθυστέρηση 5 δευτερολέπτων και επαναλαμβάνει τον βρόχο.
    
    - **Εντολή "ESP:url"**:
        - Στέλνει `ESP:url:"http://192.168.1.250:5000/data"\n` μέσω UART.
        - Περιμένει την απάντηση ("Success" ή "Fail").
        - Εμφανίζει "2.Success" ή "2.Fail" στην LCD.
        - Προσθέτει καθυστέρηση 5 δευτερολέπτων πριν επαναλάβει τον βρόχο.

---

## **Μεθοδολογία και Λογική του Προγράμματος**

1. **Αρχικοποίηση Επικοινωνίας**:
    - Η αρχικοποίηση του TWI και του UART είναι κρίσιμη για τη σωστή επικοινωνία με τον PCA9555 και το ESP8266.
    - Η ρύθμιση των καταχωρητών στο PCA9555 εξασφαλίζει ότι η LCD είναι σωστά ρυθμισμένη και έτοιμη για χρήση.

2. **Αποστολή Εντολών και Λήψη Απαντήσεων**:
    - Το πρόγραμμα στέλνει συγκεκριμένες εντολές (`ESP:connect` και `ESP:url:"..."`) στο ESP8266 μέσω UART.
    - Περιμένει την απάντηση του ESP8266 και ελέγχει αν η απάντηση είναι "Success" ή "Fail".
    - Εμφανίζει το αντίστοιχο μήνυμα στην LCD για οπτική επιβεβαίωση.

3. **Αντιμετώπιση Αποτυχιών**:
    - Αν η απάντηση είναι "Fail", το πρόγραμμα προσπαθεί ξανά να στείλει την εντολή.
    - Εάν αποτύχει και η δεύτερη προσπάθεια, προσθέτει μια καθυστέρηση 5 δευτερολέπτων πριν συνεχίσει.

4. **Επανάληψη Διεργασίας**:
    - Ο κύριος βρόχος συνεχίζει να επαναλαμβάνει τη διαδικασία αποστολής εντολών και λήψης απαντήσεων, διασφαλίζοντας συνεχή επικοινωνία με το ESP8266.

---

## **Επεξήγηση Κλειδιών Συναρτήσεων και Παραμέτρων**

### **usart_init()**

- **Σκοπός**: Ρυθμίζει την UART για επικοινωνία με το ESP8266.
- **Παράμετροι**:
    - **ubrr**: Καθορίζει το baud rate. Για BAUD=9600 και F_CPU=16MHz, η τιμή είναι 103.

### **transmit_string()**

- **Σκοπός**: Στέλνει μια αλφαριθμητική συμβολοσειρά μέσω UART μέχρι να συναντήσει `\n` ή `\0`.
- **Λόγος**: Διασφαλίζει ότι οι εντολές έχουν τον σωστό χαρακτήρα αλλαγής γραμμής.

### **receive_success_fail()**

- **Σκοπός**: Διαβάζει την απάντηση από το ESP8266 και ελέγχει αν είναι "Success" ή "Fail".
- **Επιστρέφει**:
    - `1` αν η απάντηση είναι "Success".
    - `0` αν η απάντηση είναι "Fail" ή κάτι άλλο.

### **lcd_init() και Συναρτήσεις Εμφάνισης**

- **Σκοπός**: Ρυθμίζει και ελέγχει την LCD μέσω του PCA9555.
- **Σημαντικές Εντολές**:
    - **0x01**: Καθαρισμός της LCD.
    - **0x0c**: Ενεργοποίηση της οθόνης χωρίς cursor.
    - **0x28**: Ρύθμιση λειτουργίας 4-bit mode, 2 γραμμών, 5x8 χαρακτήρων.
    - **0x06**: Ρύθμιση κατεύθυνσης cursor.

### **twi_init()**

- **Σκοπός**: Ρυθμίζει το TWI για επικοινωνία με τον PCA9555.
- **Παράμετροι**:
    - **Prescaler**: Ρυθμίζει τον prescaler σε 1 για απλή ρύθμιση.
    - **TWBR0**: Ρυθμίζει το ρολόι SCL στα 100kHz.

---

## **Συμπεράσματα**

Το πρόγραμμα αυτό είναι ένας ολοκληρωμένος κύκλος επικοινωνίας μεταξύ του ATmega328PB και του ESP8266 μέσω UART, με την έξοδο των αποτελεσμάτων να εμφανίζεται στην LCD. Η λογική του προγράμματος ακολουθεί τα εξής βήματα:

1. **Σύνδεση**: Στέλνει την εντολή `ESP:connect` και περιμένει την επιβεβαίωση.
2. **Ρύθμιση URL**: Στέλνει την εντολή `ESP:url:"..."` με την καθορισμένη διεύθυνση URL και περιμένει την επιβεβαίωση.
3. **Εμφάνιση Αποτελεσμάτων**: Εμφανίζει τα αποτελέσματα ("1.Success", "1.Fail", "2.Success", "2.Fail") στην LCD.
4. **Επανάληψη**: Επαναλαμβάνει τη διαδικασία με καθυστέρηση 5 δευτερολέπτων για ορατότητα των μηνυμάτων.