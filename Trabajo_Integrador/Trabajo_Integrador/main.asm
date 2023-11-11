;
; Trabajo_Integrador.asm
;
; Created: 11/11/2023 10:50:07 AM
; Author : FR & NN
;

.include "MARK1_include.asm"

;VARIABLES:
.dseg
.org SRAM_START

;CODIGO:
.cseg
.org 0x0000
rjmp main

.org INT_VECTORS_SIZE

main:
	;inicializo stack pointer
	ldi r16,LOW(RAMEND)
	out spl,r16
	ldi r16,HIGH(RAMEND)
	out sph,r16
	
	rcall config_ports
	rcall config_timer0
	rcall config_timer1
	rcall config_USART
	
	sei

main_loop:
	
	rjmp main_loop


end_main: rjmp end_main


.include "MARK1_config.asm"
.include "MARK1_handlers.asm"