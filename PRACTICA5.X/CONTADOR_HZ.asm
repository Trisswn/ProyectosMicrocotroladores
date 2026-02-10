PROCESSOR   16F877A
    #include    <xc.inc>

    CONFIG  FOSC = XT        ; Oscilador XT (4 MHz)
    CONFIG  WDTE = OFF       ; Watchdog Timer deshabilitado
    CONFIG  PWRTE = OFF      ; Power-up Timer deshabilitado
    CONFIG  BOREN = ON
    CONFIG  CPD = OFF        ; Protección de código deshabilitada
    CONFIG  LVP = OFF        ; Low Voltage Programming OFF	
    CONFIG  WRT = OFF
    CONFIG  CP = OFF


    PSECT   Code, delta=2
   
; VARIABLES ------------------------------
   
    BANDERA_250MS    EQU    0x20
    TIMER1_H	     EQU    0x21		; Veces que ya se contó pulsos hasta 256
    TIMER1_L	     EQU    0x22		; Pulsos normales
    CONT_TIMER0	     EQU    0x23		; Contador de desbordes de TMR0	     
    FREQ_TIMER1H     EQU    0x24
    FREQ_TIMER1L     EQU    0x25		; Para alojar copias de los datos
    
; NUEVAS VARIABLES PARA CORRECCIÓN
    TEMP_H	     EQU    0x26
    TEMP_L	     EQU    0x27
    CENTENAS         EQU    0x28
    DECENAS          EQU    0x29
    UNIDADES         EQU    0x2A
    VALOR_TEMP       EQU    0x2B
    RETARDO_CONT     EQU    0x2C
     
; DEFINICIÓN DE PINES LCD (PORTA)
    RS		     EQU    0		        ; Register Select (RA0)
    RW		     EQU    1			; Read/Write (RA1)
    E		     EQU    2			; Enable (RA2)
	     
; PROGRAMA -------------------------------
    
    org		0x00
    goto	INICIO

    org		0x04
    goto	ISR	
   
INICIO:
    
; INICIALIZACIÓN --------------------------
    
    bsf		STATUS,		5
    bcf		STATUS,		6		; Cambiar al banco 1

    movlw	0x06
    movwf	ADCON1				; Port A como pines digitales
    
    movlw	0x01
    movwf	TRISC				; Poner RC0 como entrada
    clrf	TRISB				; Poner PORTB como salida 
    clrf	TRISA				; Poner PORTA como salida
    
; CONFIG. TIMERS --------------------------
    
    movlw	0b10000111		; Pull-ups desactivados, Prescaler 1:256 para TMR0
    movwf	OPTION_REG
    
    bcf		STATUS,		5		; Volver al banco 0
    
    movlw	0x0C			; Cargar TMR0 para ~61ms (250ms/4)
    movwf	TMR0
    clrf	CONT_TIMER0			; Limpiar el contador de desbordes
    
    clrf	TMR1H
    clrf	TMR1L				; Limpiar el TMR1
    clrf	TIMER1_H
    clrf	TIMER1_L			; Limpiar variables para TMR1
    
    movlw	0b00110001		; Configurar T1CON: TMR1ON=1, TMR1CS=1 (ext clock), Preescaler 1:2
    movwf	T1CON
    
; CONFIG. INTCON Y LCD --------------------
    
    bsf		INTCON,		5		; Habilitar las interrupciones del TMR0 (TMR0IE)
    bsf		INTCON,		7		; Habilitar interrupciones globales (GIE)
    
    call	LCD_INIT			; Preparar la pantalla

; FUNCION PRINCIPAL -----------------------
    
MAIN:
    
    btfss	BANDERA_250MS,	0		; ¿Ya pasaron los 250ms?
    goto	MAIN				; No, seguir esperando
    
    bcf		BANDERA_250MS,	0		; Limpiar la bandera del tiempo
    
    ; Copiar valores del Timer1
    movf	TIMER1_L,	w
    movwf	FREQ_TIMER1L
    movf	TIMER1_H,	w
    movwf	FREQ_TIMER1H
    
    ; --- FILTRADO DE RUIDO ---
    ; Si no hay señal (menos de 5 pulsos en 250ms), considerar 0
    movf	FREQ_TIMER1H,	w
    btfss	STATUS,		2		; Si HIGH byte != 0, es señal válida
    goto	SENAL_VALIDA
    
    movf	FREQ_TIMER1L,	w
    sublw	5			; Si LOW byte < 5, considerar ruido
    btfsc	STATUS,		0
    goto	NO_SENAL		; Es ruido, mostrar 0
    
SENAL_VALIDA:
    ; MULTIPLICAR POR 4 CORRECTAMENTE
    call	MULTIPLICAR_X4
    
    ; Convertir a frecuencia (Hz)
    ; Pulsos en 250ms × 4 = Pulsos en 1 segundo = Hz
    goto	MOSTRAR_FREC
    
NO_SENAL:
    clrf	FREQ_TIMER1L
    clrf	FREQ_TIMER1H
    
MOSTRAR_FREC:
    call	MOSTRAR_RESULTADO
    goto	MAIN

; SUBRUTINA PARA MULTIPLICACIÓN CORRECTA X4 ----------------
MULTIPLICAR_X4:
    ; Guardar valor original
    movf	FREQ_TIMER1L,	w
    movwf	TEMP_L
    movf	FREQ_TIMER1H,	w
    movwf	TEMP_H
    
    ; Limpiar resultado
    clrf	FREQ_TIMER1L
    clrf	FREQ_TIMER1H
    
    ; Sumar 4 veces (multiplicar por 4)
    movlw	4
    movwf	VALOR_TEMP		; Usar VALOR_TEMP como contador
    
MULT_LOOP:
    movf	TEMP_L,		w
    addwf	FREQ_TIMER1L,	f
    movf	TEMP_H,		w
    btfsc	STATUS,		0	; Si hay carry de la suma anterior
    incfsz	TEMP_H,	w		; Incrementar si hay carry
    addwf	FREQ_TIMER1H,	f
    decfsz	VALOR_TEMP,	f
    goto	MULT_LOOP
    
    return

; SUBRUTINA PARA RESULTADO ----------------
    
MOSTRAR_RESULTADO:
    call	BIN_A_BCD
    call	LCD_CLEAR
    call	LCD_HOME
    
    movlw	' '
    call	LCD_CHAR
    movlw	'F'
    call	LCD_CHAR
    movlw	'R'
    call	LCD_CHAR
    movlw	'E'
    call	LCD_CHAR
    movlw	'Q'
    call	LCD_CHAR
    movlw ':'
    call  LCD_CHAR
    movlw ' '
    call  LCD_CHAR

    ; Mostrar centenas
    movf	CENTENAS, w
    call	LCD_DIGITO

    ; Mostrar decenas
    movf	DECENAS, w
    call	LCD_DIGITO

    ; Mostrar unidades
    movf	UNIDADES, w
    call	LCD_DIGITO

    ; Mostrar " Hz"
    movlw	' '
    call	LCD_CHAR
    movlw	'H'
    call	LCD_CHAR
    movlw	'z'
    call	LCD_CHAR

    return
   
; SUBRUTINAS PARA LCD --------------------
LCD_INIT:
    movlw	0x38        ; LCD 8 bits, 2 líneas
    call	LCD_CMD
    call	RETARDO_20MS
    movlw	0x0C        ; Display ON, cursor OFF
    call	LCD_CMD
    call	RETARDO_5MS
    movlw	0x06        ; Incremento automático
    call	LCD_CMD
    call	RETARDO_5MS
    movlw	0x01        ; Clear display
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
    return

LCD_CHAR:
    movwf	PORTB
    bsf		PORTA, RS
    bcf		PORTA, RW
    bsf		PORTA, E
    nop
    bcf		PORTA, E
    call	RETARDO_5MS
    return

LCD_CLEAR:
    movlw	0x01
    call	LCD_CMD
    call	RETARDO_20MS
    return

LCD_HOME:
    movlw	0x80
    call	LCD_CMD
    call	RETARDO_20MS
    return
    
; CONVERSIÓN BINARIO A BCD ----------------------------
    
BIN_A_BCD:
    clrf	CENTENAS
    clrf	DECENAS
    clrf	UNIDADES

    ; Usar valor de 16 bits para la conversión
    ; Primero trabajar con el byte bajo
    movf	FREQ_TIMER1L, w
    movwf	VALOR_TEMP
    movf	FREQ_TIMER1H, w
    movwf	TEMP_H		; Usar TEMP_H para contar el byte alto
    
    ; Si el byte alto es 0, solo procesar byte bajo
    movf	TEMP_H, f
    btfsc	STATUS, 2
    goto	BCD_SOLO_BAJO
    
    ; Para valores > 255, simplificar mostrando "999"
    movlw	0x03		; 999 en decimal es 0x03E7
    subwf	TEMP_H, w
    btfss	STATUS, 0
    goto	VALOR_GRANDE
    
    movlw	0xE7		; Byte bajo de 999
    subwf	VALOR_TEMP, w
    btfss	STATUS, 0
    goto	VALOR_GRANDE
    
    ; Si llegamos aquí, el valor es ? 999
    goto	PROCESAR_BCD

VALOR_GRANDE:
    ; Mostrar 999 como máximo
    movlw	0x09
    movwf	CENTENAS
    movwf	DECENAS
    movwf	UNIDADES
    return

BCD_SOLO_BAJO:
    ; Valor ? 255, procesar normalmente
    goto	PROCESAR_BCD

PROCESAR_BCD:
    ; Reiniciar valores BCD
    clrf	CENTENAS
    clrf	DECENAS
    
    ; Convertir valor de 16 bits en VALOR_TEMP:TEMP_H a BCD
    ; Simplificado para valores ? 999

; ---- centenas ----
BCD_CEN:
    movlw	100
    subwf	VALOR_TEMP, w
    btfss	STATUS, 0
    goto	BCD_DEC
    movwf	VALOR_TEMP
    incf	CENTENAS, f
    goto	BCD_CEN

; ---- decenas ----
BCD_DEC:
    movlw	10
    subwf	VALOR_TEMP, w
    btfss	STATUS, 0
    goto	BCD_UNI
    movwf	VALOR_TEMP
    incf	DECENAS, f
    goto	BCD_DEC

; ---- unidades ----
BCD_UNI:
    movf	VALOR_TEMP, w
    movwf	UNIDADES
    return
    
LCD_DIGITO:
    addlw	'0'
    call	LCD_CHAR
    return
    
; RETARDOS --------------------------------

RETARDO_5MS:
    movlw   0xFF
    movwf   RETARDO_CONT
R5:
    decfsz  RETARDO_CONT, f
    goto    R5
    return

RETARDO_20MS:
    call    RETARDO_5MS
    call    RETARDO_5MS
    call    RETARDO_5MS
    call    RETARDO_5MS
    return
    
; RUTINA DE INTERRUPCIÓN ------------------
    
ISR:
    btfss	INTCON,	2		; ¿Es una interrupción por TMR0? (TMR0IF)
    goto	SALIR_ISR		; Si no es interrupción, salir
    
    ; Recargar TMR0 para próximo intervalo de ~61ms
    movlw	0x0C
    movwf	TMR0
    
    incf	CONT_TIMER0,	f	; Incrementar contador de interrupciones
    
    movlw	4
    subwf	CONT_TIMER0,	w	; ¿Ya pasaron 4 interrupciones?
    btfss	STATUS,	2		; ¿El resultado es 0?
    goto	LIMPIAR_FLAG		; No, limpiar bandera y salir
    
    ; Sí, han pasado ~250ms (4 × 61ms = 244ms)
    
    ; Detener Timer1 para lectura estable
    bcf		T1CON,	0		; Apagar TMR1
    
    ; Leer Timer1
    movf	TMR1L,	w
    movwf	TIMER1_L
    movf	TMR1H,	w
    movwf	TIMER1_H
    
    ; Reiniciar Timer1
    clrf	TMR1L
    clrf	TMR1H
    bsf		T1CON,	0		; Encender TMR1
    
    ; Activar bandera para procesamiento en MAIN
    bsf		BANDERA_250MS,	0
    
    ; Reiniciar contadores
    clrf	CONT_TIMER0
    
LIMPIAR_FLAG:
    bcf		INTCON,	2		; Limpiar bandera de desbordamiento de TMR0
    
SALIR_ISR:
    retfie
    
    end
