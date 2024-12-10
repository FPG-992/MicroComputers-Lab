## **Σκοπός της Άσκησης 8.2**

Η άσκηση 8.2 ζητάει να επεκτείνουμε το πρόγραμμα της άσκησης 8.1 ώστε να:

1. **Ανάγνωση Αισθητήρων**:
    - **Θερμοκρασίας**: Διαβάζει μια μέτρηση από τον αισθητήρα θερμοκρασίας DS18B20 και προσθέτει ένα offset για να προσομοιώσει την πραγματική θερμοκρασία ασθενούς.
    - **Πίεσης**: Διαβάζει μια μέτρηση από το ποτενσιόμετρο (POT0) και την μετατρέπει σε κλίμακα 0-20 cm H₂O για να προσομοιώσει την κεντρική φλεβική πίεση.

2. **Διαχείριση Πληκτρολογίου**:
    - Ανίχνευση πλήκτρων για την αλλαγή της κατάστασης του συστήματος (π.χ., `NURSE CALL`).

3. **Υπολογισμός Κατάστασης (Status)**:
    - Ανάλογα με τις μετρήσεις πίεσης και θερμοκρασίας καθώς και τις ενέργειες μέσω του πληκτρολογίου, καθορίζει το κατάλληλο status (`NURSE CALL`, `CHECK PRESSURE`, `CHECK TEMP`, `OK`).

4. **Εμφάνιση Δεδομένων στην LCD**:
    - Εμφανίζει τις τιμές της θερμοκρασίας και της πίεσης στην πρώτη γραμμή της LCD και το status στη δεύτερη γραμμή.

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
10. **Κύρια Συνάρτηση (main)**

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

- **TEMP_OFFSET**: Το offset που προστίθεται στην θερμοκρασία για να προσομοιώσουμε την πραγματική θερμοκρασία ασθενούς (π.χ., θερμοκρασία δωματίου).

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

- **success[]**: Μια σταθερά που περιέχει το αναμενόμενο μήνυμα από το ESP8266. Είναι σημαντικό να περιλαμβάνει τα εισαγωγικά όπως αναφέρεται στις απαιτήσεις.

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
//----------- Master Transmitter/Receiver -----------
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

- **twi_start(unsigned char address)**: Στέλνει την σήμανση START, τη διεύθυνση της συσκευής (address) και ελέγχει την απόκριση (ACK/NACK). Επιστρέφει `0` για επιτυχία και `1` για αποτυχία.

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

#### **Συνάρτηση Σταθερής Αναμονής (Wait)**

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

### **4. Συναρτήσεις Εγγραφής και Ανάγνωσης PCA9555**

#### **Συνάρτηση Εγγραφής PCA9555**

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

#### **Συνάρτηση Ανάγνωσης PCA9555**

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

### **5. Συνάρτηση Εγγραφής Δεδομένων (write2)**

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

## **6. Συναρτήσεις Ελέγχου LCD**

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
    - Προσθέτει μια μικρή καθυστέρηση για την εκτέλεση της εντολής από την LCD.

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
    - Προσθέτει μια μικρή καθυστέρηση για την εκτέλεση της εντολής από την LCD.

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

void display_string(char arr[]) {
    uint8_t i = 0;
    while (arr[i] != '\0') {
        lcd_data(arr[i]);
        i++;
    }
}
```

- **display_number(uint8_t input)**: Εμφανίζει έναν αριθμό στην LCD μετατρέποντας τον σε ASCII χαρακτήρα. Η συνάρτηση αυτή εμφανίζει τον αριθμό σε δεκαδική μορφή.

- **display_string(char arr[])**: Εμφανίζει μια αλφαριθμητική συμβολοσειρά στην LCD χαρακτήρας-κατά-χαρακτήρα.

---

## **7. Συναρτήσεις για Αισθητήρες Θερμοκρασίας (1-Wire)**

### **1. one_wire_reset**

```c
uint8_t one_wire_reset() {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(480);

    DDRD = 0;
    PORTD = 0;
    
    _delay_us(100);
    
    uint8_t temp = PIND;
    
    _delay_us(380);
    
    return (temp & 1<<4) ? 0 : 1;
}
```

- **one_wire_reset()**:
    - Ενεργοποιεί τον pin PD4 ως έξοδο και στέλνει μια ένταση LOW για 480 μs για την αρχικοποίηση της σύνδεσης 1-Wire.
    - Απενεργοποιεί τον pin ως είσοδο και παραμένει LOW για 100 μs.
    - Διαβάζει το pin PD4 για να ελέγξει αν ο αισθητήρας απάντησε με το σήμα Presence.
    - Επιστρέφει `1` αν ο αισθητήρας ανιχνεύεται (Presence detected), αλλιώς `0`.

### **2. one_wire_receive_bit**

```c
uint8_t one_wire_receive_bit() {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(2);
    
    DDRD = 0;
    PORTD = 0;
    
    _delay_us(10);
    
    uint8_t temp = (PIND & 1<<4) ? 1 : 0;
    
    _delay_us(49);
    
    return temp;
}
```

- **one_wire_receive_bit()**:
    - Στέλνει ένα σήμα για να διαβάσει ένα bit από τον αισθητήρα.
    - Ενεργοποιεί τον pin PD4 ως έξοδο και στέλνει LOW για 2 μs.
    - Απενεργοποιεί τον pin ως είσοδο και παραμένει LOW για 10 μs.
    - Διαβάζει την κατάσταση του pin PD4 για να ανιχνεύσει το bit.
    - Περιμένει 49 μs πριν επιστρέψει το bit που έχει διαβαστεί.

### **3. one_wire_transmit_bit**

```c
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
```

- **one_wire_transmit_bit(uint8_t bit)**:
    - Ενεργοποιεί τον pin PD4 ως έξοδο και στέλνει LOW για 2 μs.
    - Αν το bit είναι `1`, στέλνει HIGH (SET PD4), αλλιώς παραμένει LOW.
    - Παραμένει σε αυτή την κατάσταση για 58 μs.
    - Απενεργοποιεί τον pin ως είσοδο και παραμένει LOW για 1 μs.

### **4. one_wire_receive_byte**

```c
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
```

- **one_wire_receive_byte()**:
    - Διαβάζει 8 bits από τον αισθητήρα, ένα bit κάθε φορά.
    - Μετακινεί τα bits στο `output` και προσθέτει τα νέα bits στο LSB.

### **5. one_wire_transmit_byte**

```c
void one_wire_transmit_byte(uint8_t byte) {
    uint8_t temp = 1;
    for (uint8_t i = 0; i < 8; i++) {
        if (byte & temp) {
            one_wire_transmit_bit(1);
        } else {
            one_wire_transmit_bit(0);
        }
        temp = temp<<1;
    }
}
```

- **one_wire_transmit_byte(uint8_t byte)**:
    - Διαβάζει κάθε bit από το `byte` και στέλνει το bit χρησιμοποιώντας τη συνάρτηση `one_wire_transmit_bit`.

### **6. temp**

```c
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
```

- **temp()**:
    - Εκτελεί μια ακολουθία εντολών για να διαβάσει την θερμοκρασία από τον αισθητήρα DS18B20.
    - **one_wire_reset()**: Ελέγχει αν ο αισθητήρας είναι παρών.
    - **one_wire_transmit_byte(0xCC)**: Στέλνει την εντολή "Skip ROM" για να στείλει εντολές στον απλό αισθητήρα.
    - **one_wire_transmit_byte(0x44)**: Στέλνει την εντολή "Convert T" για να ξεκινήσει η μέτρηση θερμοκρασίας.
    - Περιμένει μέχρι να ολοκληρωθεί η μέτρηση (μέσω του `one_wire_receive_bit`).
    - Επαναλαμβάνει το reset και στέλνει την εντολή "Read Scratchpad" (`0xBE`) για να διαβάσει τα δεδομένα θερμοκρασίας.
    - Διαβάζει τα δεδομένα θερμοκρασίας και τα συνδυάζει σε ένα 16-bit αποτέλεσμα.
    - **Επιστρέφει**: Την τιμή θερμοκρασίας ως 16-bit αριθμό.

### **7. get_temp**

```c
double get_temp() {   
    uint16_t reading = temp();
    if (reading == 0x8000) return 0;

    int16_t val = reading;
    double temperature_val = val / 16.0;
    
    return temperature_val + TEMP_OFFSET;
}
```

- **get_temp()**:
    - Καλεί τη συνάρτηση `temp()` για να λάβει την τιμή θερμοκρασίας.
    - Αν η τιμή είναι `0x8000`, επιστρέφει `0` (σημαίνει αποτυχία ανάγνωσης).
    - Διαχωρίζει την τιμή σε ακέραιο και δεκαδικό μέρος.
    - Προσθέτει το `TEMP_OFFSET` για να προσομοιώσει την πραγματική θερμοκρασία ασθενούς.

---

## **8. Συναρτήσεις Διαχείρισης Πληκτρολογίου (Keypad)**

### **1. Ορισμοί Πληκτρολογίου**

```c
const uint8_t rows[] = {0b11111110, 0b11111101, 0b11111011, 0b11110111};
const char characters[] = {'1','2','3','A','4','5','6','B','7','8','9','C','*','0','#','D'};
uint16_t pressed_keys = 0x0000;
```

- **rows[]**: Καθορίζει τις γραμμές του πληκτρολογίου που θα ενεργοποιηθούν για σάρωση.

- **characters[]**: Χαρτογραφεί τα πλήκτρα σε χαρακτήρες.

- **pressed_keys**: Καταγράφει τα πλήκτρα που έχουν πατηθεί.

### **2. Συνάρτηση Σάρωσης Γραμμών**

```c
uint8_t scan_row(uint8_t row) {
    PCA9555_0_write(REG_OUTPUT_1, rows[row]);
    uint8_t input = PCA9555_0_read(REG_INPUT_1);
    input = ~input;
    return input>>4;
}
```

- **scan_row(uint8_t row)**:
    - Ρυθμίζει μια γραμμή του πληκτρολογίου ως ενεργή (LOW).
    - Διαβάζει την κατάσταση των στηλών για να ανιχνεύσει αν κάποιο πλήκτρο έχει πατηθεί.
    - Επιστρέφει τα δεδομένα των στηλών.

### **3. Συνάρτηση Σάρωσης Πληκτρολογίου**

```c
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
```

- **scan_keypad()**:
    - Σκάναρει όλες τις γραμμές του πληκτρολογίου.
    - Συγκεντρώνει τα αποτελέσματα σε ένα 16-bit output.

### **4. Συνάρτηση Σάρωσης Πληκτρολογίου με Ανίχνευση Αλλαγής (Rising Edge)**

```c
void scan_keypad_rising_edge() {
    uint16_t pressed_keys_tempo = scan_keypad();
    _delay_ms(10);
    pressed_keys_tempo &= scan_keypad();
    
    pressed_keys = pressed_keys_tempo & (~pressed_keys);
}
```

- **scan_keypad_rising_edge()**:
    - Σκάναρει το πληκτρολόγιο και αποθηκεύει το αποτέλεσμα προσωρινά.
    - Περιμένει 10 ms για να αποφευχθεί η ταλαιπωρία (debouncing).
    - Σκάναρει ξανά και συγκεντρώνει μόνο τις αλλαγές από LOW σε HIGH.
    - Ενημερώνει το `pressed_keys` με τα νέα πατημένα πλήκτρα.

### **5. Συνάρτηση Μετατροπής Πλήκτρων σε ASCII Χαρακτήρες**

```c
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

- **keypad_to_ascii(uint16_t keys)**:
    - Μετατρέπει τα bits των πατημένων πλήκτρων σε χαρακτήρες ASCII χρησιμοποιώντας τον πίνακα `characters[]`.
    - Επιστρέφει τον αντίστοιχο χαρακτήρα αν εντοπιστεί πλήκτρο, αλλιώς επιστρέφει `'\0'`.

---

## **9. Συναρτήσεις Ανάγνωσης Πίεσης (ADC)**

### **1. get_pressure**

```c
double get_pressure() {
    ADCSRA |= (1<<ADSC);
    while ((ADCSRA & (1<<ADSC)) != 0);

    // Processing
    uint16_t input = ADC;
    double pressure = ADC * 20;
    pressure = pressure / 1024;
    
    return pressure;
}
```

- **get_pressure()**:
    - Ξεκινάει μια μέτρηση ADC (Analog-to-Digital Conversion) στον POT0.
    - Περιμένει μέχρι να ολοκληρωθεί η μέτρηση.
    - Διαβάζει την τιμή ADC (0-1023).
    - Μετατρέπει την τιμή ADC σε κλίμακα 0-20 cm H₂O.
    - **Επιστρέφει**: Την τιμή πίεσης ως `double`.

### **2. Συναρτήσεις Μετατροπής Binary σε BCD**

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
    - Μετατρέπει έναν αριθμό σε δεκαδική μορφή BCD (Binary-Coded Decimal).
    - Διαχωρίζει τον αριθμό σε χιλιάδες, εκατοντάδες, δεκάδες και μονάδες.

---

## **10. Συναρτήσεις Εμφάνισης Δεδομένων στην LCD**

### **1. display_temp**

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
    lcd_data(0b11011111); // Degree symbol
    lcd_data('C');
}
```

- **display_temp(double input)**:
    - Ελέγχει αν η θερμοκρασία είναι αρνητική και προσθέτει το κατάλληλο σύμβολο (`-` ή `+`).
    - Διαχωρίζει την θερμοκρασία σε ακέραιο και δεκαδικό μέρος.
    - Χρησιμοποιεί τη συνάρτηση `binary_to_bcd` για τη μετατροπή σε BCD.
    - Εμφανίζει τα χιλιάδες, εκατοντάδες, δεκάδες και μονάδες στην LCD.
    - Προσθέτει το σύμβολο βαθμών και το γράμμα 'C' για Celsius.

### **2. display_pressure**

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
}
```

- **display_pressure(double input)**:
    - Διαχωρίζει την πίεση σε ακέραιο και δεκαδικό μέρος.
    - Χρησιμοποιεί τη συνάρτηση `binary_to_bcd` για τη μετατροπή σε BCD.
    - Εμφανίζει τις δεκάδες και τις μονάδες στην LCD.
    - Προσθέτει το δεκαδικό σημείο και τα δεκαδικά ψηφία της πίεσης.

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
    
    // POT0 ADC Setup
    ADMUX = (1<<REFS0);
    ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);
    
    usart_init(UBRR_VALUE);
    
    init_buffer();
    
    uint8_t nurseStatus = 0;
    
    while (1) {
        lcd_clear();
        transmit_string("ESP:connect\n");

        if (!receive_success_fail()) {
            display_string("1.Fail");
            transmit_string("ESP:connect\n");
            if (receive_success_fail()) {
                lcd_clear();
            } else {
                _delay_ms(1000);
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
        
        double temp = get_temp();
        double pressure = get_pressure();
        
        char pressed_char = keypad_to_ascii(scan_keypad());
        if (pressed_char == '7') {
            nurseStatus = 1;
        } else if (pressed_char == '#') {
            nurseStatus = 0;
        }
        
        lcd_clear();
        
        display_temp(temp);
        display_string(" | ");
        display_pressure(pressure);
        
        lcd_nextline();
        
        if (nurseStatus) {
            display_string("NURSE CALL");
        } else if (pressure > 12 || pressure < 4) {
            display_string("CHECK PRESSURE");
        } else if (temp > 37 || temp < 34) {
            display_string("CHECK TEMP");
        } else {
            display_string("OK");
        }
        
        _delay_ms(10000);
    }
}
```

### **Επεξήγηση:**

#### **1. Αρχικοποίηση Συστήματος**

```c
// Enable TWI Communication for LCD
twi_init();
    
// Configure EXT_PORT1 as output
PCA9555_0_write(REG_CONFIGURATION_0, 0x00);
PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000);

// Enable LCD
lcd_init();

// POT0 ADC Setup
ADMUX = (1<<REFS0);
ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);

usart_init(UBRR_VALUE);

init_buffer();
```

- **twi_init()**: Αρχικοποιεί το TWI για επικοινωνία με τον PCA9555.

- **PCA9555_0_write(REG_CONFIGURATION_0, 0x00)**: Ρυθμίζει το EXT_PORT0 ως έξοδο (όλα τα pins ως έξοδο).

- **PCA9555_0_write(REG_CONFIGURATION_1, 0b11110000)**: Ρυθμίζει το EXT_PORT1 με τα πρώτα 4 pins ως έξοδο και τα υπόλοιπα ως είσοδο.

- **lcd_init()**: Εκτελεί την αρχικοποίηση της LCD.

- **ADMUX και ADCSRA**: Ρυθμίζει τον ADC για ανάγνωση από το POT0:
    - **ADMUX = (1<<REFS0)**: Χρησιμοποιεί την εσωτερική αναφορά τάσης (AVcc).
    - **ADCSRA = (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)**: Ενεργοποιεί τον ADC και θέτει τον διαχωριστή ρυθμού σε 128 (prescaler=128 για F_ADC=125kHz με F_CPU=16MHz).

- **usart_init(UBRR_VALUE)**: Αρχικοποιεί την UART με το baud rate 9600.

- **init_buffer()**: Επαναφέρει τον δείκτη του buffer για νέες λήψεις δεδομένων.

- **nurseStatus**: Μεταβλητή για την παρακολούθηση της κατάστασης `NURSE CALL`.

#### **2. Κύριος Βρόχος (Main Loop)**

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
            _delay_ms(1000);
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
    
    double temp = get_temp();
    double pressure = get_pressure();
    
    char pressed_char = keypad_to_ascii(scan_keypad());
    if (pressed_char == '7') {
        nurseStatus = 1;
    } else if (pressed_char == '#') {
        nurseStatus = 0;
    }
    
    lcd_clear();
    
    display_temp(temp);
    display_string(" | ");
    display_pressure(pressure);
    
    lcd_nextline();
    
    if (nurseStatus) {
        display_string("NURSE CALL");
    } else if (pressure > 12 || pressure < 4) {
        display_string("CHECK PRESSURE");
    } else if (temp > 37 || temp < 34) {
        display_string("CHECK TEMP");
    } else {
        display_string("OK");
    }
    
    _delay_ms(10000);
}
```

##### **Βήμα 1: Εκκαθάριση LCD και Αποστολή Εντολής "ESP:connect"**

```c
lcd_clear();
transmit_string("ESP:connect\n");
```

- **lcd_clear()**: Καθαρίζει την οθόνη της LCD.

- **transmit_string("ESP:connect\n")**: Στέλνει την εντολή `ESP:connect` στο ESP8266 μέσω UART, με το χαρακτήρα αλλαγής γραμμής `\n` στο τέλος όπως απαιτείται.

##### **Βήμα 2: Λήψη και Έλεγχος Απάντησης του ESP8266**

```c
if (!receive_success_fail()) {
    display_string("1.Fail");
    transmit_string("ESP:connect\n");
    if (receive_success_fail()) {
        lcd_clear();
    } else {
        _delay_ms(1000);
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
        - Αν αποτύχει ξανά, **_delay_ms(1000)** προσθέτει καθυστέρηση 1 δευτερολέπτου και συνεχίζει τον βρόχο (`continue`).
- **display_string("1.Success")**: Αν η απάντηση είναι "Success", εμφανίζει "1.Success" στην LCD.
- **lcd_nextline()**: Μεταβαίνει στη δεύτερη γραμμή της LCD για την επόμενη εντολή.

##### **Βήμα 3: Αποστολή Εντολής "ESP:url"**

```c
transmit_string("ESP:url:\"");
transmit_string(URL);
transmit_string("\"\n");
```

- **transmit_string("ESP:url:\"")**: Στέλνει την αρχή της εντολής `ESP:url:"`.

- **transmit_string(URL)**: Στέλνει την διεύθυνση URL `http://192.168.1.250:5000/data`.

- **transmit_string("\"\n")**: Στέλνει το κλείσιμο των εισαγωγικών και τον χαρακτήρα αλλαγής γραμμής `\n`. Συνολικά, η εντολή που στέλνεται είναι `ESP:url:"http://192.168.1.250:5000/data"\n`.

##### **Βήμα 4: Λήψη και Έλεγχος Απάντησης για "ESP:url"**

```c
if (receive_success_fail()) {
    display_string("2.Success");
} else {
    display_string("2.Fail");
}
```

- **if (receive_success_fail())**:
    - Αν η απάντηση είναι "Success", **display_string("2.Success")** εμφανίζει "2.Success" στην LCD.
    - Αλλιώς, **display_string("2.Fail")** εμφανίζει "2.Fail".

##### **Βήμα 5: Ανάγνωση Αισθητήρων Θερμοκρασίας και Πίεσης**

```c
double temp = get_temp();
double pressure = get_pressure();
```

- **get_temp()**: Διαβάζει την θερμοκρασία από τον αισθητήρα DS18B20, προσθέτει το `TEMP_OFFSET` και επιστρέφει την τιμή ως `double`.

- **get_pressure()**: Διαβάζει την πίεση από το POT0, μετατρέπει την τιμή σε κλίμακα 0-20 cm H₂O και επιστρέφει την τιμή ως `double`.

##### **Βήμα 6: Ανίχνευση Πλήκτρων και Καθορισμός Κατάστασης**

```c
char pressed_char = keypad_to_ascii(scan_keypad());
if (pressed_char == '7') {
    nurseStatus = 1;
} else if (pressed_char == '#') {
    nurseStatus = 0;
}
```

- **scan_keypad()**: Σκάναρει το πληκτρολόγιο και επιστρέφει τα πατημένα πλήκτρα.

- **keypad_to_ascii(uint16_t keys)**: Μετατρέπει τα πατημένα πλήκτρα σε χαρακτήρες ASCII.

- **if (pressed_char == '7')**: Αν πατηθεί το πλήκτρο '7', θέτει το `nurseStatus` σε `1` (`NURSE CALL`).

- **else if (pressed_char == '#')**: Αν πατηθεί το πλήκτρο '#', θέτει το `nurseStatus` σε `0` (επαναφορά στην κατάσταση `OK`).

##### **Βήμα 7: Εμφάνιση Θερμοκρασίας και Πίεσης στην LCD**

```c
lcd_clear();

display_temp(temp);
display_string(" | ");
display_pressure(pressure);
```

- **lcd_clear()**: Καθαρίζει την οθόνη της LCD.

- **display_temp(temp)**: Εμφανίζει την θερμοκρασία στην LCD.

- **display_string(" | ")**: Εμφανίζει τον διαχωριστή ` | ` στην LCD.

- **display_pressure(pressure)**: Εμφανίζει την πίεση στην LCD.

##### **Βήμα 8: Εμφάνιση Κατάστασης (Status) στην LCD**

```c
lcd_nextline();

if (nurseStatus) {
    display_string("NURSE CALL");
} else if (pressure > 12 || pressure < 4) {
    display_string("CHECK PRESSURE");
} else if (temp > 37 || temp < 34) {
    display_string("CHECK TEMP");
} else {
    display_string("OK");
}

_delay_ms(10000);
```

- **lcd_nextline()**: Μεταβαίνει στη δεύτερη γραμμή της LCD.

- **if (nurseStatus)**: Αν `nurseStatus` είναι `1`, εμφανίζει "NURSE CALL".

- **else if (pressure > 12 || pressure < 4)**: Αν η πίεση είναι πάνω από 12 ή κάτω από 4 cm H₂O, εμφανίζει "CHECK PRESSURE".

- **else if (temp > 37 || temp < 34)**: Αν η θερμοκρασία είναι πάνω από 37°C ή κάτω από 34°C, εμφανίζει "CHECK TEMP".

- **else**: Αν δεν έχει συμβεί κανένα από τα παραπάνω, εμφανίζει "OK".

- **_delay_ms(10000)**: Προσθέτει καθυστέρηση 10 δευτερολέπτων πριν επαναλάβει τον βρόχο, ώστε να δειτε τα αποτελέσματα στην LCD.

---

## **Συνολική Λειτουργία του Προγράμματος**

1. **Αρχικοποίηση**:
    - Το TWI αρχικοποιείται για επικοινωνία με τον PCA9555 (I/O expander).
    - Η PCA9555 ρυθμίζεται για να ελέγχει την LCD.
    - Η LCD αρχικοποιείται για εμφάνιση μηνυμάτων.
    - Ο ADC ρυθμίζεται για ανάγνωση από το POT0.
    - Η UART αρχικοποιείται για επικοινωνία με το ESP8266.
    - Το buffer αρχικοποιείται για νέα λήψη δεδομένων.
    - Η μεταβλητή `nurseStatus` αρχικοποιείται σε `0`.

2. **Κύριος Βρόχος (Loop)**:
    - **Εντολή "ESP:connect"**:
        - Στέλνει `ESP:connect` μέσω UART.
        - Περιμένει την απάντηση ("Success" ή "Fail").
        - Εμφανίζει "1.Success" ή "1.Fail" στην LCD.
        - Αν αποτύχει, προσπαθεί ξανά να στείλει την εντολή.
        - Αν συνεχιστεί η αποτυχία, προσθέτει καθυστέρηση 1 δευτερολέπτου και επαναλαμβάνει τον βρόχο.
    
    - **Εντολή "ESP:url"**:
        - Στέλνει `ESP:url:"http://192.168.1.250:5000/data"\n` μέσω UART.
        - Περιμένει την απάντηση ("Success" ή "Fail").
        - Εμφανίζει "2.Success" ή "2.Fail" στην LCD.
    
    - **Ανάγνωση Αισθητήρων**:
        - Διαβάζει την θερμοκρασία από τον αισθητήρα DS18B20.
        - Διαβάζει την πίεση από το POT0.
    
    - **Ανίχνευση Πλήκτρων**:
        - Ανιχνεύει αν πατήθηκε το πλήκτρο '7' (θέτει `nurseStatus = 1`) ή το πλήκτρο '#' (θέτει `nurseStatus = 0`).
    
    - **Εμφάνιση Δεδομένων στην LCD**:
        - Εμφανίζει την θερμοκρασία και την πίεση στην πρώτη γραμμή της LCD.
        - Εμφανίζει το κατάλληλο status (`NURSE CALL`, `CHECK PRESSURE`, `CHECK TEMP`, `OK`) στη δεύτερη γραμμή της LCD.
    
    - **Καθυστέρηση 10 Δευτερολέπτων**: Προσθέτει καθυστέρηση πριν επαναλάβει τον βρόχο, ώστε να δειτε τα μηνύματα στην LCD.

---

## **Μεθοδολογία και Λογική του Προγράμματος**

1. **Αρχικοποίηση Επικοινωνίας**:
    - Η αρχικοποίηση του TWI και του UART είναι κρίσιμη για τη σωστή επικοινωνία με τον PCA9555 και το ESP8266.
    - Η ρύθμιση των καταχωρητών στο PCA9555 εξασφαλίζει ότι η LCD είναι σωστά ρυθμισμένη και έτοιμη για χρήση.
    - Η ρύθμιση του ADC εξασφαλίζει ότι η ανάγνωση από το POT0 είναι ακριβής.

2. **Αποστολή Εντολών και Λήψη Απαντήσεων**:
    - Το πρόγραμμα στέλνει συγκεκριμένες εντολές (`ESP:connect` και `ESP:url:"..."`) στο ESP8266 μέσω UART.
    - Περιμένει την απάντηση του ESP8266 και ελέγχει αν η απάντηση είναι "Success" ή "Fail".
    - Εμφανίζει το αντίστοιχο μήνυμα στην LCD για οπτική επιβεβαίωση.

3. **Ανάγνωση Αισθητήρων**:
    - Διαβάζει την θερμοκρασία από τον αισθητήρα DS18B20 μέσω της σύνδεσης 1-Wire.
    - Διαβάζει την πίεση από το POT0 χρησιμοποιώντας τον ADC και μετατρέπει την τιμή σε κλίμακα 0-20 cm H₂O.

4. **Διαχείριση Πληκτρολογίου και Καθορισμός Κατάστασης**:
    - Ανιχνεύει αν έχουν πατηθεί συγκεκριμένα πλήκτρα ('7' για `NURSE CALL` και '#' για επαναφορά).
    - Καθορίζει το κατάλληλο status βάσει των μετρήσεων πίεσης και θερμοκρασίας καθώς και της κατάστασης του `nurseStatus`.

5. **Εμφάνιση Δεδομένων**:
    - Εμφανίζει τις τιμές της θερμοκρασίας και της πίεσης στην πρώτη γραμμή της LCD.
    - Εμφανίζει το status στην δεύτερη γραμμή της LCD, όπως καθορίζεται από τους κανόνες της άσκησης.

6. **Επανάληψη Διεργασίας**:
    - Ο κύριος βρόχος συνεχίζει να επαναλαμβάνει τη διαδικασία αποστολής εντολών, λήψης απαντήσεων, ανάγνωσης αισθητήρων, και εμφάνισης δεδομένων, διασφαλίζοντας συνεχή λειτουργία του συστήματος.

---

## **Κλειδιά Συναρτήσεων και Παραμέτρων**

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

### **twi_init()**

- **Σκοπός**: Ρυθμίζει το TWI για επικοινωνία με τον PCA9555.
- **Παράμετροι**:
    - **Prescaler**: Ρυθμίζει τον prescaler σε 1 για απλή ρύθμιση.
    - **TWBR0**: Ρυθμίζει το ρολόι SCL στα 100kHz.

### **get_temp() και temp()**

- **get_temp()**:
    - Καλεί τη συνάρτηση `temp()` για να λάβει την τιμή θερμοκρασίας.
    - Προσθέτει το `TEMP_OFFSET` για να προσομοιώσει την πραγματική θερμοκρασία ασθενούς.
    - **Επιστρέφει**: Την θερμοκρασία ως `double`.

- **temp()**:
    - Εκτελεί την ακολουθία εντολών για την ανάγνωση της θερμοκρασίας από τον αισθητήρα DS18B20.
    - **Επιστρέφει**: Την τιμή θερμοκρασίας ως 16-bit αριθμό.

### **get_pressure()**

- **Σκοπός**: Διαβάζει την πίεση από το POT0 και τη μετατρέπει σε κλίμακα 0-20 cm H₂O.
- **Επιστρέφει**: Την τιμή πίεσης ως `double`.

### **scan_keypad() και keypad_to_ascii()**

- **scan_keypad()**: Σκάναρει το πληκτρολόγιο και επιστρέφει τα πατημένα πλήκτρα ως 16-bit αριθμό.

- **keypad_to_ascii(uint16_t keys)**: Μετατρέπει τα πατημένα πλήκτρα σε χαρακτήρες ASCII χρησιμοποιώντας τον πίνακα `characters[]`.

### **display_temp() και display_pressure()**

- **display_temp(double input)**: Εμφανίζει την θερμοκρασία στην LCD με μορφή `+36.00°C` ή `-36.00°C`.

- **display_pressure(double input)**: Εμφανίζει την πίεση στην LCD με μορφή `12.00`.

---

## **Συμπεράσματα**

Το πρόγραμμα αυτό είναι ένας ολοκληρωμένος κύκλος επικοινωνίας μεταξύ του ATmega328PB και του ESP8266 μέσω UART, με έξοδο των αποτελεσμάτων να εμφανίζεται στην LCD. Η λογική του προγράμματος ακολουθεί τα εξής βήματα:

1. **Σύνδεση**: Στέλνει την εντολή `ESP:connect` και περιμένει την επιβεβαίωση.
2. **Ρύθμιση URL**: Στέλνει την εντολή `ESP:url:"http://192.168.1.250:5000/data"\n` και περιμένει την επιβεβαίωση.
3. **Ανάγνωση Αισθητήρων**: Διαβάζει τις τιμές της θερμοκρασίας και της πίεσης.
4. **Διαχείριση Πληκτρολογίου**: Ανιχνεύει αν έχουν πατηθεί συγκεκριμένα πλήκτρα για την αλλαγή της κατάστασης.
5. **Υπολογισμός Κατάστασης**: Καθορίζει το κατάλληλο status βάσει των μετρήσεων και των ενέργειων μέσω του πληκτρολογίου.
6. **Εμφάνιση Δεδομένων**: Εμφανίζει τις τιμές της θερμοκρασίας και της πίεσης στην πρώτη γραμμή της LCD και το status στη δεύτερη γραμμή.
7. **Επανάληψη Διεργασίας**: Επαναλαμβάνει τη διαδικασία με καθυστέρηση 10 δευτερολέπτων για ορατότητα των μηνυμάτων.

