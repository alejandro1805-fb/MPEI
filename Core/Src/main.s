/* ====================================================================
   Proyecto: Sumador Multiplexado
   Target:   STM32F103 (Proteus / Blue Pill)
   Reloj:    HSI Interno (8 MHz)

   SECUENCIA DE FUNCIONAMIENTO:

   Pulsación 1:
       Captura Dato A desde PA0-PA7
       Guarda Dato A en R4
       Enciende LED D1 (PB13)

   Pulsación 2:
       Captura Dato B desde PA0-PA7
       Guarda Dato B en R5
       Apaga LED D1
       Enciende LED D2 (PB14)

   Pulsación 3:
       Suma R4 + R5
       Guarda resultado en R6
       Guarda Carry en R7
       Muestra resultado
       Apaga LED D2
       Enciende LED D3

   Pulsación 4:
       Reinicia la secuencia

   --------------------------------------------------------------------
   ENTRADAS:

   PA0 - PA7  -> DIP Switch (Datos A y B)
   PC13       -> Pulsador de avance (Pull-Up)

   --------------------------------------------------------------------
   SALIDAS:

   PB0 - PB7  -> Resultado de la suma
   PB8        -> Carry Out
   PB13       -> LED D1
   PB14       -> LED D2
   PB15       -> LED D3

   --------------------------------------------------------------------
   IMPORTANTE SOBRE PB2:

   PB2 está configurado como salida en CubeMX y continúa configurado
   como salida en este programa.

   Sin embargo, la Blue Pill utilizada no dispone de un pin físico
   accesible para PB2.

   Por esto:

       Resultado bit 0 -> PB0
       Resultado bit 1 -> PB1
       Resultado bit 2 -> PB2 (lógico / interno)
       Resultado bit 2 -> PB9 (copia para conexión física)
       Resultado bit 3 -> PB3
       Resultado bit 4 -> PB4
       Resultado bit 5 -> PB5
       Resultado bit 6 -> PB6
       Resultado bit 7 -> PB7
       Carry            -> PB8

   De esta manera PB2 sigue configurado como salida, pero PB9 permite
   conectar físicamente el bit 2 del resultado.
   ==================================================================== */


    .syntax unified
    .cpu cortex-m3
    .thumb

    .text
    .align 2

    .global main
    .global Reset_Handler

    .type main, %function
    .type Reset_Handler, %function

    .thumb_func


/* ====================================================================
   DIRECCIONES DE REGISTROS RCC, AFIO Y GPIO
   ==================================================================== */


/* ---------------- RCC ---------------- */

.equ RCC_APB2ENR,     0x40021018


/* ---------------- AFIO ---------------- */

.equ AFIO_BASE,       0x40010000
.equ AFIO_MAPR,       (AFIO_BASE + 0x04)


/* ---------------- GPIOA ---------------- */

.equ GPIOA_CRL,       0x40010800
.equ GPIOA_IDR,       0x40010808


/* ---------------- GPIOB ---------------- */

.equ GPIOB_CRL,       0x40010C00
.equ GPIOB_CRH,       0x40010C04
.equ GPIOB_IDR,       0x40010C08
.equ GPIOB_ODR,       0x40010C0C


/* ---------------- GPIOC ---------------- */

.equ GPIOC_CRH,       0x40011004
.equ GPIOC_IDR,       0x40011008
.equ GPIOC_ODR,       0x4001100C



/* ====================================================================
   RESET HANDLER / MAIN
   ==================================================================== */

Reset_Handler:

main:

    /* ---------------------------------------------------------------
       Deshabilitar interrupciones durante la inicialización
       --------------------------------------------------------------- */

    cpsid i



    /* =================================================================
       1. HABILITAR RELOJ PARA:

          AFIO
          GPIOA
          GPIOB
          GPIOC
       ================================================================= */

    LDR R0, =RCC_APB2ENR

    LDR R1, [R0]

    ORR R1, R1, #(1 << 0)     /* AFIOEN */
    ORR R1, R1, #(1 << 2)     /* IOPAEN */
    ORR R1, R1, #(1 << 3)     /* IOPBEN */
    ORR R1, R1, #(1 << 4)     /* IOPCEN */

    STR R1, [R0]



    /* =================================================================
       2. DESHABILITAR JTAG

       Esto permite utilizar PB3 y PB4 como GPIO.

       SWJ_CFG = 010

       JTAG deshabilitado
       SWD habilitado
       ================================================================= */

    LDR R0, =AFIO_MAPR

    LDR R1, [R0]

    BIC R1, R1, #(0x7 << 24)

    ORR R1, R1, #(0x2 << 24)

    STR R1, [R0]



    /* =================================================================
       3. CONFIGURAR PA0-PA7 COMO ENTRADAS DIGITALES FLOATING

       0x44444444

       Cada pin:

       MODE = 00
       CNF  = 01
       ================================================================= */

    LDR R0, =GPIOA_CRL

    LDR R1, =0x44444444

    STR R1, [R0]



    /* =================================================================
       4. CONFIGURAR PB0-PB7 COMO SALIDAS PUSH-PULL 2 MHz

       0x22222222

       PB0
       PB1
       PB2
       PB3
       PB4
       PB5
       PB6
       PB7
       ================================================================= */

    LDR R0, =GPIOB_CRL

    LDR R1, =0x22222222

    STR R1, [R0]



    /* =================================================================
       5. CONFIGURAR PB8, PB9, PB13, PB14 Y PB15

       PB8  -> Carry
       PB9  -> Copia física del bit 2
       PB13 -> LED D1
       PB14 -> LED D2
       PB15 -> LED D3

       0x22200022
       ================================================================= */

    LDR R0, =GPIOB_CRH

    LDR R1, =0x22200022

    STR R1, [R0]



    /* =================================================================
       6. CONFIGURAR PC13 COMO ENTRADA PULL-UP

       PC13 está en GPIOC_CRH.

       MODE = 00
       CNF  = 10

       0x04
       ================================================================= */

    LDR R0, =GPIOC_CRH

    LDR R1, [R0]

    /* Limpiar configuración actual de PC13 */

    BIC R1, R1, #(0x0F << 20)

    /* PC13 = Input Pull-Up/Pull-Down */

    ORR R1, R1, #(0x04 << 20)

    STR R1, [R0]



    /* =================================================================
       7. ACTIVAR PULL-UP DE PC13

       Para STM32F1:

       ODR = 1 -> Pull-Up
       ODR = 0 -> Pull-Down
       ================================================================= */

    LDR R0, =GPIOC_ODR

    LDR R1, [R0]

    ORR R1, R1, #(1 << 13)

    STR R1, [R0]



/* ====================================================================
   INICIO DE LA MÁQUINA DE ESTADOS
   ==================================================================== */

inicio_proceso:


    /* =================================================================
       REPOSO INICIAL

       Limpiar las salidas del Puerto B.

       Esto apaga:

       PB0-PB9
       PB13
       PB14
       PB15
       ================================================================= */

    LDR R0, =GPIOB_ODR

    MOV R1, #0

    STR R1, [R0]



/* ====================================================================
   PASO 1: CAPTURA DEL DATO A
   ==================================================================== */


    /* ---------------------------------------------------------------
       Esperar primera pulsación del botón
       --------------------------------------------------------------- */

    BL esperar_pulsacion



    /* ---------------------------------------------------------------
       Leer PA0-PA7

       R4 = Dato A
       --------------------------------------------------------------- */

    LDR R0, =GPIOA_IDR

    LDR R4, [R0]

    AND R4, R4, #0xFF



    /* ---------------------------------------------------------------
       Encender LED D1

       PB13 = 1
       --------------------------------------------------------------- */

    LDR R0, =GPIOB_ODR

    LDR R1, =(1 << 13)

    STR R1, [R0]



/* ====================================================================
   PASO 2: CAPTURA DEL DATO B
   ==================================================================== */


    /* ---------------------------------------------------------------
       Esperar segunda pulsación
       --------------------------------------------------------------- */

    BL esperar_pulsacion



    /* ---------------------------------------------------------------
       Leer nuevamente PA0-PA7

       R5 = Dato B
       --------------------------------------------------------------- */

    LDR R0, =GPIOA_IDR

    LDR R5, [R0]

    AND R5, R5, #0xFF



    /* ---------------------------------------------------------------
       Apagar D1 y encender D2

       PB13 = 0
       PB14 = 1
       --------------------------------------------------------------- */

    LDR R0, =GPIOB_ODR

    LDR R1, =(1 << 14)

    STR R1, [R0]



/* ====================================================================
   PASO 3: CÁLCULO Y MUESTRA DE LA SUMA
   ==================================================================== */


    /* ---------------------------------------------------------------
       Esperar tercera pulsación
       --------------------------------------------------------------- */

    BL esperar_pulsacion



    /* ---------------------------------------------------------------
       Sumar:

       R4 = Dato A
       R5 = Dato B

       R6 = Resultado

       ADDS actualiza los flags, incluido Carry.
       --------------------------------------------------------------- */

    ADDS R6, R4, R5



    /* ---------------------------------------------------------------
       Capturar Carry

       R7 = 0 -> no hubo Carry
       R7 = 1 -> hubo Carry
       --------------------------------------------------------------- */

    MOV R7, #0

    ADC R7, R7, #0



    /* ---------------------------------------------------------------
       Conservar solamente los 8 bits bajos de la suma.

       Ejemplo:

       250 + 10 = 260

       260 decimal = 0x104

       R6 después del AND = 0x04
       R7 = 1

       Por tanto:

       PB0-PB7 = 00000100
       PB8     = 1
       --------------------------------------------------------------- */

    AND R6, R6, #0xFF



    /* =================================================================
       CONSTRUIR SALIDA

       R6:

       bit 0 -> PB0
       bit 1 -> PB1
       bit 2 -> PB2
       bit 3 -> PB3
       bit 4 -> PB4
       bit 5 -> PB5
       bit 6 -> PB6
       bit 7 -> PB7

       R7:

       bit 0 -> Carry

       Lo desplazamos 8 posiciones:

       R7 bit 0 -> bit 8

       Por tanto:

       bit 8 -> PB8
       ================================================================= */

    LSL R7, R7, #8



    /* ---------------------------------------------------------------
       Combinar resultado y Carry

       R1:

       PB0-PB7 = resultado
       PB8     = Carry
       --------------------------------------------------------------- */

    ORR R1, R6, R7



    /* =================================================================
       PROBLEMA FÍSICO DE PB2

       CubeMX tiene PB2 configurado como salida.

       El resultado normalmente pondría:

           R6 bit 2 -> PB2

       Sin embargo, PB2 no está disponible físicamente en nuestra
       Blue Pill.

       Por eso hacemos una copia del bit 2 hacia PB9.

       Si R6 bit 2 = 1:

           PB2 = 1
           PB9 = 1

       Si R6 bit 2 = 0:

           PB2 = 0
           PB9 = 0
       ================================================================= */


    /* ---------------------------------------------------------------
       Comprobar bit 2 de R6
       --------------------------------------------------------------- */

    TST R6, #(1 << 2)

    BEQ bit2_cero



    /* ---------------------------------------------------------------
       Bit 2 = 1

       Activar PB2
       Activar PB9
       --------------------------------------------------------------- */

    ORR R1, R1, #(1 << 2)

    ORR R1, R1, #(1 << 9)

    B bit2_listo



bit2_cero:


    /* ---------------------------------------------------------------
       Bit 2 = 0

       PB2 y PB9 deben permanecer en 0.

       Como R1 fue construido a partir de R6 y R6 bit 2 = 0,
       PB2 ya está en 0.

       PB9 también está en 0.
       --------------------------------------------------------------- */


bit2_listo:


    /* =================================================================
       ENCENDER LED D3

       PB15 = 1

       PB13 y PB14 permanecen apagados porque R1 no contiene esos bits.
       ================================================================= */

    ORR R1, R1, #(1 << 15)



    /* ---------------------------------------------------------------
       Escribir todo el resultado en GPIOB
       --------------------------------------------------------------- */

    LDR R0, =GPIOB_ODR

    STR R1, [R0]



/* ====================================================================
   PASO 4: REINICIO DE LA SECUENCIA
   ==================================================================== */


    /* ---------------------------------------------------------------
       El resultado permanece mostrado.

       Esperar cuarta pulsación.
       --------------------------------------------------------------- */

    BL esperar_pulsacion



    /* ---------------------------------------------------------------
       Volver al inicio y limpiar las salidas.
       --------------------------------------------------------------- */

    B inicio_proceso



/* ====================================================================
   BUCLE INFINITO DE SEGURIDAD
   ==================================================================== */

bucle_espera:

    B bucle_espera



/* ====================================================================
   SUBRUTINA: esperar_pulsacion

   Detecta una pulsación completa:

       1. Espera PC13 = 0
          Botón presionado

       2. Antirrebote

       3. Espera PC13 = 1
          Botón liberado

       4. Antirrebote

       5. Regresa al programa principal

   Debido al Pull-Up:

       PC13 = 1 -> botón sin presionar
       PC13 = 0 -> botón presionado
   ==================================================================== */

esperar_pulsacion:


    /* ---------------------------------------------------------------
       Cargar dirección de GPIOC_IDR
       --------------------------------------------------------------- */

    LDR R0, =GPIOC_IDR



/* ====================================================================
   ESPERAR BOTÓN PRESIONADO
   ==================================================================== */

esperar_cero:


    LDR R1, [R0]



    /* ---------------------------------------------------------------
       Comprobar PC13
       --------------------------------------------------------------- */

    TST R1, #(1 << 13)



    /* ---------------------------------------------------------------
       Si PC13 = 1:

       El botón todavía NO está presionado.

       Continuar esperando.
       --------------------------------------------------------------- */

    BNE esperar_cero



    /* =================================================================
       ANTIRREBOTE AL PRESIONAR
       ================================================================= */

    LDR R2, =8000



delay1:


    SUBS R2, R2, #1

    BNE delay1



/* ====================================================================
   ESPERAR BOTÓN LIBERADO
   ==================================================================== */

esperar_uno:


    LDR R1, [R0]



    /* ---------------------------------------------------------------
       Comprobar PC13
       --------------------------------------------------------------- */

    TST R1, #(1 << 13)



    /* ---------------------------------------------------------------
       Si PC13 = 0:

       El botón todavía está presionado.

       Continuar esperando.
       --------------------------------------------------------------- */

    BEQ esperar_uno



    /* =================================================================
       ANTIRREBOTE AL SOLTAR
       ================================================================= */

    LDR R2, =8000



delay2:


    SUBS R2, R2, #1

    BNE delay2



    /* ---------------------------------------------------------------
       Regresar al programa principal
       --------------------------------------------------------------- */

    BX LR



/* ====================================================================
   FIN DEL PROGRAMA
   ==================================================================== */
