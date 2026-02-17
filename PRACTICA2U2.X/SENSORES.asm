PROCESSOR   16F877A
    #include    <xc.inc>

    CONFIG  FOSC = XT           
    CONFIG  WDTE = OFF         
    CONFIG  PWRTE = ON        
    CONFIG  BOREN = OFF      
    CONFIG  CPD = OFF        
    CONFIG  LVP = OFF      
    CONFIG  WRT = OFF
    CONFIG  CP = OFF

    PSECT   Code, delta=2

; VARIABLES ------------------------------

   ; LCD
    RS		    EQU	    0		        ; Register Select (RA0)
    RW		    EQU	    1			; Read/Write (RA1)
    E		    EQU	    2			; Enable (RA2)
		
   ; MEMORIA
    CONT_SEGUNDOS   EQU	    0x20
    RETARDO_CONT    EQU	    0x21
    MULTI_H	    EQU	    0x22
    MULTI_L	    EQU	    0x23		; Escala del multiplicador
    DATOA_H	    EQU	    0x24		; Para guardad ADRES H y L
    DATOA_L	    EQU	    0x25
    RESULTADO_H	    EQU	    0x26		; Para guardar el resultado
    RESULTADO_L	    EQU	    0x27
    COPIA_H	    EQU	    0x28		; Copias para desplazar
    COPIA_L	    EQU	    0x29   
    CONTADOR	    EQU	    0x2A		; Contador de 16 vueltas
    DECENAS	    EQU	    0x2B
    UNIDADES	    EQU	    0x2C
    DECIMAS	    EQU	    0x2D		; Para la conversión BCD
    AUX_BCD_H	    EQU	    0x2E
    AUX_BCD_L	    EQU	    0x2F		; Ayudan en la conversion
    TEMP_MAX	    EQU	    50
    TEMP_MIN	    EQU	    32
	    
; PROGRAMA -------------------------------

    org         0x00
    goto        INICIO

INICIO:
    
    bsf		STATUS,	5
    bcf		STATUS,	6			; Cambiar al banco 1
    
    movlw	0b00000110			
    movwf	ADCON1				; PORTA digital
    clrf	TRISA				; PORTA como salida
    clrf	TRISB				; PORTB como salida
    clrf	TRISC				; PORTC como salida
    
    movlw	0b10000111
    movwf	OPTION_REG			; TIMER0 1:256
    
    bcf		STATUS,	5			; Regresar a banco 0
    clrf	PORTA
    clrf	PORTB
    clrf	PORTC				; Limpieza inicial de puertos
    
    call	LCD_INIT			; Inicializar LCD

BUCLE:
    
    call	RETARDO_1S			; 1 segundo entre cada captura
    
    bsf		STATUS,	5			; Ir a banco 1
    movlw	0b00101000			
    movwf	TRISA				; RA3 Y RA5 como entradas
    
    movlw	0b10001011
    movwf	ADCON1				; Justificación hacia la derecha, RA3 = VREF+ , RA5 = analógica
    bcf		STATUS,	5			; Regresar a banco 0
    
    movlw	0b10100001
    movwf	ADCON0				; FOSC/32, Convertidor A/D = ON
    
    call	RETARDO_1S
    bsf		ADCON0,	2			; GO = 1 inicia la conversión A/D
    
ADC_ESPERA:
    
    btfsc	ADCON0,	2			; Espera hasta que termine la conversión (GO = 0)
    goto	ADC_ESPERA			; LA CONVERSION SE GUARDA EN ADRESL Y ADRESH
    
    bsf		STATUS,	5			; Cambiar a banco 1 para leer ADRESL
    movf	ADRESL,	w
    bcf		STATUS,	5			; Regresar a banco 0
    
    movwf	DATOA_L				; Guardar parte baja
    movf	ADRESH,	w
    movwf	DATOA_H				; Guardar parte alta
    
    movlw	243				; Multiplicar ADC * 243
    movwf	MULTI_L
    clrf	MULTI_H				; Cargar el multiplicador
    
    call	MULTI
    call	CONV_BCD
    
; Comparaciones
    swapf	DECENAS, w			; ponemos el valor en la parte alta
    andlw	0XF0				; Asegura que la parte baja esté en 0000
    movwf	CONTADOR
    movf	UNIDADES, w
    andlw	0x0F
    iorwf	CONTADOR, f			; Ahora contador tiene decenas y unidades en el mismo registro
    
    movlw	TEMP_MAX
    subwf	CONTADOR, w			; restamos 50 a contador
    btfsc	STATUS,	  0			; es igual a 0?
    goto	MOTOR
    bcf		PORTC,	  2			; Apagar motor
    goto	CHECAR_MIN
    
MOTOR:
    
    bsf		PORTC,	  2			; Encender motor

CHECAR_MIN:
    
    movlw	TEMP_MIN
    subwf	CONTADOR, w
    btfss	STATUS,	  0
    goto	RELE
    bcf		PORTC,	  0			; Apagar rele
    goto	IMPRIMIR_LCD

RELE:
    bsf		PORTC,	  0			; Encender rele
    
IMPRIMIR_LCD:
    
    bsf		STATUS,	    5			; Ir a banco 1
    movlw	0b00000110	    
    movwf	ADCON1				; PORTA digital
    bcf		STATUS,	    5			; Regresar al banco 0
    
    call	LCD_CLEAR			; Limpiar LCD
    call	LCD_HOME			; Poner cursor al inicio
    movlw	'T'
    call	LCD_CHAR
    movlw	'E'
    call	LCD_CHAR   
    movlw	'M'
    call	LCD_CHAR    
    movlw	'P'
    call	LCD_CHAR
    movlw	':'
    call	LCD_CHAR
    movlw	' '
    call	LCD_CHAR
    
    movf	DECENAS,    w
    call	LCD_DIGITO
    movf	UNIDADES,   w
    call	LCD_DIGITO
    movlw	'.'
    call	LCD_CHAR
    movf	DECIMAS,    w
    andlw	0x0F
    call	LCD_DIGITO
    goto	BUCLE

; SUBRUTINAS PARA MULTIPLICACIÓN ---------
    
MULTI:
    
    clrf	RESULTADO_H
    clrf	RESULTADO_L			; Limpiar el resultado
    movlw	16
    movwf	CONTADOR			; 16 ciclos
    
    movf	DATOA_H,    w
    movwf	COPIA_H				; Copiamos para no perder el valor original
    movf	DATOA_L,    w
    movwf	COPIA_L

MULTI_CICLOS:
    bcf		STATUS,	    0			; Limpiamos el carry
    rrf		MULTI_H,    f
    rrf		MULTI_L,    f			; Rotamos a la derecha, el último bit va al carry
    
    btfss	STATUS,	    0
    goto	MULTI_SIGUIENTE			; Si fue 1, vamos sumando 
    
    movf	COPIA_L,    w			; Carga la parte baja de la copia
    addwf	RESULTADO_L, f			; Lo suma al resultado acumulado
    
    btfsc	STATUS,	    0			; Si ocurrió carry incrementa resultado_h
    incf	RESULTADO_H, f
    movf	COPIA_H,    w			; Carga la parte alta de la copia
    addwf	RESULTADO_H, f			; Lo suma al resultado acumulado
    
MULTI_SIGUIENTE:
    bcf		STATUS,	    0			; Limpiar carry
    rlf		COPIA_L,    f			; Rotar a la izquierda parte baja y alta
    rlf		COPIA_H,    f
    
    decfsz	CONTADOR,   f
    goto	MULTI_CICLOS
    return
    
; SUBRUTINAS PARA CONVERSIÓN BCD ---------
    
CONV_BCD:
    clrf	DECENAS
    clrf	UNIDADES
    clrf	DECIMAS
    
    movf	RESULTADO_H, w
    movwf	AUX_BCD_H
    movf	RESULTADO_L, w
    movwf	AUX_BCD_L

BCD_DEC:
    movlw	low(1000)
    subwf	AUX_BCD_L,  w			; w = aux_l - low(1000)
    movwf	RETARDO_CONT
    movlw	high(1000)
    btfss	STATUS,	    0			; ¿Hubo préstamo?
    addlw	1
    subwf	AUX_BCD_H, w			; W = H - 1000_high
    
    btfss	STATUS, 0			; ¿Resultado negativo? (C=0 es negativo en resta)
    goto	BCD_UNI				; Si es negativo, terminamos decenas
    
						; Si es positivo, guardamos la resta y sumamos 1 a decenas
    movwf	AUX_BCD_H			; El resultado de la resta alta estaba en W
    movf	RETARDO_CONT, w
    movwf	AUX_BCD_L
    incf	DECENAS, f
    goto	BCD_DEC

; --- SACAR UNIDADES (Restar 100) ---
BCD_UNI:
    movlw	100
    subwf	AUX_BCD_L, w
    movwf	RETARDO_CONT
    movlw	0
    btfss	STATUS, 0
    addlw	1
    subwf	AUX_BCD_H, w
    
    btfss	STATUS, 0
    goto	BCD_FIN				; Si es negativo, lo que queda son décimas
    
    movwf	AUX_BCD_H
    movf	RETARDO_CONT, w
    movwf	AUX_BCD_L
    incf	UNIDADES, f
    goto	BCD_UNI

BCD_FIN:

    movf	AUX_BCD_L, w
    movwf	DECIMAS
    return
    
; SUBRUTINAS PARA LCD --------------------
    
LCD_INIT:
    movlw	0x38				; LCD 8 bits, 2 líneas
    call	LCD_CMD
    call	RETARDO_20MS
    movlw	0x0C				; Display ON, cursor OFF
    call	LCD_CMD
    call	RETARDO_5MS
    movlw	0x06				; Incremento automático
    call	LCD_CMD
    call	RETARDO_5MS
    movlw	0x01				; Clear display
    call	LCD_CMD
    call	RETARDO_20MS
    return

LCD_CMD:
    movwf	PORTB
    bcf		PORTA, RS
    bcf		PORTA, RW
    bsf		PORTA, E
    nop
    bcf		PORTA, E
    call	RETARDO_5MS
    return					; Comandos para enviar dato al LCD

LCD_CHAR:
    movwf	PORTB
    bsf		PORTA, RS
    bcf		PORTA, RW
    bsf		PORTA, E
    nop
    bcf		PORTA, E
    call	RETARDO_5MS
    return					; Comandos para enviar caracter al LCD

LCD_CLEAR:
    movlw	0x01
    call	LCD_CMD
    call	RETARDO_20MS
    return					; Comandos para limpiar LCD

LCD_HOME:
    movlw	0x80
    call	LCD_CMD
    call	RETARDO_20MS
    return					; Comando para posicionarse en linea 1
    
LCD_DIGITO:
    addlw	'0'
    call	LCD_CHAR
    return
    
; SUBRUTINAS DE TIEMPO --------------------

RETARDO_1S:
    
    movlw       50				; 50 veces 20ms = 1000ms
    movwf       CONT_SEGUNDOS
    
BUCLE_1S:
    call        RETARDO_20MS
    decfsz      CONT_SEGUNDOS, f
    goto        BUCLE_1S
    return

RETARDO_40MS:
    
    call        RETARDO_20MS
    call        RETARDO_20MS
    return

RETARDO_20MS:
    
    ; 20ms / (1us * 256) = 78 cuentas aprox.
    ; 256 - 78 = 178
    movlw       178
    movwf       TMR0
    bcf         INTCON, 2			; Limpiar flag T0IF

ESPERA_TMR0:
    btfss       INTCON, 2			; Esperar desbordamiento
    goto        ESPERA_TMR0
    return
    
RETARDO_5MS:
    
    movlw   0xFF
    movwf   RETARDO_CONT
R5:
    decfsz  RETARDO_CONT, f
    goto    R5
    return    
    
end
    


