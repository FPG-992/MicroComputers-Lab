;Κώδικας επικοινωνίας μεταξύ μικροελεγκτή και οθόνης
;Αρχικά χρειαζόμαστε μια ρουτίνα που θα μεταφέρει τα δύο τμήματα των 4 bit κάθε εντολής. Η ρουτίνα θα πρέπει
;να αφήνει ανεπηρέαστους τους ακροδέκτες που επιλέγουν μεταξύ καταχωρητή εντολών και καταχωρητή
;δεδομένων, ώστε να μπορεί να χρησιμοποιηθεί και για τις δύο λειτουργίες.

write_2_nibbles:
 push r24 ; save r24(LCD_Data)

 in r25 ,PIND ; read PIND

 andi r25 ,0x0f ;
 andi r24 ,0xf0 ; r24[3:0] Holds previus PORTD[3:0]
 add r24 ,r25 ; r24[7:4] <-- LCD_Data_High_Byte
 out PORTD ,r24 ;

 sbi PORTD ,PD3 ; Enable Pulse
 nop
 nop
 cbi PORTD ,PD3

 pop r24 ; Recover r24(LCD_Data)
 swap r24 ;
 andi r24 ,0xf0 ; r24[3:0] Holds previus PORTD[3:0]
 add r24 ,r25 ; r24[7:4] <-- LCD_Data_Low_Byte
 out PORTD ,r24

 sbi PORTD ,PD3 ; Enable Pulse
 nop
 nop
 cbi PORTD ,PD3

 ret

;Ρουτίνα: lcd_data
;Αποστολή ενός byte δεδομένων στον ελεγκτή της οθόνης lcd. Ο ελεγκτής πρέπει να βρίσκεται σε 4 bit mode. Το
;byte που μεταδίδεται είναι αποθηκευμένο στον καταχωρητή r24

lcd_data:
 sbi PORTD ,PD2 ; LCD_RS=1(PD2=1), Data
 rcall write_2_nibbles ; send data
 ldi r24 ,250 ;
 ldi r25 ,0 ; Wait 250uSec
 rcall wait_usec
 ret

;Ρουτίνα: lcd_command
;Αποστολή μιας εντολής στον ελεγκτή της οθόνης lcd.
;Ο ελεγκτής πρέπει να βρίσκεται σε 4 bit mode.
;Η εντολή που μεταδίδεται είναι αποθηκευμένη στον καταχωρητή r24

lcd_command:
 cbi PORTD ,PD2 ; LCD_RS=0(PD2=0), Instruction
 rcall write_2_nibbles ; send Instruction
 ldi r24 ,250 ;
 ldi r25 ,0 ; Wait 250uSec
 rcall wait_usec
 ret

;Ρουτίνα: lcd_clear_disply
;Καθαρισμός της οθόνης LCD :
lcd_clear_display:

 ldi r24 ,0x01 ; clear display command
 rcall lcd_command

 ldi r24 ,low(5) ;
 ldi r25 ,high(5) ; Wait 5 mSec
 rcall wait_msec ;

 ret

;Για να μπορεί να χρησιμοποιηθεί οθόνη πρέπει να αρχικοποιηθεί στην επιθυμητή κατάσταση. Όταν η οθόνη
;τροφοδοτείται με ρεύμα για πρώτη φορά πραγματοποιείται μια εσωτερική αρχικοποίηση και για αυτό απαιτείται
;χρονική καθυστέρηση 200 ms πριν την τελική αρχικοποίηση.
;Κάθε φορά που προγραμματίζουμε τον Μικροελεγκτή, ξεκινάει η εκτέλεση του κώδικα από την αρχή. Η οθόνη
;όμως βρίσκεται στην κατάσταση που την αφήσαμε την προηγούμενη φορά. Ο κώδικας που θα κάνει την
;αρχικοποίηση της οθόνης δεν γνωρίζει αν ο ελεγκτής της οθόνης βρίσκεται σε 8 bit mode ή σε 4 bit mode. Για το
;λόγο αυτό αρχικά στέλνεται 3 φορές η εντολή 0x30 (function set) για 8 bit mode. Αν ο ελεγκτής είναι σε 8 bit mode
;δεν θα αλλάξει κάτι, αν όμως είναι σε 4 bit mode θα μεταβεί σε 8 bit mode. Στη συνέχεια στέλνεται η εντολή 0x20
;για να οδηγηθεί η οθόνη σε 4 bit mode. Μόλις είμαστε βέβαιοι για την μορφή που πρέπει να στέλνουμε τις εντολές
;μπορούμε να προχωρήσουμε με την αρχικοποίηση.

 lcd_init:
 ldi r24 ,low(200) ;
 ldi r25 ,high(200) ; Wait 200 mSec
 rcall wait_msec ;

 ldi r24 ,0x30 ; command to switch to 8 bit mode
 out PORTD ,r24 ;
 sbi PORTD ,PD3 ; Enable Pulse
 nop
 nop
 cbi PORTD ,PD3
 ldi r24 ,250 ;
 ldi r25 ,0 ; Wait 250uSec
 rcall wait_usec ;

 ldi r24 ,0x30 ; command to switch to 8 bit mode
 out PORTD ,r24 ;
 sbi PORTD ,PD3 ; Enable Pulse
 nop
 nop
 cbi PORTD ,PD3
 ldi r24 ,250 ;
 ldi r25 ,0 ; Wait 250uSec
 rcall wait_usec ;

 ldi r24 ,0x30 ; command to switch to 8 bit mode
 out PORTD ,r24 ;
 sbi PORTD ,PD3 ; Enable Pulse
 nop
 nop
 cbi PORTD ,PD3
 ldi r24 ,250 ;
 ldi r25 ,0 ; Wait 250uSec
 rcall wait_usec

 ldi r24 ,0x20 ; command to switch to 4 bit mode
 out PORTD ,r24
 sbi PORTD ,PD3 ; Enable Pulse
 nop
 nop
 cbi PORTD ,PD3
 ldi r24 ,250 ;
 ldi r25 ,0 ; Wait 250uSec
 rcall wait_usec

 ldi r24 ,0x28 ; 5x8 dots, 2 lines
 rcall lcd_command

 ldi r24 ,0x0c ; dislay on, cursor off
 rcall lcd_command
  
 rcall lcd_clear_display

 ldi r24 ,0x06 ; Increase address, no display shift
 rcall lcd_command ;
 ret