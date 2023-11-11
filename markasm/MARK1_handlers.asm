;
; MARK1_handlers.asm
;
; Created: 11/11/2023 11:54:04 AM
; Authors: FR & NN
; 


handler_OVF0:
    in temp, sreg
    push temp

    dec left_ovfs
    brne handler_OVF0_end

    rcall stop_timer0

    cpi objetivo, SCANNING_ROW
    breq objetivo_scanning_row

    ; Sin objetivo
    rjmp handler_OVF0_end

objetivo_scanning_row:
    ldi estado, MEDIR
    rjmp handler_OVF0_end

handler_OVF0_end:
    pop temp
    out sreg, temp
    reti

; Recepción de comandos
handler_URXC:
    in temp, sreg
    push temp

    ; Leer caracter
    lds temp, UDR0

    ; La lectura de ABORT se puede realizar en cualquier estado
    cpi temp, ABORT
    breq comando_abort

    ; Para otros comandos, primero verificamos si estamos en IDLE
    cpi estado, IDLE
    brne handler_URXC_end

    cpi temp, SCAN_ROW
    breq comando_scan_row

    ; Comando desconocido
    rjmp handler_URXC_end

comando_abort:
    ldi estado, IDLE
    rjmp handler_URXC_end

comando_scan_row:
    ; Mover el servo A al origen
    ldi stepa, 0
    rcall actualizar_OCR1A

    ; Hacer un delay por overflows
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0
    ldi objetivo, SCANNING_ROW

    rjmp handler_URXC_end

handler_URXC_end:
    pop temp
    out sreg, temp
    reti


; COPIAR AL CÓDIGO DE ECHO
handler_INT0:
    in temp, sreg
    push temp

    ; Falta implementar la medición de tiempo

    ; Mandar información por USART (stepa, stepb, medicion)

    cpi stepa, MAX_STEPA
    breq terminar_objetivo

    rcall stepa_up
    ldi estado, DELAY
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0

    rjmp handler_INT0_end

terminar_objetivo:
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

handler_INT0_end:
    pop temp
    out sreg, temp
    reti