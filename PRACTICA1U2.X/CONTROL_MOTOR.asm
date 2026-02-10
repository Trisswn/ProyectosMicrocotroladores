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
    org	    0x00
    goto    INICIO
    
    orf	    0x04
    
INICIO:
    
    


