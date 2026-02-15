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

    HORARIO_H       EQU     0x05    ; Parte Alta de 1500 (1500 = 0x05DC)
    HORARIO_L       EQU     0xDC    ; Parte Baja de 1500
    ANTIHORARIO_H   EQU     0x03    ; Parte Alta de 1000 (1000 = 0x03E8)
    ANTIHORARIO_L   EQU     0xE8    ; Parte Baja de 1000

    ; Variables en RAM (Banco 0)
    TEMPORAL        EQU     0x20
    DELAY_CONT      EQU     0x21
    CONT_SEGUNDOS   EQU     0x22

; PROGRAMA -------------------------------

    org         0x00
    goto        INICIO

INICIO:

; INICIALIZACIÓN --------------------------

    bsf         STATUS,     5       ; Banco 1
    bcf         STATUS,     6

    movlw       0x06
    movwf       ADCON1              ; Pines digitales en PORTA

    clrf        TRISB               ; PORTB todo salida (Motor)
    movlw       0x1F
    movwf       TRISA               ; PORTA entradas (Switches RA0-RA4)
    
    movlw       0b00000001          ; RC0 entrada (T1CKI), RC1 y RC2 salidas (CCP)
    movwf       TRISC               ; b'00000001'

    movlw       0b11000111          ; Prescaler TMR0 1:256
    movwf       OPTION_REG

    movlw       254                 ; Periodo PWM (PR2)
    movwf       PR2

    bcf         STATUS,     5       ; Banco 0
    bcf         STATUS,     6

    clrf        PORTB
    clrf        PORTA
    clrf        PORTC

; FUNCIÓN PRINCIPAL -----------------------

BUCLE_PRINCIPAL:
    
    ; Configurar CCP2 en modo PWM
    movlw       0x0C                ; Modo PWM
    movwf       CCP2CON

    movlw       0xFF                ; Valor temporal máximo (255)
    movwf       TEMPORAL
    clrf        CCPR2L              ; Velocidad inicial 0

    movlw       0x04                ; TMR2 ON, Prescaler 1
    movwf       T2CON

; PASO 1: ARRANQUE SUAVE (SENTIDO HORARIO)
    
    movlw       0x02                ; RB1 ON (Sentido Horario)
    movwf       PORTB	

RAMPA_SUBIDA:
    call        RETARDO_40MS
    
    incf        CCPR2L, f           ; Aumentar ciclo de trabajo
    decfsz      TEMPORAL, f         ; ¿Llegó a 255?
    goto        RAMPA_SUBIDA        ; No, seguir subiendo

; PASO 2: GIRAR X PASOS (HORARIO)
    
    ; Configurar CCP1 para contar pasos (Modo Compare)
    clrf        TMR1L
    clrf        TMR1H
    
    movlw       HORARIO_H
    movwf       CCPR1H
    movlw       HORARIO_L
    movwf       CCPR1L

    movlw       0x0B                ; Compare mode, trigger special event
    movwf       CCP1CON
    
    movlw       0x03                ; TMR1 ON, External Clock (Encoder)
    movwf       T1CON
    
    bcf         PIR1, 2             ; Limpiar flag CCP1IF

ESPERA_PASOS_HOR:
    btfss       PIR1, 2             ; ¿Terminó de contar?
    goto        ESPERA_PASOS_HOR
    
    bcf         PIR1, 2             ; Limpiar flag
    clrf        PORTB               ; Apagar motor

; PASO 3: PARAR 1 SEGUNDO -----------------
    bcf		T1CON,	0
    call        RETARDO_1S
    clrf	TMR1L
    clrf	TMR1H
    movlw       0x0B                ; Compare mode, trigger special event (de nuevo)
    movwf       CCP1CON

; PASO 4: GIRAR X PASOS (ANTIHORARIO) CON VELOCIDAD RA4-RA0
    
    ; Cargar pasos antihorario
    movlw       ANTIHORARIO_H
    movwf       CCPR1H
    movlw       ANTIHORARIO_L
    movwf       CCPR1L

    ; Leer velocidad de PORTA
    movf        PORTA, w
    movwf       TEMPORAL            ; Guardar switches
    
    ; Multiplicar por 8 para obtener PWM útil
    bcf         STATUS, 0           ; Limpiar Carry
    rlf         TEMPORAL, f         ; x2
    bcf		STATUS,	0
    rlf         TEMPORAL, f         ; x4
    bcf		STATUS,	0	    
    rlf         TEMPORAL, w         ; x8 -> W
    
    movwf       CCPR2L              ; Cargar velocidad al PWM

    movlw       0x01                ; RB0 ON (Sentido Antihorario)
    movwf       PORTB
    
    bcf         PIR1, 2             ; Limpiar flag CCP1IF
    bsf		T1CON, 0

ESPERA_PASOS_ANTI:
    btfss       PIR1, 2             ; ¿Terminó de contar?
    goto        ESPERA_PASOS_ANTI
    
    bcf         PIR1, 2             ; Limpiar flag

; PASO 5: DISMINUCIÓN VELOCIDAD -----------

RAMPA_BAJADA:
    call        RETARDO_40MS
    
    movf        CCPR2L, f           ; Verificar si es 0
    btfsc       STATUS, 2           ; Z=1? (Es cero)
    goto        FIN_RAMPA_BAJADA
    
    decf        CCPR2L, f           ; Disminuir velocidad
    goto        RAMPA_BAJADA

FIN_RAMPA_BAJADA:
    clrf        PORTB               ; Asegurar motor apagado

; PASO 6: PARAR 1 SEGUNDO Y REPETIR -------

    call        RETARDO_1S
    goto        BUCLE_PRINCIPAL

; SUBRUTINAS DE TIEMPO --------------------

RETARDO_1S:
    movlw       50                  ; 50 veces 20ms = 1000ms
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
    ; TMR0 con prescaler 256. 
    ; 20ms / (1us * 256) = 78 cuentas aprox.
    ; 256 - 78 = 178
    movlw       178
    movwf       TMR0
    bcf         INTCON, 2           ; Limpiar flag T0IF

ESPERA_TMR0:
    btfss       INTCON, 2           ; Esperar desbordamiento
    goto        ESPERA_TMR0
    return

    end