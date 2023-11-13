
/*; Ver si estamos esperando bytes de un comando largo
    cpi estado, WAIT_BYTE
    breq comando_byte

    ; La lectura de los siguientes comandos no modifican el estado
    ; (a excepción de ABORT) y se pueden realizar siempre

    cpi temp, ABORT
    breq comando_abort

    cpi temp, PING
    breq comando_ping

    cpi temp, ASK_POSITION
    breq comando_ask_position

    cpi temp, ASK_LASER
    breq comando_ask_laser

    ; Para otros comandos, primero verificamos si estamos en IDLE
    ; Si no, devolvemos que estamos ocupados
    cpi estado, IDLE
    brne send_busy

    ; Leer comando

    cpi temp, SCAN_ROW
    breq comando_scan_row

    cpi temp, MOVE_TO
    breq comando_move_to

    cpi temp, MEDIR_DIST
    breq comando_medir_dist

    cpi temp, TURN_ON_LASER
    breq comando_turn_on_laser

    cpi temp, TURN_OFF_LASER
    breq comando_turn_off_laser

    ; Comando desconocido
    ldi data_type, WHAT
    rcall send_data

    rjmp handler_URXC_end

comando_byte:
    ; Vemos para qué queríamos este byte
    cpi objetivo, WAITING_BYTES_MOVE_TO
    breq comando_byte_move_to

    cpi objetivo, WAITING_BYTES_SCAN_REGION
    breq comando_byte_scan_region

    ; No deberíamos llegar acá
    rjmp handler_URXC_end

comando_byte_move_to:
    ; Vemos a qué corresponde este byte
    cpi bytes_restantes, 2
    breq comando_byte_stepa

    cpi bytes_restantes, 1
    breq comando_byte_stepb

    ; No deberíamos llegar acá
    rjmp handler_URXC_end

comando_byte_stepa:
    ; Todavía falta stepb...
    mov stepa, temp
    dec bytes_restantes

    rjmp handler_URXC_end

comando_byte_stepb:
    ; Ya tenemos todos los datos! Podemos proceder
    mov stepb, temp

    ; Mover
    rcall actualizar_OCR1A
    rcall actualizar_OCR1B

    ; Notificar el cambio
    ldi data_type, CURRENT_POSITION
    rcall send_data

    ; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0

    ; Luego del delay de movimiento no queremos hacer nada
    ldi objetivo, WAITING_COMMAND

    rjmp handler_URXC_end

comando_byte_scan_region:
    ; HACER
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
    ; Devolvemos la posición
    ldi data_type, CURRENT_POSITION
    rcall send_data

    rjmp handler_URXC_end

comando_ask_laser:
    ; Devolvemos el estado actual del láser
    sbis PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    sbic PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

    rjmp handler_URXC_end

send_busy:
    ldi data_type, BUSY
    rcall send_data

    rjmp handler_URXC_end

comando_scan_row:
    ; Mover el servo A al mínimo
    ldi stepa, 0
    rcall actualizar_OCR1A

    ; Notificar del cambio de posición
    ldi data_type, CURRENT_POSITION
    rcall send_data

    ; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0

    ; Setear la distancia mínima en 0xFF
	clr min_dist
	dec min_dist

    ; Actualizar objetivo
    ldi objetivo, SCANNING_ROW

	rjmp handler_URXC_end

comando_move_to:
    ; Necesitamos 2 bytes más (stepa, stepb)
    ldi bytes_restantes, 2
    ldi estado, WAIT_BYTE
    ldi OBJETIVO, WAITING_BYTES_MOVE_TO

    rjmp handler_URXC_end

comando_medir_dist:
    ; Queremos medir solo una vez
	ldi estado, MEDIR
	ldi objetivo, SINGLE_MEASURE

    rjmp handler_URXC_end

comando_turn_on_laser:
	; Encender láser y notificar cambio de estado
	sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

    rjmp handler_URXC_end

comando_turn_off_laser:
	; Apagar láser y notificar cambio de estado
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data

    rjmp handler_URXC_end

handler_URXC_end:
    pop temp
    out sreg, temp
    reti*/