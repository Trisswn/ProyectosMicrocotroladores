PROCESSOR   16F877A
        #include    <xc.inc>

        CONFIG  FOSC = XT        ; Oscilador XT (4 MHz)
        CONFIG  WDTE = OFF       ; Watchdog Timer deshabilitado
        CONFIG  PWRTE = OFF      ; Power-up Timer deshabilitado
        CONFIG  CP = OFF         ; Protección de código deshabilitada
	CONFIG  LVP = OFF        ; Low Voltage Programming OFF 


        PSECT   Code, delta=2

        org     0x00
        goto    INICIO

        org     0x05
	
INICIO:
	bsf     STATUS,     5	    
	bcf	STATUS,	    6	    ; Cambiar al banco 1
	
	movlw   0x06		    ; 0x06 configura todos los pines como Digitales
	movwf   ADCON1		    ; Escribimos en el registro ADCON1 (está en Banco 1)
	
	movlw   0b00000110
	movwf   TRISA		    ; Configurar RA1 y RA2 como entradas
    
	clrf    TRISB		    ; Configurar PORTB como salida
    
	bcf     STATUS,     5	    ; Regresar al banco 0
	clrf	PORTB		    ; Limpiar PORTB
	
BUCLE:
    
	btfsc   PORTA,	    1	    ; Revisa si RA1 está en 0
	goto    APAGAR		    ; Si RA1 es 1 va a APAGAR
    
	btfsc   PORTA,	    2	    ; Revisa si RA2 está en 0
	goto    APAGAR		    ; Si RA2 es 1 va a APAGAR

ENCENDER:
    
	movlw   0b00000011
	movwf   PORTB		    ; Encender LEDs en RB0 y RB1
	goto    BUCLE
    
APAGAR:
	clrf	PORTB		    ; Limpiar PORTB
	goto    BUCLE

        end
	


