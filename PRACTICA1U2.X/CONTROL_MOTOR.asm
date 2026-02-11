PROCESSOR   16F877A
#include    <xc.inc>

config FOSC = XT        ; Oscilador de cristal (4 MHz)
config WDTE = ON        ; Watchdog Timer activo (seguridad)
config PWRTE = OFF      ; Power-up Timer desactivado
config BOREN = ON       ; Brown-out Reset activo
config LVP = OFF        ; Programación de bajo voltaje desactivada
config CPD = OFF        ; Protección de datos EEPROM desactivada
config WRT = OFF        ; Protección de escritura desactivada
config CP = OFF         ; Protección de código desactivada

    
HORARIO      EQU  1500     ; Pasos/Pulsos para sentido horario
ANTIHORARIO  EQU  1000     ; Pasos/Pulsos para sentido antihorario
PERIODO      EQU  255      ; Valor para el periodo del PWM
TEMPORAL     EQU  0x20     ; Registro auxiliar
DELAY_CONT   EQU  0x21     ; Multiplicador para la subrutina de tiempo


PSECT Code, delta=2
org 0x00
goto INICIO

; --- SUBRUTINA DE RETARDO (20ms) ---
DELAY:
    movlw   -78            ; Carga TMR0 para que desborde en ~20ms
    movwf   TMR0
DELAY_1:
    clrwdt                 ; Limpia el perro guardián
    btfss   INTCON, 2      ; ¿Ya desbordó el TMR0? (Bit T0IF) 20ms
    goto    DELAY_1
    bcf     INTCON, 2      ; Limpia la bandera de desborde
    decfsz  DELAY_CONT, f  ; Repite según el valor en DELAY_CONT
    goto    DELAY
    return

; --- CONFIGURACIÓN INICIAL ---
INICIO:
    clrf    PORTB          ; Limpiar puertos
    clrf    PORTA
    clrf    PORTC
    
    bsf     STATUS, 5      ; --- Cambio al BANCO 1 ---
    bcf     STATUS, 6
    
    movlw   0x06           ; Configura todos los pines de PORTA como digitales
    movwf   ADCON1
    clrf    TRISB          ; PORTB como salida (Motores)
    movlw   0b00011111     ; RA0 a RA4 como entradas (Switches)
    movwf   TRISA
    movlw   0b11111101     ; RC1 como salida (CCP2 / PWM) y RC0 entrada (T1CKI)
    movwf   TRISC
    
    ; Configuración OPTION_REG: Prescaler 1:256 asignado al TMR0
    movlw   0b11000111
    movwf   OPTION_REG
    
    movlw   PERIODO-1      ; Frecuencia del PWM cargada en PR2
    movwf   PR2
    
    bcf     STATUS, 5      ; --- Regresar al BANCO 0 ---
    
BUCLE:
    clrwdt
    ; Configuración CCP2 para modo PWM
    movlw   0b00001100 
    movwf   CCP2CON
    movlw   255
    movwf   TEMPORAL       ; Usado para contar los incrementos de velocidad
    clrf    CCPR2L         ; Iniciar con velocidad 0
    movlw   0b00000111     ; TMR2 ON, Prescaler 1:16 (Base para PWM)
    movwf   T2CON

; --- PASO 1: ACELERACIÓN SUAVE ---
PASO_1:
    movlw   0b00000010     ; Sentido horario (IN2=1, IN1=0 en Puente H)
    movwf   PORTB
    movlw   2              ; Retardo de 40ms por cada incremento
    movwf   DELAY_CONT
    call    DELAY
    incf    CCPR2L, f      ; Aumenta el ciclo de trabajo (Duty Cycle)
    decfsz  TEMPORAL, f    ; ¿Llegó al máximo (255)?
    goto    PASO_1

; --- PASO 2: CONTEO DE PASOS CON ENCODER (CCP1 + TMR1) ---
PASO_2:
    clrf    TMR1L          ; Limpiar contador de pulsos
    clrf    TMR1H
    movlw   high(HORARIO)  ; Carga el límite de pasos (1500)
    movwf   CCPR1H
    movlw   low(HORARIO)
    movwf   CCPR1L
    
    ; CCP1 en modo comparador: genera evento cuando TMR1 == CCPR1
    movlw   0b00001011 
    movwf   CCP1CON
    
    ; TMR1 como CONTADOR EXTERNO (Bit 1 = 1) para leer el Encoder en RC0
    movlw   0b00000111     
    movwf   T1CON
    bcf     PIR1, 2        ; Limpiar bandera CCP1IF

PASO_2_1:
    clrwdt
    btfss   PIR1, 2        ; ¿Se alcanzó el número de pasos?
    goto    PASO_2_1       ; No, seguir girando
    bcf     PIR1, 2
    clrf    PORTB          ; Paso 2 cumplido: detiene el motor

; --- PASO 3: PARADA DE 1 SEGUNDO ---
PASO_3:
    movlw   50             ; 50 * 20ms = 1000ms (1 segundo)
    movwf   DELAY_CONT
    call    DELAY

; --- PASO 4: ANTIHORARIO Y VELOCIDAD POR SWITCHES ---
PASO_4:
    movlw   high(ANTIHORARIO)
    movwf   CCPR1H
    movlw   low(ANTIHORARIO)
    movwf   CCPR1L
    
    ; Cálculo de velocidad: (PORTA) * 8
    movf    PORTA, w       ; Lee switches (RA4-RA0)
    movwf   TEMPORAL
    bcf     STATUS, 0      ; Limpiar carry
    rlf     TEMPORAL, f    ; Rotar a la izquierda (x2)
    rlf     TEMPORAL, f    ; Rotar (x4)
    rlf     TEMPORAL, w    ; Rotar y mover a W (x8)
    movwf   CCPR2L         ; Asigna resultado al Duty Cycle del PWM
    
    movlw   0b00000001     ; Sentido antihorario (IN2=0, IN1=1)
    movwf   PORTB

PASO_4_1:
    clrwdt
    btfss   PIR1, 2        ; Esperar a que el encoder cuente 1000 pasos
    goto    PASO_4_1
    bcf     PIR1, 2

; --- PASO 5: DESACELERACIÓN ---
PASO_5:
    movlw   2              ; Retardo para que la frenada sea visible
    movwf   DELAY_CONT
    call    DELAY
    decfsz  CCPR2L, f      ; Baja la velocidad poco a poco
    goto    PASO_5

; --- PASO 6: PARADA FINAL Y REINICIO ---
PASO_6:
    clrf    PORTB          ; Apaga motor
    movlw   50             ; Espera 1 segundo
    movwf   DELAY_CONT
    call    DELAY
    goto    BUCLE          ; Regresa al Paso 1

END