.include "m328PBdef.inc"

.def A=r20
.def B=r21
.def C=r22
.def D=r23
.def Bt=r24
.def Ct=r25
.def Dt=r26
.def F0=r27
.def F1=r28
.def temp=r29
    
.def counter=r30

reset:
    ; Initialize Stack
    ldi r24, LOW(RAMEND)
    out SPL, r24
    ldi r24, HIGH(RAMEND)
    out SPH, r24

main:
    ldi A,0x51
    ldi B,0x41
    ldi C,0x21
    ldi D,0x01
    ldi counter,0x06
    
repeat:
    ; Copy the registers
    mov Bt,B
    mov Ct,C
    mov Dt,D
    ; Inverse them
    com Bt
    com Ct
    com Dt
    ; F0
    mov temp,A
    and temp,Bt
    mov F0,Bt
    and F0,D
    or F0,temp
    com F0
    
    ; F1
    mov temp,A
    or temp,Ct
    mov F1,B
    or F1,Dt
    and F1,temp
    
    ; Prepare new ABCD
    ldi temp,0x01
    add A,temp
    inc temp
    add B,temp
    inc temp
    add C,temp
    inc temp
    add D,temp
    
    dec counter
    brne repeat
    
finish:


