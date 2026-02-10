PROCESSOR   16F84A
        #include    <xc.inc>

        CONFIG  FOSC = XT        ; Oscilador XT (4 MHz)
        CONFIG  WDTE = OFF       ; Watchdog Timer deshabilitado
        CONFIG  PWRTE = OFF      ; Power-up Timer deshabilitado
        CONFIG  CP = OFF         ; Protección de código deshabilitada


        PSECT   Code, delta=2

        org     0x00
        goto    INICIO

        org     0x05

INICIO:
    
	bsf	STATUS,	5	; Cambiar al banco 1
	
	movlw	0b00000110
	movwf	TRISA		; Configurar RA1 y RA2 como entradas
	
	clrf	TRISB		; Configurar PORTB como salida
	
	bcf	STATUS,	5	; Regresar al banco 0
	
BUCLE:
    
	btfsc	PORTA,	1	; Revisa si RA1 está en 0, si lo está, salta la siguiente instrucción
	goto	APAGAR		; Si RA1 es 1 entonces va a la rutina APAGAR
	
	btfsc	PORTA,	2	; Revisa si RA2 está en 0, si lo está, salta la siguiente instrucción
	goto	APAGAR		; Si RA2 es 1 entonces va a la rutina APAGAR

ENCENDER:
    
	movlw	0b00000011
	movwf	PORTB		; Encender LEDs en RB0 y RB1
	goto	BUCLE
	
APAGAR:
	clrf	PORTB		; Limpiar PORTB
	goto	BUCLE

        end


