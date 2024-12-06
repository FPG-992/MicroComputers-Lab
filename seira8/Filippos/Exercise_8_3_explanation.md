## **Σκοπός της Άσκησης 8.3**

Η άσκηση 8.3 ζητάει να επεκτείνουμε το πρόγραμμα της άσκησης 8.2 ώστε να:

1. **Αποστολή Payload στον Server**:
    - Διαμορφώνει και στέλνει ένα JSON payload που περιλαμβάνει τις μετρήσεις θερμοκρασίας και πίεσης, τον αριθμό της ομάδας και το status.
    - Χρησιμοποιεί τις εντολές `ESP:payload:` και `ESP:transmit` για την αποστολή των δεδομένων στον server μέσω του ESP8266.

2. **Λήψη και Επεξεργασία Απαντήσεων**:
    - Λαμβάνει την απάντηση του server ("200 OK" ή κάποιο άλλο μήνυμα) και την εμφανίζει στην LCD.

3. **Επανάληψη Διεργασίας**:
    - Το πρόγραμμα επαναλαμβάνει συνεχώς τη διαδικασία αποστολής εντολών, λήψης απαντήσεων, και εμφάνισης δεδομένων στην LCD.

## **Δομή του Προγράμματος**

Το πρόγραμμα αποτελείται από τις ακόλουθες βασικές ενότητες:

1. **Επικεφαλίδες και Ορισμοί (Preprocessor Directives and Definitions)**
2. **Διαχείριση Buffer για UART Επικοινωνία**
3. **Συναρτήσεις UART**
4. **Συναρτήσεις για TWI (I²C) και PCA9555**
5. **Συναρτήσεις Ελέγχου LCD**
6. **Συναρτήσεις για Αισθητήρες Θερμοκρασίας (1-Wire)**
7. **Συναρτήσεις Διαχείρισης Πληκτρολογίου (Keypad)**
8. **Συναρτήσεις Ανάγνωσης Πίεσης (ADC)**
9. **Συναρτήσεις Εμφάνισης Δεδομένων στην LCD**
10. **Συναρτήσεις Διαμόρφωσης και Αποστολής Payload**
11. **Κύρια Συνάρτηση (main)**

Ας εξετάσουμε κάθε ενότητα αναλυτικά.

---

## **1. Επικεφαλίδες και Ορισμοί (Preprocessor Directives and Definitions)**

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

#define TEMP_OFFSET 9.0
```

### **Επεξήγηση:**

- **F_CPU**: Καθορίζει τη συχνότητα λειτουργίας του μικροελεγκτή σε Hertz. Εδώ είναι 16 MHz, που είναι η συχνότητα του ATmega328PB.
  
- **Συμπερίληψη Βιβλιοθηκών**:
  - **avr/io.h**: Παρέχει ορισμούς για είσοδοι/έξοδοι του AVR.
  - **util/delay.h**: Παρέχει συναρτήσεις καθυστέρησης όπως `_delay_ms()`.
  - **avr/interrupt.h**: Διαχείριση των διακοπών (interrupts).
  
- **UBRR_VALUE**: Ορίζει την τιμή του καταχωρητή baud rate για UART. Η τιμή 103 αντιστοιχεί σε BAUD=9600 με F_CPU=16MHz.
  
- **URL**: Η διεύθυνση URL που θα χρησιμοποιηθεί στην εντολή `ESP:url`.
  
- **PCA9555_0_ADDRESS**: Η διεύθυνση του TWI (I²C) εξαρτημένου PCA9555. Το PCA9555 είναι ένας εξωτερικός εκτατικός οδηγός (I/O expander) που χρησιμοποιείται για τον έλεγχο της LCD.
  
- **TWI_READ και TWI_WRITE**: Καθορίζουν την κατεύθυνση της επικοινωνίας (ανάγνωση ή εγγραφή).
  
- **SCL_CLOCK**: Η συχνότητα του ρολογιού για το TWI (100kHz).
  
- **TWBR0_VALUE**: Υπολογισμός του καταχωρητή baud rate για TWI. Χρησιμοποιείται ο τύπος για τον υπολογισμό του TWBR0.
  
- **TEMP_OFFSET**: Το offset που προστίθεται στην θερμοκρασία για να προσομοιώσουμε την πραγματική θερμοκρασία ασθενούς.

---

## **2. Διαχείριση Buffer για UART Επικοινωνία**

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

### **Επεξήγηση:**

- **buffer**: Ένας πίνακας χαρακτήρων που χρησιμοποιείται για την αποθήκευση της λήψης από την UART.
  
- **buffer_pointer**: Δείκτης που κρατάει την τρέχουσα θέση στο buffer για την αποθήκευση χαρακτήρων.
  
- **success**: Μια σταθερά που περιέχει το αναμενόμενο μήνυμα από το ESP8266. Είναι σημαντικό να περιλαμβάνει τα εισαγωγικά όπως αναφέρεται στις απαιτήσεις.
  
- **init_buffer()**: Επαναφέρει τον δείκτη του buffer στην αρχή, καθιστώντας τον έτοιμο για νέα δεδομένα.
  
- **write_buffer(char c)**: Προσθέτει έναν χαρακτήρα στο buffer και αυξάνει τον δείκτη. Αν ο δείκτης φτάσει στο μέγιστο (50), επαναφέρεται στην αρχή για αποφυγή υπερχείλισης.
  
- **display_buffer()**: Εμφανίζει τα περιεχόμενα του buffer στην LCD, χαρακτήρας-κατά-χαρακτήρα.
  
- **success_fail_buffer()**: Ελέγχει αν τα πρώτα δύο στοιχεία του buffer αντιστοιχούν στην σταθερά `success`. Επιστρέφει `1` αν ταιριάζουν, αλλιώς `0`. Αυτό βοηθά στον έλεγχο αν η απάντηση είναι "Success" ή "Fail".

---

## **3. Συναρτήσεις UART**

### **1. Αρχικοποίηση UART**

```c
void usart_init(uint16_t ubrr) {
    UCSR0A = 0;
    UCSR0B = (1<<RXEN0) | (1<<TXEN0);
    UBRR0H = (unsigned char) (ubrr>>8);
    UBRR0L = (unsigned char) ubrr;
    UCSR0C = (3 << UCSZ00);    
}
```

- **usart_init(uint16_t ubrr)**: Αρχικοποιεί την UART με τις καθορισμένες παραμέτρους.
    - **UCSR0A = 0**: Καθαρίζει τον καταχωρητή κατάστασης.
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

## **4. Συναρτήσεις για TWI (I²C) και PCA9555**

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
//---------------- Master Transmitter ---------------
#define TW_MT_SLA_ACK 0x18
#define TW_MT_SLA_NACK 0x20
#define TW_MT_DATA_ACK 0x28
//---------------- Master Receiver ------------------
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

- **twi_init()**: Αρχικοποιεί το TWI (I²C) με prescaler=1 και καθορίζει το ρολόι SCL στα 100kHz χρησιμοποιώντας τον υπολογισμένο `TWBR0_VALUE`.

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

### **4. Συνάρτηση Σταθερής Αναμονής (Wait)**

Δεν υπάρχει πρόσθετη συνάρτηση στα 8.3. Προσθέτουμε τις συναρτήσεις ανάγνωσης και εγγραφής όπως στις προηγούμενες ασκήσεις.

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

---

## **5. Συνάρτήσεις Ελέγχου LCD**

### **1. lcd_data**

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

### **2. lcd_command**

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

### **3. lcd_nextline, lcd_clear, lcd_init**

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

### **4. Πρόσθετες Συναρτήσεις Εμφάνισης**

```c
void display_number(uint8_t input) {
    lcd_data(0b00110000 | (input & 0x0F));
}

// Displays character array up until it finds a \0
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

## **6. Συνάρτηση Διαχείρισης Αισθητήρων Θερμοκρασίας (1-Wire)**

### **1. Λειτουργίες 1-Wire για Αισθητήρα Θερμοκρασίας**

```c
// Returns 1 if device is detected, 0 if no.
uint8_t one_wire_reset() {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(480);

    DDRD = 0;
    PORTD = 0;
    
    _delay_us(100);
    
    uint8_t temp = PIND;
    
    _delay_us(380);
    
    return (temp & (1<<4)) ? 0 : 1;
}

uint8_t one_wire_receive_bit() {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(2);
    
    DDRD = 0;
    PORTD = 0;
    
    _delay_us(10);
    
    uint8_t temp = (PIND & (1<<4)) ? 1 : 0;
    
    _delay_us(49);
    
    return temp;
}

void one_wire_transmit_bit(uint8_t bit) {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(2);
    
    PORTD = bit<<4;
    
    _delay_us(58);
    
    DDRD = 0;
    PORTD = 0;
    
    _delay_us(1);
}

uint8_t one_wire_receive_byte() {
    uint8_t output = 0x00;
    
    for (uint8_t i = 0; i < 8; i++) {
        output = output>>1;
        if (one_wire_receive_bit()) {
            output |= 1<<7;
        }
    }
    
    return output;
}

void one_wire_transmit_byte(uint8_t byte) {
    uint8_t temp = 1;
    for (uint8_t i = 0; i < 8; i++) {
        if (byte & temp) {
            one_wire_transmit_bit(1);
        } else {
            one_wire_transmit_bit(0);
        }
        temp = temp << 1;
    }
}

uint16_t temp() {
    if (!one_wire_reset()) {
        return 0x8000;
    }
    
    one_wire_transmit_byte(0xCC);
    
    one_wire_transmit_byte(0x44);
    
    while (!one_wire_receive_bit());
    
    if (!one_wire_reset()) {
        return 0x8000;
    }
    
    one_wire_transmit_byte(0xCC);
    
    one_wire_transmit_byte(0xBE);
    
    uint16_t output = one_wire_receive_byte();
    output |= one_wire_receive_byte()<<8;
    
    return output;
}

double get_temp() {   
    uint16_t reading = temp();
    if (reading == 0x8000) return 0;

    int16_t val = reading;
    double temperature_val = val / 16.0;
    
    return temperature_val + TEMP_OFFSET;
}
```

### **Επεξήγηση:**

- **one_wire_reset()**:
    - Εκτελεί τη διαδικασία reset για τον αισθητήρα 1-Wire.
    - Ορίζεται το pin PD4 ως έξοδο και στέλνει μια χαμηλή τάση για 480 μs.
    - Επαναφέρει το pin PD4 ως είσοδο και περιμένει για 480 μs.
    - Ελέγχει αν ο αισθητήρας ανταποκρίνεται. Επιστρέφει `1` αν ο αισθητήρας είναι παρόν (το pin PD4 είναι χαμηλό), αλλιώς `0`.

- **one_wire_receive_bit()**:
    - Λαμβάνει ένα bit από τον αισθητήρα 1-Wire.
    - Στέλνει μια μικρή παλμική τάση και διαβάζει το bit που επιστρέφει ο αισθητήρας.
    - Επιστρέφει `1` αν το bit είναι υψηλό, αλλιώς `0`.

- **one_wire_transmit_bit(uint8_t bit)**:
    - Στέλνει ένα bit στον αισθητήρα 1-Wire.
    - Ορίζει το pin PD4 ως έξοδο, στέλνει το bit, και επιστρέφει το pin ως είσοδο.

- **one_wire_receive_byte()**:
    - Λαμβάνει έναν byte από τον αισθητήρα 1-Wire, bit-κατά-bit.

- **one_wire_transmit_byte(uint8_t byte)**:
    - Στέλνει έναν byte στον αισθητήρα 1-Wire, bit-κατά-bit.

- **temp()**:
    - Εκτελεί τη διαδικασία ανάγνωσης θερμοκρασίας από τον αισθητήρα.
    - Στέλνει τις εντολές reset, skip ROM (`0xCC`), και convert T (`0x44`).
    - Περιμένει την ολοκλήρωση της μέτρησης.
    - Στέλνει τις εντολές reset, skip ROM (`0xCC`), και read scratchpad (`0xBE`).
    - Διαβάζει τα δύο πρώτα bytes που περιέχουν την θερμοκρασία.
    - Επιστρέφει την ανάγνωση ως 16-bit τιμή.

- **get_temp()**:
    - Μετατρέπει την 16-bit ανάγνωση σε πραγματική θερμοκρασία σε βαθμούς Κελσίου.
    - Προσθέτει το `TEMP_OFFSET` για να προσομοιώσει την πραγματική θερμοκρασία ασθενούς.

---

## **7. Συνάρτηση Διαχείρισης Πληκτρολογίου (Keypad)**

```c
const uint8_t rows[] = {0b11111110, 0b11111101, 0b11111011, 0b11110111};
const char characters[] = {'1','2','3','A','4','5','6','B','7','8','9','C','*','0','#','D'};
uint16_t pressed_keys = 0x0000;

uint8_t scan_row(uint8_t row) {
    PCA9555_0_write(REG_OUTPUT_1, rows[row]);
    uint8_t input = PCA9555_0_read(REG_INPUT_1);
    input = ~input;
    return input>>4;
}

uint16_t scan_keypad() {
    uint16_t output = 0x0000;
    uint8_t temp;
    for (uint8_t i = 0; i < 4; i++) {
        output = output<<4;
        temp = scan_row(i) & 0x0F;
        output |= temp;
    }
    
    return output;
}

void scan_keypad_rising_edge() {
    uint16_t pressed_keys_tempo = scan_keypad();
    _delay_ms(10);
    pressed_keys_tempo &= scan_keypad();
    
    pressed_keys = pressed_keys_tempo & (~pressed_keys);
}

char keypad_to_ascii(uint16_t keys) {
    uint16_t test = 1;
    for (uint8_t i = 0; i < 16; i++) {
        if (keys & test) {
            return characters[i];
        }
        test = test<<1;
    }
    return '\0';
}
```

### **Επεξήγηση:**

- **rows**: Ένας πίνακας που καθορίζει τις σειρές του πληκτρολογίου, ενεργοποιώντας μία σειρά τη φορά.
  
- **characters**: Ένας πίνακας που αντιστοιχίζει κάθε bit στο αντίστοιχο χαρακτήρα του πληκτρολογίου.
  
- **pressed_keys**: Ένας μεταβλητός που κρατάει τα τρέχοντα πατημένα πλήκτρα.

- **scan_row(uint8_t row)**:
    - Στέλνει την ενεργοποίηση μιας συγκεκριμένης σειράς μέσω του PCA9555.
    - Διαβάζει τα εισερχόμενα bits από την αντίστοιχη στήλη.
    - Επιστρέφει τα πρώτα 4 bits ως κατάσταση της σειράς.

- **scan_keypad()**:
    - Διατρέχει όλες τις σειρές του πληκτρολογίου.
    - Λαμβάνει τα πατημένα πλήκτρα και επιστρέφει ένα 16-bit τιμή όπου κάθε bit αντιστοιχεί σε ένα πλήκτρο.

- **scan_keypad_rising_edge()**:
    - Αναγνωρίζει τα πλήκτρα που πατήθηκαν στη στιγμή της ανανέωσης.
    - Προσθέτει debounce με καθυστέρηση 10 ms.
    - Ενημερώνει τα `pressed_keys` μόνο για τα νέα πατημένα πλήκτρα.

- **keypad_to_ascii(uint16_t keys)**:
    - Μετατρέπει τα bits των πατημένων πλήκτρων σε αντίστοιχα ASCII χαρακτήρες.
    - Επιστρέφει τον χαρακτήρα που αντιστοιχεί στο πρώτο πατημένο πλήκτρο.

---

## **8. Συνάρτηση Ανάγνωσης Πίεσης (ADC)**

```c
double get_pressure() {
    ADCSRA |= (1<<ADSC);
    while ((ADCSRA & (1<<ADSC)) != 0);

    // Processing
    double pressure = ADC * 20;
    pressure = pressure / 1024;
    
    return pressure;
}
```

### **Επεξήγηση:**

- **get_pressure()**:
    - Εκκινεί μια μετατροπή ADC για το POT0.
    - Περιμένει μέχρι να ολοκληρωθεί η μετατροπή.
    - Μετατρέπει την ADC ανάγνωση σε κλίμακα 0-20 cm H₂O:
        - Πολλαπλασιάζει την ανάγνωση ADC με 20.
        - Διαιρεί το αποτέλεσμα με 1024 (για 10-bit ADC).

---

## **9. Συνάρτηση Εμφάνισης Δεδομένων στην LCD**

### **1. Συνάρτηση Μετατροπής Binary σε BCD**

```c
unsigned char thousands, hundreds, tens, units;

void binary_to_bcd(uint16_t input) {
    thousands = input / 1000;
    input = input % 1000;
    
    hundreds = input / 100;
    input = input % 100;
    
    tens = input / 10;
    units = input % 10;
}
```

- **binary_to_bcd(uint16_t input)**:
    - Μετατρέπει μια δυαδική τιμή σε BCD (Binary-Coded Decimal).
    - Διαχωρίζει το input σε χιλιάδες, εκατοντάδες, δεκάδες και μονάδες.

### **2. Συνάρτηση Εμφάνισης Θερμοκρασίας στην LCD**

```c
void display_temp(double input) {
    uint8_t negative_sign = (input < 0) ? 1 : 0;
        
    if (negative_sign) input = -input;

    uint16_t integer = input;
    uint16_t decimal = (input - integer) * 10000;

    binary_to_bcd(integer);

    if (negative_sign) {
        lcd_data('-');
    } else {
        lcd_data('+');
    }

    if (hundreds != 0) display_number(hundreds);
    if (tens != 0 || hundreds != 0) display_number(tens);
    display_number(units);
    lcd_data('.');

    binary_to_bcd(decimal);
    display_number(thousands);
    // display_number(hundreds);
    // display_number(tens);
    // display_number(units);
    lcd_data(0b11011111); // Degree symbol
    lcd_data('C');
}
```

- **display_temp(double input)**:
    - Ελέγχει αν η θερμοκρασία είναι αρνητική και προσθέτει το κατάλληλο σύμβολο ('-' ή '+').
    - Μετατρέπει την θερμοκρασία σε ακέραιο και δεκαδικό μέρος.
    - Χρησιμοποιεί τη `binary_to_bcd` για τη μετατροπή σε BCD.
    - Εμφανίζει τα μέρη της θερμοκρασίας στην LCD, προσθέτοντας το σύμβολο βαθμού Κελσίου.

### **3. Συνάρτηση Εμφάνισης Πίεσης στην LCD**

```c
void display_pressure(double input) {
    uint16_t integer = input;
    uint16_t decimal = (input - integer) * 10000;
    
    binary_to_bcd(integer);

    if (tens != 0) display_number(tens);
    display_number(units);
    lcd_data('.');

    binary_to_bcd(decimal);
    display_number(thousands);
    // display_number(hundreds);
    // display_number(tens);
    // display_number(units);
}
```

- **display_pressure(double input)**:
    - Μετατρέπει την πίεση σε ακέραιο και δεκαδικό μέρος.
    - Χρησιμοποιεί τη `binary_to_bcd` για τη μετατροπή σε BCD.
    - Εμφανίζει τα μέρη της πίεσης στην LCD.

---

## **10. Συνάρτηση Διαμόρφωσης και Αποστολής Payload**

### **1. Συνάρτηση Μετατροπής Αριθμών σε ASCII**

```c
void transmit_temp(double input) {
    uint8_t negative_sign = (input < 0) ? 1 : 0;
        
    if (negative_sign) input = -input;

    uint16_t integer = input;
    uint16_t decimal = (input - integer) * 10000;

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
    uint16_t integer = input;
    uint16_t decimal = (input - integer) * 10000;
    
    binary_to_bcd(integer);

    if (tens != 0) usart_transmit(tens + '0');
    usart_transmit(units + '0');
    usart_transmit('.');

    binary_to_bcd(decimal);
    usart_transmit(thousands + '0');
}
```

- **transmit_temp(double input)**:
    - Ελέγχει αν η θερμοκρασία είναι αρνητική και στέλνει το κατάλληλο σύμβολο.
    - Μετατρέπει την θερμοκρασία σε ακέραιο και δεκαδικό μέρος.
    - Μετατρέπει σε BCD και στέλνει τους χαρακτήρες μέσω UART.

- **transmit_pressure(double input)**:
    - Μετατρέπει την πίεση σε ακέραιο και δεκαδικό μέρος.
    - Μετατρέπει σε BCD και στέλνει τους χαρακτήρες μέσω UART.

### **2. Συναρτήσεις Διαμόρφωσης JSON Payload**

Η διαδικασία διαμόρφωσης του JSON payload γίνεται μέσα στο κύριο βρόχο του προγράμματος, όπως θα δούμε αργότερα.

---

## **11. Κύρια Συνάρτηση (main)**

```c
int main(void) {
    // Enable TWI Communication for LCD
    twi_init();
        
    // Configure EXT_PORT1 as output
    PCA9555_0_write(REG_CONFIGURATION_0, 0x00);
    PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000);
    
    // Enable LCD
    lcd_init();
    
    init_buffer();
    
    // POT0 ADC Setup
    ADMUX = (1<<REFS0);
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);
    
    usart_init(UBRR_VALUE);
    
    uint8_t nurseStatus = 0;
    
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
        lcd_clear();
        transmit_string("ESP:connect\n");

        if (!receive_success_fail()) {
            display_string("1.Fail");
            lcd_nextline();
            display_string("Rec:");
            display_buffer();
            _delay_ms(1000);
            transmit_string("ESP:connect\n");
            if (receive_success_fail()) {
                lcd_clear();
            } else {
                continue;
            }
        }
        display_string("1.Success");
        lcd_nextline();
        display_string("Rec:");
        display_buffer();
        
        _delay_ms(1000);
        
        transmit_string("ESP:url:\"");
        
        transmit_string(URL);
        
        transmit_string("\"\n");
        
        lcd_clear();
        
        if (receive_success_fail()) {
            display_string("2.Success");
        } else {
            display_string("2.Fail");
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
        
        double temp = get_temp();
        double pressure = get_pressure();
        
        char pressed_char = keypad_to_ascii(scan_keypad());
        if (pressed_char == '7') {
            nurseStatus = 1;
        } else if (pressed_char == '#') {
            nurseStatus = 0;
        }
        
        transmit_string("ESP:payload:[{\"name\": \"temperature\", \"value\": \"");
        
        transmit_temp(temp);
        
        transmit_string("\"},{\"name\": \"pressure\", \"value\": \"");
        
        transmit_pressure(pressure);
                
        transmit_string("\"},{\"name\": \"team\", \"value\": \"17\"},{\"name\": \"status\", \"value\": \"");
        
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
            display_string("3.Success");
        } else {
            display_string("3.Fail");
            _delay_ms(1000);
            continue;
        }
        
        lcd_nextline();
        
        display_string("Rec:");
        display_buffer();
        
        _delay_ms(1000);
        
        transmit_string("ESP:transmit\n");
        
        lcd_clear();
        
        display_string("4.Success");
        lcd_nextline();
        init_buffer();

        char readChar = usart_receive();
        while (readChar != '\n') {
            write_buffer(readChar);
            readChar = usart_receive();
        }

        display_buffer();
        
        _delay_ms(5000);
    }
}
```

### **Επεξήγηση:**

#### **1. Αρχικοποίηση TWI και PCA9555**

```c
twi_init();

// Configure EXT_PORT1 as output
PCA9555_0_write(REG_CONFIGURATION_0, 0x00);
PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000);
```

- **twi_init()**: Αρχικοποιεί το TWI για επικοινωνία με τον PCA9555.
  
- **PCA9555_0_write(REG_CONFIGURATION_0, 0x00)**: Ρυθμίζει το EXT_PORT0 ως έξοδο.
  
- **PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000)**: Ρυθμίζει το EXT_PORT1 με τα πρώτα 4 pins ως έξοδο και τα υπόλοιπα ως είσοδο.

#### **2. Αρχικοποίηση LCD και UART**

```c
lcd_init();
init_buffer();

// POT0 ADC Setup
ADMUX = (1<<REFS0);
ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);

usart_init(UBRR_VALUE);
```

- **lcd_init()**: Εκτελεί την αρχικοποίηση της LCD.
  
- **init_buffer()**: Επαναφέρει τον δείκτη του buffer για νέες λήψεις δεδομένων.
  
- **ADMUX και ADCSRA**: Ρυθμίζει το ADC για τη μέτρηση της πίεσης μέσω POT0.
    - **ADMUX = (1<<REFS0)**: Επιλέγει την εσωτερική αναφορά τάσης (AVcc) για το ADC.
    - **ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)**: Ενεργοποιεί το ADC και ρυθμίζει το prescaler στα 128 για μέγιστη ακρίβεια.

- **usart_init(UBRR_VALUE)**: Αρχικοποιεί την UART με το baud rate 9600.

#### **3. Εκκίνηση ESP8266**

```c
transmit_string("ESP:restart\n");
char letter = usart_receive();
while (letter != '\n') {
    letter = usart_receive();
}
letter = usart_receive();
while (letter != '\n') {
    letter = usart_receive();
}
```

- **transmit_string("ESP:restart\n")**: Στέλνει την εντολή `ESP:restart` στο ESP8266 για επανεκκίνηση.
  
- **Λήψη Απαντήσεων**: Περιμένει να λάβει δύο απαντήσεις, καθένα τελειώνει με `\n`, πριν προχωρήσει στον κύριο βρόχο.

#### **4. Κύριος Βρόχος (Loop)**

```c
while (1) {
    // Βήμα 1: Σύνδεση με ESP
    lcd_clear();
    transmit_string("ESP:connect\n");

    if (!receive_success_fail()) {
        display_string("1.Fail");
        lcd_nextline();
        display_string("Rec:");
        display_buffer();
        _delay_ms(1000);
        transmit_string("ESP:connect\n");
        if (receive_success_fail()) {
            lcd_clear();
        } else {
            continue;
        }
    }
    display_string("1.Success");
    lcd_nextline();
    display_string("Rec:");
    display_buffer();
    
    _delay_ms(1000);
    
    // Βήμα 2: Ρύθμιση URL
    transmit_string("ESP:url:\"");
    transmit_string(URL);
    transmit_string("\"\n");
    
    lcd_clear();
    
    if (receive_success_fail()) {
        display_string("2.Success");
    } else {
        display_string("2.Fail");
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
    
    // Βήμα 3: Ανάγνωση Αισθητήρων και Πληκτρολογίου
    double temp = get_temp();
    double pressure = get_pressure();
    
    char pressed_char = keypad_to_ascii(scan_keypad());
    if (pressed_char == '7') {
        nurseStatus = 1;
    } else if (pressed_char == '#') {
        nurseStatus = 0;
    }
    
    // Βήμα 4: Διαμόρφωση και Αποστολή JSON Payload
    transmit_string("ESP:payload:[{\"name\": \"temperature\", \"value\": \"");
    
    transmit_temp(temp);
    
    transmit_string("\"},{\"name\": \"pressure\", \"value\": \"");
    
    transmit_pressure(pressure);
            
    transmit_string("\"},{\"name\": \"team\", \"value\": \"17\"},{\"name\": \"status\", \"value\": \"");
    
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
    
    // Βήμα 5: Λήψη Απάντησης για Payload
    if (receive_success_fail()) {
        display_string("3.Success");
    } else {
        display_string("3.Fail");
        _delay_ms(1000);
        continue;
    }
    
    lcd_nextline();
    
    display_string("Rec:");
    display_buffer();
    
    _delay_ms(1000);
    
    // Βήμα 6: Αποστολή Εντολής Transmit
    transmit_string("ESP:transmit\n");
    
    lcd_clear();
    
    display_string("4.Success");
    lcd_nextline();
    init_buffer();

    char readChar = usart_receive();
    while (readChar != '\n') {
        write_buffer(readChar);
        readChar = usart_receive();
    }

    display_buffer();
    
    _delay_ms(5000);
}
```

### **Λεπτομερής Επεξήγηση:**

#### **Βήμα 1: Σύνδεση με ESP**

```c
lcd_clear();
transmit_string("ESP:connect\n");

if (!receive_success_fail()) {
    display_string("1.Fail");
    lcd_nextline();
    display_string("Rec:");
    display_buffer();
    _delay_ms(1000);
    transmit_string("ESP:connect\n");
    if (receive_success_fail()) {
        lcd_clear();
    } else {
        continue;
    }
}
display_string("1.Success");
lcd_nextline();
display_string("Rec:");
display_buffer();

_delay_ms(1000);
```

- **lcd_clear()**: Καθαρίζει την οθόνη της LCD.
  
- **transmit_string("ESP:connect\n")**: Στέλνει την εντολή `ESP:connect` στο ESP8266 μέσω UART για σύνδεση.
  
- **receive_success_fail()**: Λαμβάνει την απάντηση του ESP8266. Αν η απάντηση δεν είναι "Success":
    - **display_string("1.Fail")**: Εμφανίζει "1.Fail" στην LCD.
    - **display_string("Rec:")** και **display_buffer()**: Εμφανίζει τα λάθος δεδομένα που έλαβε από το ESP8266.
    - **transmit_string("ESP:connect\n")**: Προσπαθεί ξανά να στείλει την εντολή `ESP:connect`.
    - **receive_success_fail()**: Αν η δεύτερη προσπάθεια είναι επιτυχής, καθαρίζει την LCD. Διαφορετικά, προσθέτει καθυστέρηση 1 δευτερολέπτου και συνεχίζει τον βρόχο.

- **display_string("1.Success")**: Αν η απάντηση είναι "Success", εμφανίζει "1.Success" στην LCD.
  
- **display_string("Rec:")** και **display_buffer()**: Εμφανίζει την απάντηση που έλαβε από το ESP8266.
  
- **_delay_ms(1000)**: Προσθέτει καθυστέρηση 1 δευτερολέπτου πριν προχωρήσει στο επόμενο βήμα.

#### **Βήμα 2: Ρύθμιση URL**

```c
transmit_string("ESP:url:\"");
transmit_string(URL);
transmit_string("\"\n");

lcd_clear();

if (receive_success_fail()) {
    display_string("2.Success");
} else {
    display_string("2.Fail");
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
```

- **transmit_string("ESP:url:\"")**, **transmit_string(URL)**, **transmit_string("\"\n")**:
    - Στέλνει την εντολή `ESP:url:"http://192.168.1.250:5000/data"\n` στο ESP8266 για ρύθμιση του URL του server.

- **lcd_clear()**: Καθαρίζει την οθόνη της LCD.

- **receive_success_fail()**: Λαμβάνει την απάντηση του ESP8266 για την εντολή URL.
    - Αν η απάντηση είναι "Success", εμφανίζει "2.Success".
    - Αν όχι, εμφανίζει "2.Fail" και τα λάθος δεδομένα, προσθέτει καθυστέρηση 1 δευτερολέπτου και συνεχίζει τον βρόχο.

- **display_string("Rec:")** και **display_buffer()**: Εμφανίζει την απάντηση που έλαβε από το ESP8266.
  
- **_delay_ms(1000)**: Προσθέτει καθυστέρηση 1 δευτερολέπτου πριν προχωρήσει στο επόμενο βήμα.

#### **Βήμα 3: Ανάγνωση Αισθητήρων και Πληκτρολογίου**

```c
double temp = get_temp();
double pressure = get_pressure();

char pressed_char = keypad_to_ascii(scan_keypad());
if (pressed_char == '7') {
    nurseStatus = 1;
} else if (pressed_char == '#') {
    nurseStatus = 0;
}
```

- **double temp = get_temp()**: Διαβάζει την θερμοκρασία από τον αισθητήρα 1-Wire.
  
- **double pressure = get_pressure()**: Διαβάζει την πίεση από το POT0 μέσω ADC.

- **char pressed_char = keypad_to_ascii(scan_keypad())**: Ανιχνεύει το πατημένο πλήκτρο από το πληκτρολόγιο.

    - **if (pressed_char == '7')**: Αν πατηθεί το πλήκτρο '7' (υποθέτουμε ότι αντιστοιχεί στο τελευταίο ψηφίο της ομάδας), θέτει το `nurseStatus` σε `1` (NURSE CALL).
  
    - **else if (pressed_char == '#')**: Αν πατηθεί το πλήκτρο '#', θέτει το `nurseStatus` σε `0` (OK).

#### **Βήμα 4: Διαμόρφωση και Αποστολή JSON Payload**

```c
transmit_string("ESP:payload:[{\"name\": \"temperature\", \"value\": \"");

transmit_temp(temp);

transmit_string("\"},{\"name\": \"pressure\", \"value\": \"");

transmit_pressure(pressure);
        
transmit_string("\"},{\"name\": \"team\", \"value\": \"17\"},{\"name\": \"status\", \"value\": \"");

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
```

- **transmit_string("ESP:payload:[{\"name\": \"temperature\", \"value\": \"")**: Στέλνει την αρχή του JSON payload για την θερμοκρασία.

- **transmit_temp(temp)**: Μετατρέπει και στέλνει την θερμοκρασία ως string μέσω UART.

- **transmit_string("\"},{\"name\": \"pressure\", \"value\": \"")**: Στέλνει τη διαχωριστική εντολή για την πίεση στο JSON payload.

- **transmit_pressure(pressure)**: Μετατρέπει και στέλνει την πίεση ως string μέσω UART.

- **transmit_string("\"},{\"name\": \"team\", \"value\": \"17\"},{\"name\": \"status\", \"value\": \"")**:
    - Στέλνει τα υπόλοιπα πεδία του JSON payload: `team` με τιμή "17" και την αρχή του `status`.

- **if (nurseStatus)**:
    - Αν `nurseStatus` είναι `1`, στέλνει "NURSE CALL".
  
- **else if (pressure > 12 || pressure < 4)**:
    - Αν η πίεση είναι πάνω από 12 ή κάτω από 4 cm H₂O, στέλνει "CHECK PRESSURE".
  
- **else if (temp > 37 || temp < 34)**:
    - Αν η θερμοκρασία είναι πάνω από 37 ή κάτω από 34 βαθμούς Κελσίου, στέλνει "CHECK TEMP".
  
- **else**:
    - Αν δεν ισχύει κανένα από τα παραπάνω, στέλνει "OK".
  
- **transmit_string("\"}]\n")**: Κλείνει το JSON payload και προσθέτει τον χαρακτήρα αλλαγής γραμμής.

- **lcd_clear()**: Καθαρίζει την οθόνη της LCD για να προετοιμαστεί για την επόμενη εμφάνιση.

#### **Βήμα 5: Λήψη Απάντησης για Payload**

```c
if (receive_success_fail()) {
    display_string("3.Success");
} else {
    display_string("3.Fail");
    _delay_ms(1000);
    continue;
}

lcd_nextline();

display_string("Rec:");
display_buffer();

_delay_ms(1000);
```

- **receive_success_fail()**: Λαμβάνει την απάντηση του ESP8266 για την αποστολή του payload.
    - Αν η απάντηση είναι "Success", εμφανίζει "3.Success".
    - Αν όχι, εμφανίζει "3.Fail", προσθέτει καθυστέρηση 1 δευτερολέπτου και συνεχίζει τον βρόχο.

- **display_string("Rec:")** και **display_buffer()**: Εμφανίζει την απάντηση που έλαβε από το ESP8266.

- **_delay_ms(1000)**: Προσθέτει καθυστέρηση 1 δευτερολέπτου πριν προχωρήσει στο επόμενο βήμα.

#### **Βήμα 6: Αποστολή Εντολής Transmit**

```c
transmit_string("ESP:transmit\n");

lcd_clear();

display_string("4.Success");
lcd_nextline();
init_buffer();

char readChar = usart_receive();
while (readChar != '\n') {
    write_buffer(readChar);
    readChar = usart_receive();
}

display_buffer();

_delay_ms(5000);
```

- **transmit_string("ESP:transmit\n")**: Στέλνει την εντολή `ESP:transmit` στο ESP8266 για αποστολή του payload στον server.

- **lcd_clear()**: Καθαρίζει την οθόνη της LCD.

- **display_string("4.Success")**: Εμφανίζει "4.Success" στην LCD.

- **lcd_nextline()**: Μεταβαίνει στη δεύτερη γραμμή της LCD.

- **init_buffer()**: Επαναφέρει τον δείκτη του buffer για νέα λήψεις δεδομένων.

- **Λήψη Απαντήσεων**:
    - Λαμβάνει την απάντηση του server (π.χ., "200 OK") και την αποθηκεύει στο buffer.
    - **display_buffer()**: Εμφανίζει την απάντηση του server στην LCD.

- **_delay_ms(5000)**: Προσθέτει καθυστέρηση 5 δευτερολέπτων πριν επαναλάβει τον βρόχο.

---

## **Συνολική Λειτουργία του Προγράμματος**

1. **Αρχικοποίηση**:
    - Το TWI αρχικοποιείται για επικοινωνία με τον PCA9555 (I/O expander).
    - Η PCA9555 ρυθμίζεται για να ελέγχει την LCD.
    - Η LCD αρχικοποιείται για εμφάνιση μηνυμάτων.
    - Το ADC αρχικοποιείται για τη μέτρηση της πίεσης μέσω POT0.
    - Η UART αρχικοποιείται για επικοινωνία με το ESP8266.
    - Το buffer αρχικοποιείται για νέα λήψη δεδομένων.
  
2. **Επανεκκίνηση ESP8266**:
    - Στέλνει την εντολή `ESP:restart` για επανεκκίνηση του ESP8266.
    - Περιμένει δύο απαντήσεις (πιθανώς "Waiting for command" και "ESP8266: Waiting for command").

3. **Κύριος Βρόχος (Loop)**:
    - **Βήμα 1: Σύνδεση με ESP**:
        - Στέλνει `ESP:connect` και περιμένει την απάντηση.
        - Αν αποτύχει, προσπαθεί ξανά και εμφανίζει "1.Fail" ή "1.Success" στην LCD.
  
    - **Βήμα 2: Ρύθμιση URL**:
        - Στέλνει `ESP:url:"http://192.168.1.250:5000/data"\n` και περιμένει την απάντηση.
        - Αν αποτύχει, εμφανίζει "2.Fail" και προσπαθεί ξανά.
        - Αν είναι επιτυχής, εμφανίζει "2.Success" στην LCD.
  
    - **Βήμα 3: Ανάγνωση Αισθητήρων και Πληκτρολογίου**:
        - Διαβάζει τη θερμοκρασία και την πίεση.
        - Ανιχνεύει το πατημένο πλήκτρο για να καθορίσει το `nurseStatus`.
  
    - **Βήμα 4: Διαμόρφωση και Αποστολή JSON Payload**:
        - Διαμορφώνει το JSON payload με τις μετρήσεις θερμοκρασίας και πίεσης, τον αριθμό της ομάδας και το status.
        - Στέλνει το payload μέσω εντολής `ESP:payload:`.

    - **Βήμα 5: Λήψη Απάντησης για Payload**:
        - Λαμβάνει την απάντηση για την αποστολή του payload ("Success" ή "Fail").
        - Εμφανίζει "3.Success" ή "3.Fail" στην LCD.

    - **Βήμα 6: Αποστολή Εντολής Transmit**:
        - Στέλνει την εντολή `ESP:transmit` για να στείλει το payload στον server.
        - Λαμβάνει την απάντηση του server (π.χ., "200 OK") και την εμφανίζει στην LCD.

    - **Καθυστέρηση 5 Δευτερολέπτων**: Προσθέτει καθυστέρηση 5 δευτερολέπτων πριν επαναλάβει τον βρόχο.

---

## **Μεθοδολογία και Λογική του Προγράμματος**

1. **Αρχικοποίηση Επικοινωνίας**:
    - Η αρχικοποίηση του TWI και του UART είναι κρίσιμη για τη σωστή επικοινωνία με τον PCA9555 και το ESP8266.
    - Η ρύθμιση των καταχωρητών στο PCA9555 εξασφαλίζει ότι η LCD είναι σωστά ρυθμισμένη και έτοιμη για χρήση.
  
2. **Εκκίνηση και Σύνδεση με ESP8266**:
    - Στέλνει την εντολή `ESP:restart` για να βεβαιωθεί ότι το ESP8266 είναι στις προεπιλεγμένες ρυθμίσεις.
    - Στη συνέχεια, στέλνει την εντολή `ESP:connect` για σύνδεση με το WiFi δίκτυο.
    - Ελέγχει την απάντηση για να βεβαιωθεί ότι η σύνδεση ήταν επιτυχής.

3. **Ρύθμιση URL**:
    - Στέλνει την εντολή `ESP:url:"http://192.168.1.250:5000/data"` για να καθορίσει το URL του server όπου θα στείλει τα δεδομένα.
    - Ελέγχει την απάντηση για να βεβαιωθεί ότι το URL έχει ρυθμιστεί σωστά.

4. **Ανάγνωση Αισθητήρων και Πληκτρολογίου**:
    - Διαβάζει τις μετρήσεις θερμοκρασίας και πίεσης.
    - Ανιχνεύει το πατημένο πλήκτρο από το πληκτρολόγιο για να καθορίσει το `nurseStatus`.

5. **Διαμόρφωση και Αποστολή Payload**:
    - Διαμορφώνει ένα JSON payload που περιλαμβάνει τις μετρήσεις θερμοκρασίας και πίεσης, τον αριθμό της ομάδας και το status.
    - Στέλνει το payload μέσω της εντολής `ESP:payload:`.

6. **Αποστολή Payload στον Server**:
    - Στέλνει την εντολή `ESP:transmit` για να στείλει το payload στον server.
    - Λαμβάνει την απάντηση του server και την εμφανίζει στην LCD.

7. **Επανάληψη Διεργασίας**:
    - Ο κύριος βρόχος συνεχίζει να επαναλαμβάνει τη διαδικασία αποστολής εντολών, λήψης απαντήσεων, και εμφάνισης δεδομένων στην LCD, διασφαλίζοντας συνεχή επικοινωνία με το ESP8266 και τον server.

---

## **Κλειδιά Συναρτήσεων και Παραμέτρων**

### **1. usart_init()**

- **Σκοπός**: Ρυθμίζει την UART για επικοινωνία με το ESP8266.
- **Παράμετροι**:
    - **ubrr**: Καθορίζει το baud rate. Για BAUD=9600 και F_CPU=16MHz, η τιμή είναι 103.

### **2. transmit_string()**

- **Σκοπός**: Στέλνει μια αλφαριθμητική συμβολοσειρά μέσω UART μέχρι να συναντήσει `\n` ή `\0`.
- **Λόγος**: Διασφαλίζει ότι οι εντολές έχουν τον σωστό χαρακτήρα αλλαγής γραμμής.

### **3. receive_success_fail()**

- **Σκοπός**: Διαβάζει την απάντηση από το ESP8266 και ελέγχει αν είναι "Success" ή "Fail".
- **Επιστρέφει**:
    - `1` αν η απάντηση είναι "Success".
    - `0` αν η απάντηση είναι "Fail" ή κάτι άλλο.

### **4. twi_init() και Συναρτήσεις για TWI/I²C**

- **Σκοπός**: Διαχειρίζεται την επικοινωνία μέσω I²C με τον PCA9555 για τον έλεγχο της LCD.
- **Σημαντικές Εντολές**:
    - **twi_init()**: Αρχικοποιεί το TWI.
    - **PCA9555_0_write() και PCA9555_0_read()**: Γράφουν και διαβάζουν από τον PCA9555.
  
### **5. lcd_init() και Συναρτήσεις Εμφάνισης**

- **Σκοπός**: Ρυθμίζει και ελέγχει την LCD μέσω του PCA9555.
- **Σημαντικές Εντολές**:
    - **0x01**: Καθαρισμός της LCD.
    - **0x0c**: Ενεργοποίηση της οθόνης χωρίς cursor.
    - **0x28**: Ρύθμιση λειτουργίας 4-bit mode, 2 γραμμών, 5x8 χαρακτήρων.
    - **0x06**: Ρύθμιση κατεύθυνσης cursor.

### **6. get_temp() και 1-Wire Συναρτήσεις**

- **get_temp()**:
    - Διαβάζει την θερμοκρασία από τον αισθητήρα 1-Wire.
    - Μετατρέπει την ανάγνωση σε πραγματική θερμοκρασία και προσθέτει offset.

### **7. get_pressure()**

- **get_pressure()**:
    - Διαβάζει την πίεση από το POT0 μέσω ADC.
    - Μετατρέπει την ADC ανάγνωση σε κλίμακα 0-20 cm H₂O.

### **8. keypad_to_ascii() και Keypad Συναρτήσεις**

- **keypad_to_ascii(uint16_t keys)**:
    - Μετατρέπει τα bits των πατημένων πλήκτρων σε αντίστοιχα ASCII χαρακτήρες.

### **9. transmit_temp() και transmit_pressure()**

- **transmit_temp(double input)**:
    - Μετατρέπει την θερμοκρασία σε ASCII χαρακτήρες και στέλνει μέσω UART.

- **transmit_pressure(double input)**:
    - Μετατρέπει την πίεση σε ASCII χαρακτήρες και στέλνει μέσω UART.

---

## **Συμπεράσματα**

Το πρόγραμμα αυτό είναι ένας ολοκληρωμένος κύκλος επικοινωνίας μεταξύ του ATmega328PB και του ESP8266 μέσω UART, με την έξοδο των αποτελεσμάτων να εμφανίζεται στην LCD και την αποστολή δεδομένων σε server μέσω JSON payload. Η λογική του προγράμματος ακολουθεί τα εξής βήματα:

1. **Αρχικοποίηση**:
    - Το TWI αρχικοποιείται για επικοινωνία με τον PCA9555 (I/O expander).
    - Η PCA9555 ρυθμίζεται για να ελέγχει την LCD.
    - Η LCD αρχικοποιείται για εμφάνιση μηνυμάτων.
    - Το ADC αρχικοποιείται για τη μέτρηση της πίεσης μέσω POT0.
    - Η UART αρχικοποιείται για επικοινωνία με το ESP8266.
    - Το buffer αρχικοποιείται για νέα λήψη δεδομένων.

2. **Επανεκκίνηση ESP8266**:
    - Στέλνει την εντολή `ESP:restart` για να βεβαιωθεί ότι το ESP8266 είναι στις προεπιλεγμένες ρυθμίσεις.
    - Περιμένει δύο απαντήσεις (πιθανώς "Waiting for command" και "ESP8266: Waiting for command").

3. **Κύριος Βρόχος (Loop)**:
    - **Βήμα 1: Σύνδεση με ESP**:
        - Στέλνει `ESP:connect` και περιμένει την απάντηση.
        - Αν αποτύχει, προσπαθεί ξανά και εμφανίζει "1.Fail" ή "1.Success" στην LCD.
  
    - **Βήμα 2: Ρύθμιση URL**:
        - Στέλνει `ESP:url:"http://192.168.1.250:5000/data"\n` και περιμένει την απάντηση.
        - Αν αποτύχει, εμφανίζει "2.Fail" και προσπαθεί ξανά.
        - Αν είναι επιτυχής, εμφανίζει "2.Success" στην LCD.
  
    - **Βήμα 3: Ανάγνωση Αισθητήρων και Πληκτρολογίου**:
        - Διαβάζει τη θερμοκρασία και την πίεση.
        - Ανιχνεύει το πατημένο πλήκτρο από το πληκτρολόγιο για να καθορίσει το `nurseStatus`.
  
    - **Βήμα 4: Διαμόρφωση και Αποστολή JSON Payload**:
        - Διαμορφώνει ένα JSON payload που περιλαμβάνει τις μετρήσεις θερμοκρασίας και πίεσης, τον αριθμό της ομάδας και το status.
        - Στέλνει το payload μέσω της εντολής `ESP:payload:`.
  
    - **Βήμα 5: Λήψη Απάντησης για Payload**:
        - Λαμβάνει την απάντηση για την αποστολή του payload ("Success" ή "Fail").
        - Εμφανίζει "3.Success" ή "3.Fail" στην LCD.
  
    - **Βήμα 6: Αποστολή Εντολής Transmit**:
        - Στέλνει την εντολή `ESP:transmit` για να στείλει το payload στον server.
        - Λαμβάνει την απάντηση του server (π.χ., "200 OK") και την εμφανίζει στην LCD.
  
    - **Καθυστέρηση 5 Δευτερολέπτων**: Προσθέτει καθυστέρηση 5 δευτερολέπτων πριν επαναλάβει τον βρόχο.