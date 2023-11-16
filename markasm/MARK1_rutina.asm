; ---------------------------------
; MARK1_rutina.asm
;
; Created: 11/11/2023 16:12:54
; Author: FR & NN
; ---------------------------------


; ------------------------------------------------------
;                       TIMER 0
; ------------------------------------------------------

start_timer0:
    ; Cuenta en 0
    clr temp
    out TCNT0, temp

    ; Prescaler 1024
    ldi temp, (1 << CS02) | (0 << CS01) | (1 << CS00)
    out TCCR0B, temp
    
    ret


stop_timer0:
    ; Apagado
    ldi temp, (0 << CS02) | (0 << CS01) | (0 << CS00)
    out TCCR0B, temp
    
    ret


; ------------------------------------------------------
;                       TIMER 2
; ------------------------------------------------------

start_timer2:
    ; Cuenta en 0
    clr temp
    sts TCNT2, temp

    ; Prescaler 8
    ldi temp, (0 << CS22) | (1 << CS21) | (0 << CS20)
	sts TCCR2B, temp
    ret


stop_timer2:
    ; Apagado
    ldi temp, (0 << CS22) | (0 << CS21) | (0 << CS20)
    sts TCCR2B, temp
    
    ret

; ------------------------------------------------------
;                       TRIGGER
; ------------------------------------------------------

send_trigger:
	;Limpiar flag de PCI0 y activar la interrupcion
	sbi PCIFR,PCIF0
	 
	lds temp,PCICR
	ori temp,(1 << PCIE0)
	sts PCICR,temp
	
	sbi PORTB, ULTRASOUND_TRIG
	ldi temp, LOOPS_TRIGGER
	mov loop_trigger, temp
loop_trig:
	dec loop_trigger
	brne loop_trig
	cbi PORTB, ULTRASOUND_TRIG

	ret


; ------------------------------------------------------
;                COMUNICACIÓN SERIAL
; ------------------------------------------------------

; Se debe cargar previamente el registro data_type
send_data:
    ; Mandar primero el byte de tipo de dato
    mov temp_byte, data_type
    rcall send_byte

    ; Ver si hay que mandar bytes extra, según el tipo de dato

    cpi data_type, MEASUREMENT
    breq send_measurement

    cpi data_type, CURRENT_POSITION
    breq send_position

	cpi data_type, DEBUG
	breq send_debug

	cpi data_type, STATE
	breq send_state

	cpi data_type, OBJECTIVE
	breq send_objective

    ; No hace falta mandar bytes extra
    rjmp send_data_end

send_measurement:
    ; Formato: A, B 
    mov temp_byte, stepa
    rcall send_byte
    mov temp_byte, stepb
    rcall send_byte

	;Formato: lectural , lecturah (little-endian)
    mov temp_byte, lectural
    rcall send_byte
	mov temp_byte, lecturah
    rcall send_byte

    rjmp send_data_end

send_position:
    ; Formato: A, B
    mov temp_byte, stepa
    rcall send_byte
    mov temp_byte, stepb
    rcall send_byte

    rjmp send_data_end

send_debug:
	mov temp_byte, lecturah
    rcall send_byte

	rjmp send_data_end

send_state:
	mov temp_byte, estado
	rcall send_byte

	rjmp send_data_end

send_objective:
	mov temp_byte, objetivo
	rcall send_byte

	rjmp send_data_end

send_data_end:
    ret


; Se debe cargar previamente el registro temp_byte
send_byte:
    lds temp, UCSR0A
    sbrs temp, UDRE0
    rjmp send_byte

    sts UDR0, temp_byte
    ret


; ------------------------------------------------------
;                RUTINAS DE BYTES
; ------------------------------------------------------

rutina_comando_byte_move_to:
    ; Vemos a qu? corresponde este byte
    mov temp, bytes_restantes

    cpi temp, 2
    breq comando_byte_stepa

    cpi temp, 1
    breq comando_byte_stepb

    ; No deber?amos llegar ac?
    rjmp rutina_comando_byte_move_to_end


comando_byte_stepa:
    ; Todav?a falta stepb...
    mov stepa, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

    rjmp rutina_comando_byte_move_to_end


comando_byte_stepb:
    ; Ya tenemos todos los datos! Podemos proceder
    mov stepb, byte_recibido

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

rutina_comando_byte_move_to_end:
    ret








rutina_comando_byte_scan_region:
    mov temp, bytes_restantes

    cpi temp, 4
    breq comando_byte_first_stepa

    cpi temp, 3
    breq comando_byte_first_stepb

	cpi temp, 2
	breq comando_byte_last_stepa

	cpi temp, 1
	breq comando_byte_last_stepb

comando_byte_first_stepa:
	mov first_stepa, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

	rjmp rutina_comando_byte_scan_region_end

comando_byte_first_stepb:
	mov first_stepb, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

	rjmp rutina_comando_byte_scan_region_end

comando_byte_last_stepa:
	mov last_stepa, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

	rjmp rutina_comando_byte_scan_region_end

comando_byte_last_stepb:
	mov last_stepb, byte_recibido
	rcall start_scan

	rjmp rutina_comando_byte_scan_region_end

rutina_comando_byte_scan_region_end:
    ret








rutina_comando_byte_write_info:
    ; Guardar al búffer
    st x+, byte_recibido

    ; Fijarse si es el null para terminar
    cpi byte_recibido, 0
    breq comando_byte_write_info_end

    rjmp rutina_comando_byte_write_info_end
    
comando_byte_write_info_end:
    ; Iniciar escritura de RAM a EEPROM
    ; Bloquea el programa
    rcall copiar_buffer_a_eeprom
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND
    ldi data_type, WRITE_INFO_DONE
    rcall send_data

rutina_comando_byte_write_info_end:
    ret


; ------------------------------------------------------
;                RUTINAS DE COMANDOS
; ------------------------------------------------------

rutina_comando_abort:
    ; Nos quedamos donde estamos
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

    ret


rutina_comando_ping:
    ; Ping - pong
    ldi data_type, PONG
    rcall send_data
	ldi estado,IDLE

    ret


rutina_comando_ask_position:
    ; Devolvemos la posici?n
    ldi data_type, CURRENT_POSITION
    rcall send_data
	ldi estado,IDLE

    ret


rutina_comando_ask_laser:
    ; Devolvemos el estado actual del l?ser
    sbis PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    sbic PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data
	ldi estado,IDLE

    ret


rutina_comando_ask_state:
	ldi data_type, STATE
	rcall send_data
	ldi estado,IDLE

	ret


rutina_comando_ask_objective:
	ldi data_type, OBJECTIVE
	rcall send_data
	ldi estado,IDLE

	ret


rutina_comando_scan_row:
	mov first_stepa, zero
	ldi temp, MAX_STEPA
	mov last_stepa, temp

	mov first_stepb, stepb
	mov last_stepb, stepb

	rcall start_scan

	ret


rutina_comando_scan_col:
	mov first_stepa, stepa
	mov last_stepa, stepa

	mov first_stepb, zero
	ldi temp, MAX_STEPB
	mov last_stepb, temp

	rcall start_scan

	ret


rutina_comando_scan_all:
	mov first_stepa, zero
	ldi temp, MAX_STEPA
	mov last_stepa, temp

	mov first_stepb, zero
	ldi temp, MAX_STEPB
	mov last_stepb, temp

	rcall start_scan

	ret


rutina_comando_scan_region:
    ; Necesitamos 4 bytes mas (first_stepa, first_stepb, last_stepa, last_stepb)
	ldi temp, 4
	mov bytes_restantes, temp
	ldi estado, WAIT_BYTE
    ldi OBJETIVO, WAITING_BYTES_SCAN_REGION

	ret


rutina_comando_move_to:
    ; Necesitamos 2 bytes mas (stepa, stepb)
	ldi temp, 2
	mov bytes_restantes, temp
    ldi estado, WAIT_BYTE
    ldi OBJETIVO, WAITING_BYTES_MOVE_TO

    ret


rutina_comando_medir_dist:
    ; Queremos medir solo una vez
	ldi estado, MEDIR
	ldi objetivo, SINGLE_MEASURE

    ret


rutina_comando_turn_on_laser:
	; Encender l?ser y notificar cambio de estado
	sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data
	ldi estado,IDLE

    ret


rutina_comando_turn_off_laser:
	; Apagar l?ser y notificar cambio de estado
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data
	ldi estado,IDLE

    ret


rutina_comando_write_info:
    ldx buffer
    ldi estado, WAIT_BYTE
    ldi objetivo, WAITING_BYTES_WRITE_INFO

    ret

; ------------------------------------------------------
;                      START SCAN
; ------------------------------------------------------

start_scan:
	;Deben estar cargados los valores limites de stepa y stepb segun sea el caso
	
	; Mover el servo A y B a la primer  posicion
	mov stepa,first_stepa
	mov stepb,first_stepb

	rcall actualizar_OCR1A
	rcall actualizar_OCR1B

	ldi data_type, CURRENT_POSITION
    rcall send_data

	; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0

	; Setear la distancia mínima en 0xFFFF
	clr min_disth
	dec min_disth

	clr min_distl
	dec min_distl

	; Actualizar objetivo
    ldi objetivo, SCANNING

	ret


; ------------------------------------------------------
;                         EEPROM
; ------------------------------------------------------

copiar_buffer_a_eeprom:
    ldx buffer
    ldy INFO_ADDR
    ldi temp, MAX_STRING
    mov index, temp

copiar_buffer_a_eeprom_loop:
    ld temp_byte, x+
    rcall eeprom_write
    ld temp, y+  ; Incrementar Y


    cp temp_byte, zero
    brne copiar_buffer_a_eeprom_loop

    dec index
    brne copiar_buffer_a_eeprom_loop

    ; Por las dudas, finalizar con un NULL
    ; en la última posición escrita
    ld temp, -y
    clr temp_byte
    rcall eeprom_write

    ret


; Usa temp_byte y el puntero Y
; para la dirección
eeprom_write:
    ; Verificar si podemos escribir
    sbic EECR, EEPE
    rjmp eeprom_write
    
    ; Address
    out EEARH, xh
    out EEARL, xl

    ; Data
    out EEDR, temp_byte

    ; Enable
    sbi EECR, EEMPE
    sbi EECR, EEPE

    ret
