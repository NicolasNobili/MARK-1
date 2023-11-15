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
loop_trig:
	dec temp
	brne loop_trig
	cbi PORTB, ULTRASOUND_TRIG

	ret


; ------------------------------------------------------
;                COMUNICACIÓN SERIAL
; ------------------------------------------------------

; Se debe cargar previamente el registro data_type
send_data:
    ; Mandar primero el byte de tipo de dato
    mov tempbyte, data_type
    rcall send_byte

    ; Ver si hay que mandar bytes extra, según el tipo de dato

    cpi data_type, MEASUREMENT
    breq send_measurement

    cpi data_type, CURRENT_POSITION
    breq send_position

	cpi data_type, DEBUG
	breq send_debug

    ; No hace falta mandar bytes extra
    rjmp send_data_end

send_measurement:
    ; Formato: A, B 
    mov tempbyte, stepa
    rcall send_byte
    mov tempbyte, stepb
    rcall send_byte

	;Formato: lectural , lecturah (little-endian)
    mov tempbyte, lectural
    rcall send_byte
	mov tempbyte, lecturah
    rcall send_byte

    rjmp send_data_end

send_position:
    ; Formato: A, B
    mov tempbyte, stepa
    rcall send_byte
    mov tempbyte, stepb
    rcall send_byte

    rjmp send_data_end

send_debug:
	mov tempbyte, lecturah
    rcall send_byte

	rjmp send_data_end

send_data_end:
    ret


; Se debe cargar previamente el registro tempbyte
send_byte:
    lds temp, UCSR0A
    sbrs temp, UDRE0
    rjmp send_byte

    sts UDR0, tempbyte
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

	; Setear la distancia m?nima en 0xFFFF
	clr min_disth
	dec min_disth

	clr min_distl
	dec min_distl

	; Actualizar objetivo
    ldi objetivo, SCANNING

	ret