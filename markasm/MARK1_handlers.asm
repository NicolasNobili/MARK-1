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

    ; Una vez que ya no hay más espera, apagar
    ; timer 0 y ver qué sigue hacer
    rcall stop_timer0

    cpi objetivo, SCANNING
    breq objetivo_scanning

	cpi objetivo, PRENDER_LASER
    breq objetivo_prender_laser

	cpi objetivo, APAGAR_LASER
    breq objetivo_apagar_laser

    ; Otro objetivo
    ldi estado, IDLE
    rjmp handler_OVF0_end

objetivo_scanning:
    rcall stop_timer0

    ; Solicitamos una medición (al main loop)
    ldi estado, MEDIR

    rjmp handler_OVF0_end

objetivo_prender_laser:
    ; Es necesario?
	rcall stop_timer0

    ; Encender láser y notificar cambio de estado
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
    ; Se terminó la fiesta
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data
	ldi data_type, SCAN_DONE
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
	
	inc lecturah

handler_OVF2_end:
	pop temp
	out sreg,temp
	reti


; ------------------------------------------------------
;                  COMUNICACIÓN SERIAL
; ------------------------------------------------------

; Recepción de comandos
handler_URXC:
    in temp, sreg
    push temp

    ; Leer caracter
    lds byte_recibido, UDR0

    ; Ver si esto es un byte extra de un comando
    cpi estado, WAIT_BYTE
    breq byte_extra_recibido

    ; Interpretamos como un comando o inicio de comando en sí
    ldi estado, PROCESAR_COMANDO
    rjmp handler_URXC_end

byte_extra_recibido:
    ldi estado, PROCESAR_BYTE
    rjmp handler_URXC_end

handler_URXC_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;           INTERRUPCIÓN INT0 PARA DEBUGEAR
; ------------------------------------------------------

handler_INT0:
    in temp, sreg
    push temp

    ; Falta implementar la medición de tiempo

    ; Mandar información por USART (stepa, stepb, medicion)

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
;           INTERRUPCIÓN PIN CHANGE 0 (ECHO)
; ------------------------------------------------------

handler_PCIO:
	in temp,sreg
	push temp

    ; Determinar en qué flanco estamos
	sbic PINB, ULTRASOUND_ECHO
	rjmp start_measure

process_measure:
    ; Flanco descendiente, termina la lectura
	rcall stop_timer2

	;Desactivar interrupcion PCI0
	lds temp,PCICR
	andi temp,~(1<<PCIE0)
	sts PCICR,temp

	;Lectura de medicion
	lds lectural, TCNT2

	
    ; Comparar con mínimo
	cp min_disth, lecturah
	brlo send_measure
	
	cp lecturah, min_disth
	brlo actualizar_minimo

	cp lectural, min_distl
	brlo actualizar_minimo

	rjmp send_measure
	
actualizar_minimo:
    ; Reemplazar mínimo
	mov min_distl, lectural
	mov min_disth, lecturah
	mov min_stepa, stepa
	mov min_stepb, stepb

send_measure:
    ; Mandar info al serial
    ldi data_type, MEASUREMENT
	rcall send_data

    ; Cómo seguimos depende del objetivo actual

	cpi objetivo, SINGLE_MEASURE
	breq terminar_single_measure
    
    cpi objetivo, SCANNING
    breq continuar_scanning

    ; No debería llegar acá
    rjmp handler_PCI0_end

continuar_scanning:

continuar_scan_stepa:
    ; Vemos si podemos seguir avanzando
    cp stepa, last_stepa
    breq continuar_scan_stepb

    ; Podemos seguir, dar tiempo
    ; para moverse a la siguiente posición

	cp first_stepa,last_stepa
	brlo continuar_scan_stepa_derecha

continuar_scan_stepa_izquierda:
	rcall stepa_down
	rjmp continuar_scan_stepa_delay

continuar_scan_stepa_derecha:
    rcall stepa_up

continuar_scan_stepa_delay:

    ldi estado, DELAY
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0
	
	ldi data_type, CURRENT_POSITION
	rcall send_data

    rjmp handler_PCI0_end

continuar_scan_stepb:
	; Vemos si podemos seguir avanzando
	; Se llega a aca despues de haber escaneado la fila [first_stepa : last_stepa , stepb]
    cp stepb, last_stepb
	breq terminar_scanning
	
	mov temp, last_stepa

	;Permutamos first_stepa con last_stepa para cambiar la direccion del movimiento horizontal
	mov last_stepa, first_stepa
	mov first_stepa, temp

	; Podemos seguir, dar tiempo
    ; para moverse a la siguiente posición
	rcall stepb_up
    ldi estado, DELAY
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0
	
	ldi data_type, CURRENT_POSITION
	rcall send_data

	rjmp handler_PCI0_end


terminar_scanning:
    ; No podemos seguir avanzando, vamos
    ; a apuntar al mínimo que encontramos
    mov stepa, min_stepa
    rcall actualizar_OCR1A
    mov stepb, min_stepb
    rcall actualizar_OCR1B
    
    ; Enviamos el cambio de posición
    ldi data_type, CURRENT_POSITION
    rcall send_data
    
    ; Ahora queremos prenderle un laser,
    ; después de habernos movido ahí
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
    ; Flanco ascendente, recién comienza la lectura
    ; Iniciar el timer 2 (más el bit extra por overflows)
	clr lecturah
	clr lectural
	rcall start_timer2
    rjmp handler_PCI0_end

handler_PCI0_end:
	pop temp
	out sreg,temp
	reti
