#set document(
    title: "Εργαστήριο Μικροϋπολογιστών - 2η Εργαστηριακή Άσκηση",
    author: "Χριστόφορος Χαραλάμπους 03121614, Φίλιππος Γιανακόπουλος 03121629",
)
#set align(center)
#set page(
  paper: "a4",
  margin: (x: 1.5cm, y: 1.5cm)
)
#set text(font: "Lato")
#show math.equation: set text(font: "Lato Math")
#show table.cell.where(y: 0): set text(weight: "bold")

#align(horizon)[
    #text(size: 20pt)[Εθνικό Μετσόβιο Πολυτεχνείο] \ \ \

    #image("emp.svg", width: 40%) \

    #text(size: 20pt)[
        Εργαστήριο Μικροϋπολογιστών \
        2η Εργαστηριακή Άσκηση \
    ]
]

#align(bottom)[
    #text(size: 14pt)[
        Χριστόφορος Χαραλάμπους 03121614 \
        Φίλιππος Γιανακόπουλος 03121629 \
        Ομάδα 17
    ]
]

#pagebreak()
#set align(left)
#set par(justify: true)
#set page(
    numbering: "- 1 -",
    number-align: center
)
#counter(page).update(1)

= Ζήτημα 2.1
Το Ζήτημα 2.1 βρίσκεται στο αρχείο `erg2.1.asm`.

```ASM
.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=500
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms
    
.def count=r26
.def countINT=r27
    
.org 0x0
    rjmp reset
    
.org 0x4
    rjmp ISR1
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; Set PORTB as output
    ser r24
    out DDRB,r24
    
    ; Set PORTC as output
    ser r24
    out DDRC,r24
    
    ; Set PORTD as input
    clr r24
    out DDRD,r24
    
    ; Setup interrupts
    ldi r24,(1 << ISC11) | (1 << ISC10)
    sts EICRA,r24
    
    ldi r24, (1 << INT1)
    out EIMSK,r24
    
    sei
    
    ; Setup INT1 counter
    clr countINT
    out PORTC, countINT
    
    ; Load delay to r24-r25
    ldi r24, low(F1)
    ldi r25, high(F1)
    
loop1:
    clr count
loop2:
    out PORTB,count
    
    rcall wait_x_msec
    
    inc count
    
    cpi count,16
    breq loop1
    rjmp loop2
   
ISR1:
    push r23
    push r24
    push r25
    in r24,SREG
    push r24
    
    ; Load delay of 5ms for repeated checks
    ldi r24, low(F2)
    ldi r25, high(F2)
    
repeat:
    ldi r23,(1<<INTF1)
    out EIFR,r23
    
    rcall wait_x_msec
    
    in r23,EIFR
    sbrc r23,INTF1
    rjmp repeat
    
    ; Collect PORTD input
    ser r23
    out portd, r23
    in r23, pind
    
    ; If PD5 = 0 (pressed), skip to finish
    sbrs r23,5
    rjmp finish
    
    inc countINT
    cpi countINT,64
    brne finish
    
    clr countINT   
    
finish:
    out PORTC, countINT
    
    pop r24
    out SREG,r24
    pop r25
    pop r24
    pop r23
    
    reti
    
wait_x_msec:
    push r23
    push r24
    push r25
repeat_x:
    rcall wait_one_msec
    sbiw r24,1
    brne repeat_x
    
    pop r25
    pop	r24
    pop r23
    ret

wait_one_msec:
    ldi	r23, 247
repeat_one:
    dec r23
    nop
    brne repeat_one
    
    nop
    ret
```

Ο έλεγχος του σπινθηρισμού έγινε βάση του σχεδιαγράμματος, συγκεκριμένα με τον ακόλουθο κώδικα:

```ASM
ldi r23,(1<<INTF1)
out EIFR,r23

rcall wait_x_msec

in r23,EIFR
sbrc r23,INTF1
rjmp repeat
```

#pagebreak()

= Ζήτημα 2.2
Το Ζήτημα 2.2 βρίσκεται στο αρχείο `erg2.2.asm`.

```ASM
.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=2000
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms
    
.def count=r26
    
.org 0x0
    rjmp reset
    
.org 0x2
    rjmp ISR0
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; Set PORTB as input
    clr r24
    out DDRB,r24
    
    ; Set PORTC as output
    ser r24
    out DDRC,r24
    
    ; Setup interrupts
    ldi r24,(1 << ISC01) | (0 << ISC00)
    sts EICRA,r24
    
    ldi r24, (1 << INT0)
    out EIMSK,r24
    
    sei
    
    ; Load delay to r24-r25
    ldi r24, low(F1)
    ldi r25, high(F1)
    
loop1:
    clr count
loop2:
    out PORTC,count
    
    rcall wait_x_msec
    
    inc count
    
    cpi count,32
    breq loop1
    rjmp loop2
   
ISR0:
    push r23
    push r24
    push r25
    in r24,SREG
    push r24
    
    ; Load delay of 5ms for repeated checks
    ldi r24, low(F2)
    ldi r25, high(F2)
    
repeat:
    ldi r23,(1<<INTF0)
    out EIFR,r23
    
    rcall wait_x_msec
    
    in r23,EIFR
    sbrc r23,INTF0
    rjmp repeat
    
    ; Collect PORTB input
    ser r23
    out PORTB, r23
    in r23, PINB
    
    clr r24
        
    ; If PB0 = 1 (unpressed), skip to next
    sbrc r23,0
    rjmp second
    ori r24,1
    
second:
    sbrc r23,1
    rjmp third
    lsl r24
    ori r24,1
    
third:
    sbrc r23,2
    rjmp fourth
    lsl r24
    ori r24,1
    
fourth:
    sbrc r23,3
    rjmp finish
    lsl r24
    ori r24,1
    
    
finish:
    out PORTC, r24
    
    ldi r24,low(16*500)
    ldi r25,high(16*500)
    
    rcall wait_x_msec
    
    pop r24
    out SREG,r24
    pop r25
    pop r24
    pop r23
    
    reti
    
wait_x_msec:
    push r23
    push r24
    push r25
repeat_x:
    rcall wait_one_msec
    sbiw r24,1
    brne repeat_x
    
    pop r25
    pop	r24
    pop r23
    ret

wait_one_msec:
    ldi	r23, 247
repeat_one:
    dec r23
    nop
    brne repeat_one
    
    nop
    ret
```

Για την παρουσίαση των bit του PORTB που είναι πατημένα, προστέθηκε μια χρονοκαθυστέρηση `500ms` όταν δωθεί `INT0`, έτσι ώστε να υπάρχει χρόνος για να φανεί το αποτέλεσμα.

Ο υπολογισμός των bit που πρέπει να εμφανιστούν έγινε με την χρήση Left Logical Shift και εντολής ORI για την προσθήκη νεόυ ενεργοποιημένου bit στο LSB.

#pagebreak()

= Ζήτημα 2.3
== Assembly
Το Ζήτημα 2.3 σε Assembly βρίσκεται στο αρχείο `erg2.3.asm`.

```ASM
.include "m328PBdef.inc"

.equ FOSC_MHZ=16
.equ DEL_mS=50
.equ DEL_INT_ms=5
.equ F1=FOSC_MHZ*DEL_mS
.equ F2=FOSC_MHZ*DEL_INT_ms
    
.def count=r26
.def updated=r27
    
.org 0x0
    rjmp reset
    
.org 0x4
    rjmp ISR1
    
reset:
    ; Initialize Stack Pointer
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24
    
    ; Set PORTB as output
    ser r24
    out DDRB,r24
    
    ; Setup interrupts
    ldi r24,(1 << ISC11) | (1 << ISC10)
    sts EICRA,r24
    
    ldi r24, (1 << INT1)
    out EIMSK,r24
    
    sei
    
    ; Load delay to r24-r25
    ldi r24, low(F1)
    ldi r25, high(F1)
    
start:
    cpi count,0
    brne check1
    
    clr updated
    clr r28
    out PORTB, r28
    rjmp end
    
check1:
    cpi count,91
    brsh check2
    
    ldi r28,0x01
    out PORTB,r28
    rjmp decrement
    
check2:
    sbrc updated,0
    rjmp displayAll
    
    ldi r28,0x01
    out PORTB,r28
    rjmp decrement
    
displayAll:
    ser r28
    out PORTB,r28
    
decrement:
    dec count    
end:
    rcall wait_x_msec
    rjmp start    
   
ISR1:
    push r23
    push r24
    push r25
    in r24,SREG
    push r24
    
    ; Load delay of 5ms for repeated checks
    ldi r24, low(F2)
    ldi r25, high(F2)
    
repeat:
    ldi r23,(1<<INTF1)
    out EIFR,r23
    
    rcall wait_x_msec
    
    in r23,EIFR
    sbrc r23,INTF1 ; 0 for INT0 1 for INT1???
    rjmp repeat
    
    cpi count,0
    breq skip
    ldi updated,0x01
    
skip:
    ldi count,100
    
finish:    
    pop r24
    out SREG,r24
    pop r25
    pop r24
    pop r23
    
    reti
    
wait_x_msec:
    push r23
    push r24
    push r25
repeat_x:
    rcall wait_one_msec
    sbiw r24,1
    brne repeat_x
    
    pop r25
    pop	r24
    pop r23
    ret

wait_one_msec:
    ldi	r23, 247
repeat_one:
    dec r23
    nop
    brne repeat_one
    
    nop
    ret
```

Γίνεται χρήση ρολογιού στην κύρια επανάληψη του προγράμματος με χρονοκαθυστέρηση `50ms`, έτσι ώστε ο κύριος μετρητής να χρειάζεται να χωράει μέχρι το 100, και άρα να μπορεί να είναι μονός καταχωρητής.


#pagebreak()

== C
Το Ζήτημα 2.3 σε C βρίσκεται στο αρχείο `erg2.3.c`.

```C
#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

int counter;
char update;

ISR(INT1_vect) {
    do {
        EIFR = (1<<INTF1);
        _delay_ms(5);
    } while ((EIFR && 1<<INTF1) != 0);
    
    if (counter != 0) {
        update = 1;
    }
    counter = 5000;
}

int main(void) {
    EICRA = (1<<ISC11)|(1<<ISC10);
    
    EIMSK = (1<<INT1);
    
    sei();
    
    DDRB = 0xFF;
    PORTB = 0x00;
    
    counter = 0;
    update = 0;
    
    while (1) {
        if (counter > 4500 && update == 1) {
            PORTB = 0b00111111;
            _delay_ms(1);
            counter--;
        } else if (counter > 0) {
            PORTB = 0x01;
            _delay_ms(1);
            counter--;
        } else {
            PORTB = 0x00;
            update = 0;
        }
    }
}
```