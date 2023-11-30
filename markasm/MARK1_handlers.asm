; ---------------------------------
; MARK1_handlers.asm
;
; Created: 11/11/2023 11:54:04 AM
; Authors: FR & NN
; ---------------------------------


; ------------------------------------------------------
;                   OVERFLOW TIMER 0
; ------------------------------------------------------

; Timer 0 solo se prende al iniciar comandos
; de MOVE TO o de ESCANEO.
handler_OVF0:
    in temp, sreg
    push temp

    ; Verificar si debemos seguir esperando
    dec left_ovfs
    brne handler_OVF0_end

    ; Una vez que ya no hay más espera, apagar
    ; timer 0 y ver qué sigue hacer
    rcall stop_timer0

    ; Solo deberíamos estar acá
    ; si se inició un delay

    cpi estado_medicion, DELAY_SCAN
    breq objetivo_scanning

    cpi estado_medicion, DELAY_LASER
    breq objetivo_laser

    cpi estado_medicion, DELAY_MOVE_TO
    breq objetivo_move_to

    ; Otro estado que no sea delay
    ; (no deberíamos estar acá)
    ldi estado_medicion, WAIT_MEDIR
    rjmp handler_OVF0_end

objetivo_scanning:
    ldi estado_medicion, MEDIR

    rjmp handler_OVF0_end

objetivo_laser:
    sbis PORTD, LASER_PIN
    rjmp objetivo_prender_laser
    rjmp objetivo_apagar_laser

objetivo_prender_laser:
    ; Si el láser está apagado, apenas
    ; terminamos el scan y lo debemos prender
    sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

    cp first_stepa, last_stepa
    brne objetivo_prender_laser_delay_scan
    cp first_stepb, last_stepb
    brne objetivo_prender_laser_delay_scan

objetivo_prender_laser_delay_single_measure:
    ldi left_ovfs, DELAY_SINGLE_MEASURE
    rjmp objetivo_prender_laser_timer0

objetivo_prender_laser_delay_scan:
    ldi left_ovfs, DELAY_DURACION_LASER

objetivo_prender_laser_timer0:
    rcall start_timer0

    rjmp handler_OVF0_end

objetivo_apagar_laser:
    cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data

    ldi estado_medicion, WAIT_MEDIR

    rjmp handler_OVF0_end

objetivo_move_to:
    ; MOVE_TO no pide nada más,
    ; llegamos al destino :)
    ldi estado_medicion, WAIT_MEDIR

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
    cpi estado_comando, WAIT_BYTE
    breq handler_URXC_byte_extra_recibido

    ; Ver si estamos ya procesando otro comando
    cpi estado_comando, WAIT_COMMAND
    breq handler_URXC_comando_recibido

    ; Si no, estamos procesando algo
    ; Se descarta el byte (notificamos
    ; que estamos ocupados)
    ldi data_type, BUSY
    rcall send_data

    rjmp handler_URXC_end

handler_URXC_comando_recibido:
    ; Interpretamos como un comando
    ; o inicio de comando en sí
    mov comando_recibido, byte_recibido
    ldi estado_comando, PROCESAR_COMANDO
    rjmp handler_URXC_end

handler_URXC_byte_extra_recibido:
    ldi estado_comando, PROCESAR_BYTE
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

handler_INT0_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;           INTERRUPCIÓN PIN CHANGE 0 (ECHO)
; ------------------------------------------------------

handler_PCI2:
	in temp,sreg
	push temp

    ; Determinar en qué flanco estamos
	sbic PIND, ULTRASOUND_ECHO
	rjmp start_measure

process_measure:
    ; Flanco descendiente, termina la lectura
	rcall stop_timer2

	;Desactivar interrupcion PCI2
	lds temp, PCICR
	andi temp, ~(1<<PCIE2)
	sts PCICR, temp

	; Lectura de medición
	lds lectural, TCNT2

    ; Comparar con mínimo:

    ; Caso fácil: la distancia mínima
    ; tiene byte alto menor a lecturah
    ; No intercambiamos
	cp min_disth, lecturah
	brlo send_measure
	
    ; Caso fácil: la distancia mínima
    ; tiene byte alto mayor a lecturah
    ; Intercambiamos
	cp lecturah, min_disth
	brlo actualizar_minimo

    ; En este caso, los bytes altos
    ; son iguales, así que comparamos
    ; en base al byte low.
	cp lectural, min_distl
	brlo actualizar_minimo

    ; No hay intercambio.
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

continuar_scan_stepa:
    ; Vemos si podemos seguir avanzando
    ; Si no, debemos modificar stepb.
    cp stepa, last_stepa
    breq continuar_scan_stepb

    ; Podemos seguir, ver en qúe dirección
    ; corresponde.
	cp first_stepa, last_stepa
	brlo continuar_scan_stepa_derecha

continuar_scan_stepa_izquierda:
	rcall stepa_down
	rjmp continuar_scan_stepa_delay

continuar_scan_stepa_derecha:
    rcall stepa_up

continuar_scan_stepa_delay:
    ; Actualizar posición, dar delay también
    ldi estado_medicion, DELAY_SCAN
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0
	
	ldi data_type, CURRENT_POSITION
	rcall send_data

    rjmp handler_PCI0_end

continuar_scan_stepb:
	; Vemos si podemos seguir avanzando
	; Se llega a acá despues de haber
    ; escaneado la fila
    ; [first_stepa : last_stepa , stepb]
    cp stepb, last_stepb
	breq terminar_scanning
	
	; Permutamos first_stepa con last_stepa
    ; para cambiar la direccion del
    ; movimiento horizontal
    mov temp, last_stepa
	mov last_stepa, first_stepa
	mov first_stepa, temp

	; Podemos seguir, dar tiempo
    ; para moverse a la siguiente posición
	rcall stepb_up
    ldi estado_medicion, DELAY_SCAN
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0
	
	ldi data_type, CURRENT_POSITION
	rcall send_data

	rjmp handler_PCI0_end

terminar_scanning:
    cp first_stepa, last_stepa
    brne terminar_scanning_multiple_measure
    cp first_stepb, last_stepb
    brne terminar_scanning_multiple_measure

terminar_scanning_single_measure:
    ldi left_ovfs, DELAY_SINGLE_MEASURE
    ldi estado_medicion, DELAY_LASER
    rcall start_timer0

    rjmp handler_PCI0_end

terminar_scanning_multiple_measure:
    ; No podemos seguir avanzando, vamos
    ; a apuntar al mínimo que encontramos
    mov stepa, min_stepa
    rcall actualizar_OCR1A
    mov stepb, min_stepb
    rcall actualizar_OCR1B
    
    ; Enviamos el cambio de posición
    ldi data_type, CURRENT_POSITION
    rcall send_data
    
    ; Ahora queremos prenderle un láser,
    ; después de habernos movido ahí
    ; (el handler de timer 0 lo hace)
    ldi estado_medicion, DELAY_LASER
    ldi left_ovfs, DELAY_MOVIMIENTO
    rcall start_timer0

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
	out sreg, temp
	reti
