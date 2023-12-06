.def min_distl = r21
.def min_disth = r22
.def temp = r16
.def temp_byte = r17

.macro ldx
	ldi XL, LOW(@0)
	ldi XH, HIGH(@0)
.endmacro

.macro ldy
	ldi YL, LOW(@0)
	ldi YH, HIGH(@0)
.endmacro

.macro ldz
	ldi ZL, LOW(@0)
	ldi ZH, HIGH(@0)
.endmacro

.dseg
.org SRAM_START
lectura_ascii: .byte 4

.cseg

.org 0x0000
rjmp main

main:
    ldi r16, high(RAMEND)
    out sph, r16
    ldi r16, low(RAMEND)
    out spl, r16

    ; Dividend
    ldi min_disth, high(0x12AB)
    ldi min_distl, low(0x12AB)

    rcall convertir_lectura_ascii

end:
    rjmp end

; Convierte la mindisth:mindistl (16 bits)
; a un string ASCII en RAM
convertir_lectura_ascii:
    ldx lectura_ascii

    ; Nibble más significativo 0x?...
    mov temp_byte, min_disth
    andi temp_byte, 0xF0
    swap temp_byte
    rcall convertir_byte_ascii
    st x+, temp_byte

    ; Nibble 0x.?..
    mov temp_byte, min_disth
    andi temp_byte, 0x0F
    rcall convertir_byte_ascii
    st x+, temp_byte

    ; Nibble 0x..?.
    mov temp_byte, min_distl
    andi temp_byte, 0xF0
    swap temp_byte
    rcall convertir_byte_ascii
    st x+, temp_byte

    ; Nibble menos significativo 0x...?
    mov temp_byte, min_distl
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



































.equ GO_TO_SLEEP               = 0x00
.equ SCANNING                  = 0x01
.equ PRENDER_LASER             = 0x02
.equ APAGAR_LASER              = 0x03
.equ SINGLE_MEASURE            = 0x04
.equ WAITING_BYTES_MOVE_TO     = 0x05
.equ WAITING_BYTES_SCAN_REGION = 0x06
.equ WAITING_BYTES_WRITE_INFO  = 0x07















comando_byte_move_to:
    ; Vemos a qu? corresponde este byte
    mov temp, bytes_restantes

    cpi temp, 2
    breq comando_byte_stepa

    cpi temp, 1
    breq comando_byte_stepb

    ; No deber?amos llegar ac?
    rjmp main_loop

comando_byte_stepa:
    ; Todav?a falta stepb...
    mov stepa, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

    rjmp main_loop

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

    rjmp main_loop

comando_byte_scan_region:
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

	rjmp main_loop

comando_byte_first_stepb:
	mov first_stepb, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

	rjmp main_loop

comando_byte_last_stepa:
	mov last_stepa, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

	rjmp main_loop

comando_byte_last_stepb:
	mov last_stepb, byte_recibido
	rcall start_scan
	rjmp main_loop

comando_byte_write_info:
    ; Guardar al búffer
    st x+, byte_recibido

    ; Fijarse si es el null para terminar
    cpi byte_recibido, 0
    breq comando_byte_write_info_end

    rjmp main_loop
    
comando_byte_write_info_end:
    ; Iniciar escritura de RAM a EEPROM
    ; Bloquea el programa
    rcall copiar_buffer_a_eeprom
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND
    ldi data_type, WRITE_INFO_DONE
    rcall send_data

    rjmp main_loop










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

/* comando_scan_row:
    ; Mover el servo A al m?nimo
    ldi stepa, 0
    rcall actualizar_OCR1A

    ; Notificar del cambio de posici?n
    ldi data_type, CURRENT_POSITION
    rcall send_data

    ; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0

    ; Setear la distancia m?nima en 0xFF
	clr min_dist
	dec min_dist

    ; Actualizar objetivo
    ldi objetivo, SCANNING_ROW

	rjmp main_loop */