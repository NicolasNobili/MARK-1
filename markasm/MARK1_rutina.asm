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
    ; No interrumpir para tener un pulso exacto siempre
    cli

	; Limpiar flag de PCI2 y activar la interrupcion
    sbic PCIFR, PCIF2
	sbi PCIFR, PCIF2
	 
	lds temp, PCICR
	ori temp, (1 << PCIE2)
	sts PCICR, temp
	
	sbi PORTD, ULTRASOUND_TRIG
	ldi temp, LOOPS_TRIGGER
	mov loop_index, temp
send_trigger_loop:
	dec loop_index
	brne send_trigger_loop
	cbi PORTD, ULTRASOUND_TRIG

    sei
	ret


; ------------------------------------------------------
;                COMUNICACIÓN SERIAL
; ------------------------------------------------------

; Se debe cargar previamente el registro data_type
send_data:
    cli

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

	cpi data_type, MEASURE_STATE
	breq send_state

	cpi data_type, INFO
	breq send_info

    ; Si se llegó acá, no
    ; hace falta mandar bytes extra
    rjmp send_data_end

send_measurement:
	; Convertir a cm primero.
	rcall convertir_a_cm
    ; Guardar en RAM el valor.
    ; rcall convertir_lectura_ascii
    ; Comentado porque es innecesario para nuestro proyecto.

    ; Formato: STEPA, STEPB, LECTURAL, LECTURAH
    ; (Little-endian) 
    mov temp_byte, stepa
    rcall send_byte
    mov temp_byte, stepb
    rcall send_byte

    mov temp_byte, lectural
    rcall send_byte
	mov temp_byte, lecturah
    rcall send_byte

    rjmp send_data_end

send_position:
    ; Formato: STEPA, STEPB
    mov temp_byte, stepa
    rcall send_byte
    mov temp_byte, stepb
    rcall send_byte

    rjmp send_data_end

send_debug:
    ; Acá poner el dato que sea necesario.
	mov temp_byte, lecturah
    rcall send_byte

	rjmp send_data_end

send_state:
	mov temp_byte, estado_medicion
	rcall send_byte

	rjmp send_data_end

send_info:
	; Leemos byte por byte en eeprom
	ldy INFO_ADDR
	ldi temp, MAX_STRING
	mov loop_index, temp

send_info_loop:
	rcall eeprom_read
	rcall send_byte

	cpi temp_byte, 0
	breq send_info_loop_end

	dec loop_index
	breq send_info_loop_end

	ld temp, y+ ; incrementar y
	rjmp send_info_loop

send_info_loop_end:
	rjmp send_data_end

send_data_end:
    sei
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
    ; Vemos a qué corresponde este byte
    mov temp, bytes_restantes

    cpi temp, 2
    breq comando_move_to_byte_stepa

    cpi temp, 1
    breq comando_move_to_byte_stepb

    ; No deberíamos llegar acá
    rjmp rutina_comando_byte_move_to_end


comando_move_to_byte_stepa:
    ; Todavía falta stepb...
    mov stepa, byte_recibido
    dec bytes_restantes
    ldi estado_comando, WAIT_BYTE

    rjmp rutina_comando_byte_move_to_end


comando_move_to_byte_stepb:
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
    ldi estado_medicion, DELAY_MOVE_TO
    rcall start_timer0

    ; Ya podemos recibir nuevos comandos
    ldi estado_comando, WAIT_COMMAND

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
    ldi estado_comando, WAIT_BYTE

	rjmp rutina_comando_byte_scan_region_end

comando_byte_first_stepb:
	mov first_stepb, byte_recibido
    dec bytes_restantes
    ldi estado_comando, WAIT_BYTE

	rjmp rutina_comando_byte_scan_region_end

comando_byte_last_stepa:
	mov last_stepa, byte_recibido
    dec bytes_restantes
    ldi estado_comando, WAIT_BYTE

	rjmp rutina_comando_byte_scan_region_end

comando_byte_last_stepb:
    ; Ya tenemos todos los datos
	mov last_stepb, byte_recibido
	rcall start_scan

    ; Podemos recibir nuevos comandos
    ldi estado_comando, WAIT_COMMAND

	rjmp rutina_comando_byte_scan_region_end

rutina_comando_byte_scan_region_end:
    ret








rutina_comando_byte_write_info:
    ; Guardar al búffer
    st x+, byte_recibido
    ldi estado_comando, WAIT_BYTE

    ; Fijarse si es el null para terminar
    cpi byte_recibido, 0
    breq rutina_comando_byte_write_info_eeprom

    ; Fijarse si llegamos al límite de
    ; longitud del string
    dec bytes_restantes
    breq rutina_comando_byte_write_info_eeprom

    rjmp rutina_comando_byte_write_info_end
    
rutina_comando_byte_write_info_eeprom:
    ; Iniciar escritura de RAM a EEPROM
    ; Bloquea el programa
    rcall copiar_buffer_a_eeprom
    ldi estado_comando, WAIT_COMMAND

    ; Notificar escritura completa
    ldi data_type, WRITE_INFO_DONE
    rcall send_data

rutina_comando_byte_write_info_end:
    ret


; ------------------------------------------------------
;                RUTINAS DE COMANDOS
; ------------------------------------------------------

rutina_comando_abort:
    ; Nos quedamos donde estamos
    ldi estado_medicion, WAIT_MEDIR
    ldi estado_comando, WAIT_COMMAND

    ret


rutina_comando_ping:
    ; Ping - pong
    ldi data_type, PONG
    rcall send_data
	ldi estado_comando, WAIT_COMMAND

    ret


rutina_comando_ask_position:
    ; Devolvemos la posición
    ldi data_type, CURRENT_POSITION
    rcall send_data
	ldi estado_comando, WAIT_COMMAND

    ret


rutina_comando_ask_laser:
    ; Devolvemos el estado actual del láser
    sbis PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    sbic PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data
	ldi estado_comando, WAIT_COMMAND

    ret


rutina_comando_ask_state:
	ldi data_type, MEASURE_STATE
	rcall send_data
	ldi estado_comando, WAIT_COMMAND

	ret


rutina_comando_ask_info:
	ldi data_type, INFO
	rcall send_data
	ldi estado_comando, WAIT_COMMAND

	ret


rutina_comando_scan_row:
	mov first_stepa, zero
	ldi temp, MAX_STEPA
	mov last_stepa, temp

	mov first_stepb, stepb
	mov last_stepb, stepb

	rcall start_scan
    ldi estado_comando, WAIT_COMMAND

	ret


rutina_comando_scan_col:
	mov first_stepa, stepa
	mov last_stepa, stepa

	mov first_stepb, zero
	ldi temp, MAX_STEPB
	mov last_stepb, temp

	rcall start_scan
    ldi estado_comando, WAIT_COMMAND

	ret


rutina_comando_scan_all:
	mov first_stepa, zero
	ldi temp, MAX_STEPA
	mov last_stepa, temp

	mov first_stepb, zero
	ldi temp, MAX_STEPB
	mov last_stepb, temp

	rcall start_scan
    ldi estado_comando, WAIT_COMMAND

	ret


rutina_comando_scan_region:
    ; Necesitamos 4 bytes mas (first_stepa, first_stepb, last_stepa, last_stepb)
	ldi temp, 4
	mov bytes_restantes, temp
	ldi estado_comando, WAIT_BYTE

	ret


rutina_comando_move_to:
    ; Necesitamos 2 bytes mas (stepa, stepb)
	ldi temp, 2
	mov bytes_restantes, temp
    ldi estado_comando, WAIT_BYTE

    ret


rutina_comando_medir_dist:
    mov first_stepa, stepa
	mov last_stepa, stepa
    mov first_stepb, stepb
	mov last_stepb, stepb

    ; Apagar el laser
    cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data

	; Setear la distancia mínima en 0xFFFF
	clr min_disth
	dec min_disth

	clr min_distl
	dec min_distl

    ldi estado_medicion, MEDIR

    ldi estado_comando, WAIT_COMMAND

    ret


rutina_comando_turn_on_laser:
	; Encender láser y notificar cambio de estado
	sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data
	ldi estado_comando, WAIT_COMMAND

    ret


rutina_comando_turn_off_laser:
	; Apagar láser y notificar cambio de estado
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data
	ldi estado_comando, WAIT_COMMAND

    ret


rutina_comando_write_info:
    ldi temp, MAX_STRING
	mov bytes_restantes, temp
    ldx buffer
    ldi estado_comando, WAIT_BYTE

    ret

; ------------------------------------------------------
;                      START SCAN
; ------------------------------------------------------

start_scan:
	; Deben estar cargados los valores
    ; límite de stepa y stepb según sea el caso

	; Mover el servo A y B a la primer posición
	mov stepa, first_stepa
	mov stepb, first_stepb

	rcall actualizar_OCR1A
	rcall actualizar_OCR1B

    ; Apagar el laser
    cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data

    ; Notificar cambio de posición
	ldi data_type, CURRENT_POSITION
    rcall send_data

	; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado_medicion, DELAY_SCAN
    rcall start_timer0

	; Setear la distancia mínima en 0xFFFF
	clr min_disth
	dec min_disth

	clr min_distl
	dec min_distl

	ret


; ------------------------------------------------------
;                         EEPROM
; ------------------------------------------------------

copiar_buffer_a_eeprom:
    ldx buffer
    ldy INFO_ADDR
    ldi temp, MAX_STRING
    mov loop_index, temp

copiar_buffer_a_eeprom_loop:
    ld temp_byte, x+
    rcall eeprom_write
    ld temp, y+  ; Incrementar Y

    cpi temp_byte, 0
    breq copiar_buffer_a_eeprom_end

    dec loop_index
    breq copiar_buffer_a_eeprom_end

    rjmp copiar_buffer_a_eeprom_loop

copiar_buffer_a_eeprom_end:
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
    out EEARH, yh
    out EEARL, yl

    ; Data
    out EEDR, temp_byte

    ; Enable
    sbi EECR, EEMPE
    sbi EECR, EEPE

    ret


; Usa temp_byte y el puntero Y
; para la dirección
eeprom_read:
	; Esperar a una posible escritura en curso
	sbic EECR, EEPE
	rjmp eeprom_read

	; Address de lectura
	out EEARH, yh
	out EEARL, yl

	; Iniciar lectura
	sbi EECR, EERE

	; Byte leido
	in temp_byte, EEDR

	ret


; ------------------------------------------------------
;                  STEP UPS Y DOWNS
; ------------------------------------------------------

; Incrementa STEPA si es posible
stepa_up:
    cpi stepa, MAX_STEPA
    breq stepa_up_end

    inc stepa
    rcall actualizar_OCR1A

stepa_up_end:
    ret


; Decrementa STEPA si es posible
stepa_down:
    cpi stepa, 0
    breq stepa_down_end

    dec stepa
    rcall actualizar_OCR1A

stepa_down_end:
    ret


; Incrementa STEPB si es posible
stepb_up:
    cpi stepb, MAX_STEPB
    breq stepb_up_end

    inc stepb
    rcall actualizar_OCR1B

stepb_up_end:
    ret


; Decrementa STEPB si es posible
stepb_down:
    cpi stepb, 0
    breq stepb_down_end

    dec stepb
    rcall actualizar_OCR1B

stepb_down_end:
    ret


; ------------------------------------------------------
;                 MODIFICACIÓN DE OCR1X
; ------------------------------------------------------

; Las funciones step up, down lo hacen automáticamente
; Escribe en OCR1A = STEPA * STEP_OCR1A + MIN_OCR1A
actualizar_OCR1A:
	push r0
	push r1

    in temp, sreg
    push temp
    cli

    ; Multiplicación
    ldi temp, STEP_OCR1A
    mul stepa, temp

    ; Suma
    ldi xl, LOW(MIN_OCR1A)
    ldi xh, HIGH(MIN_OCR1A)
    add xl, r0
    adc xh, r1

    ; Guardado
    sts OCR1AH, xh
    sts OCR1AL, xl

    pop temp
    out sreg, temp

	pop r1
	pop r0
	 
    ret


; Las funciones step up, down lo hacen automáticamente
; Escribe en OCR1B = STEPB * STEP_OCR1B + MIN_OCR1B
actualizar_OCR1B:
	push r0
	push r1

    in temp, sreg
    push temp
    cli

    ldi temp, STEP_OCR1B
    mul stepb, temp

    ldi xl, LOW(MIN_OCR1B)
    ldi xh, HIGH(MIN_OCR1B)
    
    add xl, r0
    adc xh, r1

    sts OCR1BH, xh
    sts OCR1BL, xl

    pop temp
    out sreg, temp

	pop r1
	pop r0
    ret

; ------------------------------------------------------
;                       ARITMÉTICA
; ------------------------------------------------------


; Convierte los bytes lecturah:lectural a centimetros
; mediante una division
convertir_a_cm:
	
	; Divisor
	push r18
	push r19
	ldi r18, low(DIVISOR_CONVERSION)
	ldi r19, high(DIVISOR_CONVERSION)


	; Dividendo
	push r16
	push r17
    mov r16, lectural
	mov r17, lecturah

	rcall division_16bits

	; Cociente
	mov lectural, r16
	mov lecturah, r17

	pop r17
	pop r16
	pop r19
	pop r18

	ret


; Fijarse los registros que utiliza
division_16bits:
    ; Algoritmo basado en:
    ; https://www.microchip.com/en-us/application-notes?rv=1234aaef

    ; Resto
    push r14 ; Low
    push r15 ; High

    ; Cociente y Dividendo: r16 y r17

    ; Divisor: r18 y r19 (low, high)

    ; Contador auxiliar
    push r20

    ; Reiniciar resto y bit de carry
    clr	r14
	sub	r15, r15 ; Esto borra el carry
	ldi	r20, 17 ; El loop itera una vez por bit

division_16bits_1:
    ; Tomar el bit más significativo del dividendo
    ; y guardarlo en el carry
    rol	r16
	rol	r17
	
    ; Si ya recorrimos todos los bits terminamos
    dec	r20
	brne division_16bits_2
    rjmp division_16bits_end

division_16bits_2:
    ; Mover el bit guardado en el carry a la posición
    ; menos significativa del resto
    rol	r14
	rol	r15

    ; Vemos si podemos restar un divisor al resto
    ; actual
	sub	r14, r18
	sbc	r15, r19	

    ; Si no se puede, volvemos a dejar el resto como estaba
    ; Y ponemos un 0 en el resultado final (va al carry
    ; y luego al registro r16)
	brcc division_16bits_3
	add	r14, r18
	adc	r15, r19
	clc
	rjmp division_16bits_1

    ; Si se pudo restar, en el resultado guardarmos un 1.
division_16bits_3:
    sec
	rjmp division_16bits_1

division_16bits_end:
    pop r20
    pop r15
    pop r14
    ret

; Convierte la mindisth:mindistl (16 bits)
; a un string ASCII en RAM
convertir_lectura_ascii:
    ldx lectura_ascii

    ; Nibble más significativo 0x?...
    mov temp_byte, lecturah
    andi temp_byte, 0xF0
    swap temp_byte
    rcall convertir_byte_ascii
    st x+, temp_byte

    ; Nibble 0x.?..
    mov temp_byte, lecturah
    andi temp_byte, 0x0F
    rcall convertir_byte_ascii
    st x+, temp_byte

    ; Nibble 0x..?.
    mov temp_byte, lectural
    andi temp_byte, 0xF0
    swap temp_byte
    rcall convertir_byte_ascii
    st x+, temp_byte

    ; Nibble menos significativo 0x...?
    mov temp_byte, lectural
    andi temp_byte, 0x0F
    rcall convertir_byte_ascii
    st x+, temp_byte

    ret

; Convierte el byte en temp_byte a su dígito ASCII
convertir_byte_ascii:
    ; Para valores 0-9, sumar 0x30
    cpi temp_byte, 9
    brlo convertir_byte_sumar_30

    ; Sino, sumar 0x41 - 0x0A
    ldi temp, 0x41 - 0x0A
    add temp_byte, temp

    rjmp convertir_byte_ascii_end

convertir_byte_sumar_30:
    ldi temp, 0x30
    add temp_byte, temp
    
convertir_byte_ascii_end:
    ret
