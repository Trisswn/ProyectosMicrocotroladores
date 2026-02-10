PROCESSOR   16F877A
        #include    <xc.inc>

        CONFIG  FOSC = XT        ; Oscilador XT (4 MHz)
        CONFIG  WDTE = OFF       ; Watchdog Timer deshabilitado
        CONFIG  PWRTE = OFF      ; Power-up Timer deshabilitado
        CONFIG  CP = OFF         ; Protección de código deshabilitada
        CONFIG  LVP = OFF        ; Low Power Programming OFF

        PSECT   Code, delta=2

        org     0x00
        goto    INICIO

        org     0x04

        ; Variables
        ADDR_L  EQU  0X020
        DATA_L  EQU  0x021

INICIO:
        movlw   0x00
        movwf   ADDR_L          ; Cargar la dirección 00h
        movlw   0x027
        movwf   DATA_L          ; Cargar valor 27h

ESCRIBIR_EEPROM:
        
        bsf     STATUS, 6
        bcf     STATUS, 5       ; Cambiar al banco 2

        bcf     STATUS, 6	; Regreso breve a Banco 0 para leer ADDR_L
	movf    ADDR_L, W
	bsf     STATUS, 6	; Regreso a Banco 2
	movwf   EEADR		; Pasarlo al registro de dirección

        bcf     STATUS, 6	; Regreso breve a Banco 0 para leer DATA_L
	movf    DATA_L, W
	bsf     STATUS, 6	; Regreso a Banco 2
	movwf   EEDATA		; Pasarlo al registro de datos
	
        bsf     STATUS, 5       ; Cambiar a banco 3
        bcf     EECON1, 7       ; Seleccionar memoria EEPROM 
        bsf     EECON1, 2	; Habilitar escritura

        ; Secuencia requerida
	
        bcf     INTCON, 7	; Deshabilitar interrupciones
        movlw   0x55
        movwf   EECON2          ; Primer paso de desbloqueo
        movlw   0xAA
        movwf   EECON2          ; Segundo paso de desbloqueo
        bsf     EECON1, 1       ; Iniciar escritura física
	
ESPERA_EEPROM:
        btfsc EECON1, 1
	goto ESPERA_EEPROM

        bsf     INTCON, 7       ; Habilitar interrupciones de nuevo
        
       
        bcf     EECON1, 2	; Deshabilitar escritura para protección
        bcf     STATUS, 6
        bcf     STATUS, 5       ; Cambiar al banco 0
        bcf     PIR2,	4

FIN:
        goto    FIN
        
        end


