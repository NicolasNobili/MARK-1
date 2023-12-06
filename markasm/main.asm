; ---------------------------------
; Trabajo_Integrador.asm
;
; Created: 11/11/2023 10:50:07 AM
; Authors: FR & NN
; ---------------------------------

.include "MARK1_include.asm"


; ------------------------------------------------------
;                    MEMORIA EEPROM
; ------------------------------------------------------
.eseg
.org INFO_ADDR

default_info:
    .db "Connected to MARK1: Multi Angle Radar Kinematics Mk.1", 0


; ------------------------------------------------------
;                   MEMORIA DE DATOS
; ------------------------------------------------------

.dseg
.org SRAM_START

buffer: .byte MAX_STRING
lectura_ascii: .byte 4  ; El máximo es FFFF


; ------------------------------------------------------
;                VECTOR DE INTERRUPCIONES
; ------------------------------------------------------

.cseg
.org 0x0000
    rjmp main
.org INT0addr
    rjmp handler_INT0
.org PCI2addr
	rjmp handler_PCI2
.org URXCaddr
    rjmp handler_URXC
.org OVF0addr
    rjmp handler_OVF0
.org OVF2addr
    rjmp handler_OVF2


; ------------------------------------------------------
;                  INICIALIZACION
; ------------------------------------------------------

.org INT_VECTORS_SIZE
main:
	; Stack pointer
	ldi temp, LOW(RAMEND)
	out spl, temp
	ldi temp, HIGH(RAMEND)
	out sph, temp
	
	clr zero
    ldi stepa, STEPA_INICIAL
    ldi stepb, STEPB_INICIAL
    ldi estado_medicion, WAIT_MEDIR
    ldi estado_comando, WAIT_COMMAND

	rcall config_ports
	rcall config_timer0
	rcall config_timer1
	rcall config_timer2
	rcall config_USART
	; rcall config_int0
    rcall config_pci0

	sbi PORTB, ACTIVE_LED

	ldi data_type, CURRENT_POSITION
	rcall send_data
	
	sbis PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    sbic PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

	ldi data_type, INFO
	rcall send_data
		
	sei
    

; ------------------------------------------------------
;                  LOOP PRINCIPAL
; ------------------------------------------------------

main_loop:
	
    ; Solo dormir si no hay ni comandos
    ; ni mediciones pendientes
	cpi estado_medicion, WAIT_MEDIR
	brne main_loop_accion_pendiente
    cpi estado_comando, WAIT_COMMAND
    breq main_sleep

main_loop_accion_pendiente:

    cpi estado_medicion, MEDIR
    breq main_iniciar_medicion

    cpi estado_comando, PROCESAR_BYTE
    breq main_procesar_byte

    cpi estado_comando, PROCESAR_COMANDO
    breq main_procesar_comando
	
	rjmp main_loop


; ------------------------------------------------------
;						SLEEP
; ------------------------------------------------------
    

main_sleep:
    cbi PORTB, ACTIVE_LED

    ; Modo Idle. Mantiene prendida la USART para despertarse
	ldi temp, (0 << SM2) | (0 << SM1) | (0 << SM0) | (1 << SE)
    out SMCR, temp 
	sleep
	out SMCR, zero

    sbi PORTB, ACTIVE_LED
	rjmp main_loop


; ------------------------------------------------------
;                  INICIAR MEDICION
; ------------------------------------------------------

main_iniciar_medicion:
    ; Esperamos que el ECHO haga una interrupción
    ; Mientras tanto no hay que hacer nada
    ldi estado_medicion, MIDIENDO
    rcall send_trigger

    rjmp main_loop


; ------------------------------------------------------
;                  PROCESAR BYTE
; ------------------------------------------------------

main_procesar_byte:
    ; Vemos para qué queríamos este byte
    cpi comando_recibido, MOVE_TO
    breq comando_byte_move_to

    cpi comando_recibido, SCAN_REGION
    breq comando_byte_scan_region

    cpi comando_recibido, WRITE_INFO
    breq comando_byte_write_info

    ; No deberíamos llegar acá
    rjmp main_loop

comando_byte_move_to:
    rcall rutina_comando_byte_move_to
    rjmp main_loop

comando_byte_scan_region:
    rcall rutina_comando_byte_scan_region
    rjmp main_loop

comando_byte_write_info:
    rcall rutina_comando_byte_write_info
    rjmp main_loop


; ------------------------------------------------------
;                 PROCESAR COMANDO
; ------------------------------------------------------

main_procesar_comando:
    ; La lectura de los siguientes comandos no modifican el estado
    ; de la medición (a excepción de ABORT) y se pueden realizar siempre

    cpi comando_recibido, ABORT
    breq comando_abort

    cpi comando_recibido, PING
    breq comando_ping

    cpi comando_recibido, ASK_POSITION
    breq comando_ask_position

    cpi comando_recibido, ASK_LASER
    breq comando_ask_laser

	cpi comando_recibido, ASK_STATE
	breq comando_ask_state

	cpi comando_recibido, ASK_INFO
	breq comando_ask_info

    ; Para otros comandos, primero verificamos
    ; Si no hay alguna medición en curso
    cpi estado_medicion, WAIT_MEDIR
    brne send_busy

    ; Leer comando

    cpi comando_recibido, SCAN_ROW
    breq comando_scan_row

	cpi comando_recibido, SCAN_COL
    breq comando_scan_col

	cpi comando_recibido, SCAN_ALL
    breq comando_scan_all

	cpi comando_recibido, SCAN_REGION
    breq comando_scan_region

    cpi comando_recibido, MOVE_TO
    breq comando_move_to

    cpi comando_recibido, MEDIR_DIST
    breq comando_medir_dist

    cpi comando_recibido, TURN_ON_LASER
    breq comando_turn_on_laser

    cpi comando_recibido, TURN_OFF_LASER
    breq comando_turn_off_laser

    cpi comando_recibido, WRITE_INFO
    breq comando_write_info

    ; Comando desconocido
    ldi data_type, WHAT
    rcall send_data
	ldi estado_comando, WAIT_COMMAND
    rjmp main_loop


send_busy:
    ldi data_type, BUSY
    rcall send_data
	ldi estado_comando, WAIT_COMMAND

    rjmp main_loop

comando_abort:
    rcall rutina_comando_abort
    rjmp main_loop

comando_ping:
	rcall rutina_comando_ping
    rjmp main_loop

comando_ask_position:
	rcall rutina_comando_ask_position
    rjmp main_loop

comando_ask_laser:
	rcall rutina_comando_ask_laser
    rjmp main_loop

comando_ask_state:
	rcall rutina_comando_ask_state
	rjmp main_loop

comando_ask_info:
	rcall rutina_comando_ask_info
	rjmp main_loop

comando_scan_row:
	rcall rutina_comando_scan_row
	rjmp main_loop

comando_scan_col:
	rcall rutina_comando_scan_col
	rjmp main_loop

comando_scan_all:
	rcall rutina_comando_scan_all
	rjmp main_loop

comando_scan_region:
	rcall rutina_comando_scan_region
	rjmp main_loop

comando_move_to:
	rcall rutina_comando_move_to
    rjmp main_loop

comando_medir_dist:
	rcall rutina_comando_medir_dist
    rjmp main_loop

comando_turn_on_laser:
	rcall rutina_comando_turn_on_laser
    rjmp main_loop

comando_turn_off_laser:
	rcall rutina_comando_turn_off_laser
    rjmp main_loop

comando_write_info:
    rcall rutina_comando_write_info
    rjmp main_loop

end_main:
    rjmp end_main


; ------------------------------------------------------
;                 RUTINAS Y HANDLERS
; ------------------------------------------------------

.include "MARK1_config.asm"
.include "MARK1_handlers.asm"
.include "MARK1_rutina.asm"
