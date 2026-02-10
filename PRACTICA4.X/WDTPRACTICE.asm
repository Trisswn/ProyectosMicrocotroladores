PROCESSOR   16F877A
    #include    <xc.inc>

        CONFIG  FOSC = XT        ; Oscilador XT (4 MHz)
        CONFIG  WDTE = ON        ; Watchdog Timer habilitado
        CONFIG  PWRTE = OFF      ; Power-up Timer deshabilitado
	CONFIG  BOREN = ON
        CONFIG  CPD = OFF        ; Protección de código deshabilitada
	CONFIG  LVP = OFF        ; Low Voltage Programming OFF	
        CONFIG  WRT = OFF
        CONFIG  CP = OFF


        PSECT   Code, delta=2
   
; VARIABLES --------------------------------------------------------------
   
    CONTADOR    EQU	    0X20

; PROGRAMA ---------------------------------------------------------------
    
    org     0x00
    goto    INICIO

    org     0x04
    goto    ISR	
	
INICIO:
    
    bsf     STATUS,     5	    
    bcf	    STATUS,	6	    ; Cambiar al banco 1
    
    bsf	    OPTION_REG,	3	    ; Prescaler asignado al WDT
	
    bsf	    OPTION_REG,	2
    bsf	    OPTION_REG,	1
    bsf	    OPTION_REG,	0	    ; Prescaler en 1:128
	
    movlw   0x06		    ; 0x06 configura todos los pines como Digitales
    movwf   ADCON1		    ; Escribimos en el registro ADCON1 (está en Banco 1)
	
    movlw   0b00000110
    movwf   TRISA		    ; Configurar RA1 y RA2 como entradas
    
    clrf    TRISB		    ; Configurar PORTB como salida
    
    bcf     STATUS,     5	    ; Regresar al banco 0
    clrf    PORTB		    ; Limpiar PORTB
	
BUCLE:
    
    btfsc   PORTA,	1	    ; Revisa si RA1 está en 0
    goto    APAGAR		    ; Si RA1 es 1 va a APAGAR
    
    btfsc   PORTA,      2	    ; Revisa si RA2 está en 0
    goto    APAGAR		    ; Si RA2 es 1 va a APAGAR

ENCENDER:
    
    movlw   0b00000011
    movwf   PORTB		    ; Encender LEDs en RB0 y RB1
    goto    DORMIR
    
APAGAR:
    
    clrf    PORTB		    ; Limpiar PORTB
    
DORMIR:
    
    movlw   3			    ; Número de ciclos por dormir
    movwf   CONTADOR		    ; Mover a la variable contador
    
CICLOS_WDT:
    
    clrwdt			    ; Limpiar el WDT
    sleep			    ; Dormir
    nop
    
    decfsz  CONTADOR,	f	    ; Decrementa en 1 al contador de ciclos
    goto    CICLOS_WDT		    ; Si el contador aún no llega a 0, vuelve a dormir
    clrf    CONTADOR		    ; Si el contador llega a 3, limpiamos y regresamos al bucle
    
    goto    BUCLE		    ; Regresar al bucle para revisar pines
    
    end