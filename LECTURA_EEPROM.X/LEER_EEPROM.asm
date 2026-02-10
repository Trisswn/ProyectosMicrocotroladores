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

        org     0x05

	; Variables
        ADDR_L  EQU  0X020
        DATA_L  EQU  0x021
	CONT    EQU 0x022
	
INICIO:
        ; 1. PREPARACIÓN PARA LEER LA DIRECCIÓN 00h
	
        movlw   0x00            ; Cargar dirección 00h
        movwf   ADDR_L          ; Guardar en variable de paso
        call    LEER_EEPROM     ; Ejecutar subrutina de lectura

        ; 2. COMPARACIÓN CON EL VALOR DE CONTROL 27h
	
        movf    DATA_L, w       ; Mover el dato leído a W
        sublw   0x27            ; Restar 27h al valor en W
        btfss   STATUS, 2       ; ¿Es cero el resultado? (Z=1 si son iguales)
        goto    FLUJO_NORMAL    ; Si NO es 27h, saltar inicialización [cite: 19, 20]

PRIMERA_VEZ:                    ; Se ejecuta solo si se detectó 27h
    
        ; 3. RUTINAS DE INICIALIZACIÓN 
	
        movlw   0x0A            ; Cargar valor inicial para contadores
        movwf   CONT            ; Inicializar contador de ejemplo

        ; 4. MODIFICAR EEPROM PARA INDICAR INICIALIZACIÓN REALIZADA 
	
        movlw   0x00            ; Valor nuevo (diferente a 27h)
        movwf   DATA_L
        movlw   0x00            ; Seguir trabajando en dirección 00h
        movwf   ADDR_L
        call    ESCRIBIR_EEPROM ; Ejecutar escritura física [cite: 28]

FLUJO_NORMAL:                   ; Punto donde converge el programa 
    
        ; 5. CUERPO NORMAL DEL PROGRAMA
	
        nop                     ; Instrucción de relleno (No Operation)
        goto    FLUJO_NORMAL    ; Bucle infinito de ejecución normal

; --- SUBRUTINAS ---

LEER_EEPROM:                    ; 
        bsf     STATUS, 6       
        bcf     STATUS, 5       ; Cambiar al banco 2
        bcf     STATUS, 6       ; Regresar a Banco 0 para leer ADDR_L
        movf    ADDR_L, w       ; Cargar dirección en W
        bsf     STATUS, 6       ; Regresar a Banco 2
        movwf   EEADR           ; Pasar dirección al hardware
        bsf     STATUS, 5       ; Cambiar al banco 3
        bcf     EECON1, 7       ; EEPGD = 0 (Memoria de datos)
        bsf     EECON1, 0       ; RD = 1 (Iniciar lectura)
        bcf     STATUS, 5       ; Regresar al banco 2
        movf    EEDATA, w       ; Recuperar dato leído
        bcf     STATUS, 6       ; Regresar al banco 0 para guardar
        movwf   DATA_L          ; Guardar resultado en variable de paso
        return

ESCRIBIR_EEPROM:                ; Basada en manual y datasheet
        bsf     STATUS, 6
        bcf     STATUS, 5       ; Cambiar al banco 2
        bcf     STATUS, 6       ; Banco 0 para leer variables
        movf    ADDR_L, w
        bsf     STATUS, 6
        movwf   EEADR           ; Cargar dirección física
        bcf     STATUS, 6
        movf    DATA_L, w
        bsf     STATUS, 6
        movwf   EEDATA          ; Cargar dato físico
        bsf     STATUS, 5       ; Cambiar al banco 3
        bcf     EECON1, 7       ; EEPGD = 0 (Seleccionar datos)
        bsf     EECON1, 2       ; WREN = 1 (Habilitar escritura)
        bcf     INTCON, 7       ; Deshabilitar GIE por seguridad
        movlw   0x55
        movwf   EECON2          ; Secuencia de desbloqueo 1
        movlw   0xAA
        movwf   EECON2          ; Secuencia de desbloqueo 2
        bsf     EECON1, 1       ; WR = 1 (Iniciar escritura física)
        bsf     INTCON, 7       ; Reabilitar interrupciones
	
ESPERAR_WR:                     ; Bucle de espera
        btfsc   EECON1, 1       ; ¿Bit WR sigue activo?
        goto    ESPERAR_WR      ; Esperar a que termine el hardware
        bcf     EECON1, 2       ; WREN = 0 (Protección)
        bcf     STATUS, 6
        bcf     STATUS, 5       ; Regresar al Banco 0
        bcf     PIR2, 4         ; Limpiar bandera EEIF (bit 4)
        return

end


