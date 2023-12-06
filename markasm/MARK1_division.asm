.def lectural = r21
.def lecturah = r22
.equ DIVISOR_CONVERSION = 30

.cseg

.org 0x0000
rjmp main

main:
    ldi r16, high(RAMEND)
    out sph, r16
    ldi r16, low(RAMEND)
    out spl, r16

    ; Dividend
    ldi lecturah, high(200)
    ldi lectural, low(200)

    rcall convertir_a_cm

end:
    rjmp end


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
