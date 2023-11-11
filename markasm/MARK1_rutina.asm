;
; MARK1_rutina.asm
;
; Created: 11/11/2023 16:12:54
; Author: FR & NN
; 

start_timer0:
    ; Cuenta en 0
    clr temp
    out TCNT0, temp

    ; Prescaler 1024
    ldi temp, (1 << CS12) | (0 << CS12) | (1 << CS12)
    out TCCR0B, temp
    
    ret

stop_timer0:
    ; Apagado
    ldi temp, (0 << CS12) | (0 << CS12) | (0 << CS12)
    out TCCR0B, temp
    
    ret

send_trigger:
    ret
