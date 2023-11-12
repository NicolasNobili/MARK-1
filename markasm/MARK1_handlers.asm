; ---------------------------------
; MARK1_handlers.asm
;
; Created: 11/11/2023 11:54:04 AM
; Authors: FR & NN
; ---------------------------------


; ------------------------------------------------------
;                   OVERFLOW TIMER 0
; ------------------------------------------------------

handler_OVF0:
    in temp, sreg
    push temp

    ; Verificar si debemos seguir esperando
    dec left_ovfs
    brne handler_OVF0_end

    ; Una vez que ya no hay m�s espera, apagar
    ; timer 0 y ver qu� sigue hacer
    rcall stop_timer0

    cpi objetivo, SCANNING_ROW
    breq objetivo_scanning_row

	cpi objetivo, PRENDER_LASER
    breq objetivo_prender_laser

	cpi objetivo, APAGAR_LASER
    breq objetivo_apagar_laser

    ; Sin objetivo
    rjmp handler_OVF0_end

objetivo_scanning_row:
    rcall stop_timer0

    ; Solicitamos una medici�n (al main loop)
    ldi estado, MEDIR

    rjmp handler_OVF0_end

objetivo_prender_laser:
    ; Es necesario?
	rcall stop_timer0

    ; Encender l�ser y notificar cambio de estado
	sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

    ; Dar un tiempo para mantener el laser prendido
	ldi estado, DELAY
	ldi objetivo, APAGAR_LASER
	ldi left_ovfs, DELAY_LASER
	rcall start_timer0

	rjmp handler_OVF0_end

objetivo_apagar_laser:
    ; Se termin� la fiesta
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data

	rcall stop_timer0
	ldi estado, IDLE
	ldi objetivo, WAITING_COMMAND

	rjmp handler_OVF0_end

handler_OVF0_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;                   OVERFLOW TIMER 2
; ------------------------------------------------------

handler_OVF2:
	in temp,sreg
	push temp
	
	inc count_ovfs

handler_OVF2_end:
	pop temp
	out sreg,temp
	reti


; ------------------------------------------------------
;                  COMUNICACI�N SERIAL
; ------------------------------------------------------

; Recepci�n de comandos
handler_URXC:
    in temp, sreg
    push temp

    ; Leer caracter
    lds temp, UDR0

    ; La lectura de los siguientes comandos no modifican el estado
    ; (a excepci�n de ABORT) y se pueden realizar siempre

    cpi temp, ABORT
    breq comando_abort

    cpi temp, PING
    breq comando_ping

    cpi temp, ASK_POSITION
    breq comando_ask_position

    cpi temp, ASK_LASER
    breq comando_ask_laser

    ; Para otros comandos, primero verificamos si estamos en IDLE o WAITING_COMMAND
    cpi estado, IDLE
    brne handler_URXC_end

    ; Leer comando

    cpi temp, SCAN_ROW
    breq comando_scan_row

    cpi temp, MEDIR_DIST
    breq comando_medir_dist

    cpi temp, TURN_ON_LASER
    breq comando_turn_on_laser

    cpi temp, TURN_OFF_LASER
    breq comando_turn_off_laser

    ; Comando desconocido
    rjmp handler_URXC_end

comando_abort:
    ; Nos quedamos donde estamos
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

    rjmp handler_URXC_end

comando_ping:
    ; Ping - pong
    ldi data_type, PONG
    rcall send_data

    rjmp handler_URXC_end

comando_ask_position:
    ; Devolvemos la posici�n
    ldi data_type, CURRENT_POSITION
    rcall send_data

    rjmp handler_URXC_end

comando_ask_laser:
    ; Devolvemos el estado actual del l�ser
    sbis PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    sbic PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

    rjmp handler_URXC_end

comando_scan_row:
    ; Mover el servo A al m�nimo
    ldi stepa, 0
    rcall actualizar_OCR1A

    ; Notificar del cambio de posici�n
    ldi data_type, CURRENT_POSITION
    rcall send_data

    ; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0

    ; Setear la distancia m�nima en 0xFF
	clr min_dist
	dec min_dist

    ; Actualizar objetivo
    ldi objetivo, SCANNING_ROW

	rjmp handler_URXC_end

comando_medir_dist:
    ; Queremos medir solo una vez
	ldi estado, MEDIR
	ldi objetivo, SINGLE_MEASURE

    rjmp handler_URXC_end

comando_turn_on_laser:
	; Encender l�ser y notificar cambio de estado
	sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

    rjmp handler_URXC_end

comando_turn_off_laser:
	; Apagar l�ser y notificar cambio de estado
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data

    rjmp handler_URXC_end

handler_URXC_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;           INTERRUPCI�N INT0 PARA DEBUGEAR
; ------------------------------------------------------

handler_INT0:
    in temp, sreg
    push temp

    ; Falta implementar la medici�n de tiempo

    ; Mandar informaci�n por USART (stepa, stepb, medicion)

    cpi stepa, MAX_STEPA
    breq terminar_objetivo_aux_aux

    rcall stepa_up
    ldi estado, DELAY
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0

    rjmp handler_INT0_end

terminar_objetivo_aux_aux:
	ldi stepa,STEPA_INICIAL
	rcall actualizar_OCR1A
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

handler_INT0_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;           INTERRUPCI�N PIN CHANGE 0 (ECHO)
; ------------------------------------------------------

handler_PCIO:
	in temp,sreg
	push temp

    ; Determinar en qu� flanco estamos
	sbic PINB, ULTRASOUND_ECHO
	rjmp start_measure

process_measure:
    ; Flanco descendiente, termina la lectura
	rcall stop_timer2

    ; Convertir la lectura a 1 byte
	lds temp, TCNT2
	lsr count_ovfs
	ror lectura
	
    ; Comparar con m�nimo
	cp lectura, min_dist
	brsh send_measure

    ; Reemplazar m�nimo
	mov min_dist, lectura
	mov min_stepa, stepa
	mov min_stepb, stepb

send_measure:
    ; Mandar info al serial
    ldi data_type, MEASUREMENT
	rcall send_data

    ; C�mo seguimos depende del objetivo actual

	cpi objetivo, SINGLE_MEASURE
	breq terminar_single_measure
    
    cpi objetivo, SCANNING_ROW
    breq continuar_scanning_row

    ; No deber�a llegar ac�
    rjmp handler_PCI0_end

continuar_scanning_row:
    ; Vemos si podemos seguir avanzando
    cpi stepa, MAX_STEPA
    breq terminar_scanning_row

    ; Podemos seguir, dar tiempo
    ; para moverse a la siguiente posici�n
    rcall stepa_up
    ldi estado, DELAY
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0

    rjmp handler_PCI0_end

terminar_scanning_row:
    ; No podemos seguir avanzando, vamos
    ; a apuntar al m�nimo que encontramos
    mov stepa, min_stepa
    rcall actualizar_OCR1A
    mov stepb, min_stepb
    rcall actualizar_OCR1B
    
    ; Enviamos el cambio de posici�n
    ldi data_type, CURRENT_POSITION
    rcall send_data
    
    ; Ahora queremos prenderle un laser,
    ; despu�s de habernos movido ah�
    ldi objetivo, PRENDER_LASER
    ldi estado, DELAY
    ldi left_ovfs, DELAY_MOVIMIENTO
    rcall start_timer0

    rjmp handler_PCI0_end

terminar_single_measure:
    ; Nos quedamos donde estamos y listo
	ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND
	rjmp handler_PCI0_end

start_measure:
    ; Flanco ascendente, reci�n comienza la lectura
    ; Iniciar el timer 2 (m�s el bit extra por overflows)
	clr count_ovfs
	rcall start_timer2
    rjmp handler_PCI0_end

handler_PCI0_end:
	pop temp
	out sreg,temp
	reti
