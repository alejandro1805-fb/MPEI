/* ====================================================================
   Proyecto: Sumador Multiplexado
   Target:   STM32F103 (Proteus / Blue Pill)
   Reloj:    HSI Interno (8 MHz)

   DESCRIPCIÓN:

   Entradas:
       PA0 - PA7  -> DIP Switch (Datos A y B)
       PC13       -> Pulsador de avance (Pull-Up)

   Salidas físicas:

       PB0  -> Resultado bit 0
       PB1  -> Resultado bit 1
       PB3  -> Resultado bit 2
       PB4  -> Resultado bit 3
       PB5  -> Resultado bit 4
       PB6  -> Resultado bit 5
       PB7  -> Resultado bit 6
       PB8  -> Resultado bit 7
       PB9  -> Carry

       PB13 -> LED D1 (Dato A capturado)
       PB14 -> LED D2 (Dato B capturado)
       PB15 -> LED D3 (Suma realizada)

   IMPORTANTE:

   PB2 está configurado como salida en CubeMX, pero la Blue Pill
   utilizada no tiene acceso físico a PB2.

   Por lo tanto, PB2 NO se utiliza para las salidas físicas.

   Para solucionar esto, desde PB2 en adelante se desplazan las
   señales una posición:

       Resultado bit 0 -> PB0
       Resultado bit 1 -> PB1
       Resultado bit 2 -> PB3
       Resultado bit 3 -> PB4
       Resultado bit 4 -> PB5
       Resultado bit 5 -> PB6
       Resultado bit 6 -> PB7
       Resultado bit 7 -> PB8
       Carry            -> PB9

   PB2 permanece configurado como salida, pero queda sin utilizar.

   SECUENCIA:

       Pulsación 1 -> Captura Dato A
       Pulsación 2 -> Captura Dato B
       Pulsación 3 -> Realiza y muestra la suma
       Pulsación 4 -> Reinicia el proceso
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
   DIRECCIONES DE REGISTROS
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
.equ GPIOB_ODR,       0x40010C0C


/* ---------------- GPIOC ---------------- */

.equ GPIOC_CRH,       0x40011004
.equ GPIOC_IDR,       0x40011008
.equ GPIOC_ODR,       0x4001100C



/* ====================================================================
   RESET HANDLER
   ==================================================================== */

Reset_Handler:


/* ====================================================================
   MAIN
   ==================================================================== */

main:

    /* ---------------------------------------------------------------
       Deshabilitar interrupciones durante la inicialización
       --------------------------------------------------------------- */

    cpsid i



    /* =================================================================
       1. HABILITAR RELOJ PARA AFIO, GPIOA, GPIOB Y GPIOC

       Bit 0 -> AFIO
       Bit 2 -> GPIOA
       Bit 3 -> GPIOB
       Bit 4 -> GPIOC
       ================================================================= */

    LDR R0, =RCC_APB2ENR

    LDR R1, [R0]

    ORR R1, R1, #(1 << 0)
    ORR R1, R1, #(1 << 2)
    ORR R1, R1, #(1 << 3)
    ORR R1, R1, #(1 << 4)

    STR R1, [R0]



    /* =================================================================
       2. DESHABILITAR JTAG

       Se libera PB3 y PB4 para utilizarlos como GPIO.

       SWJ_CFG = 010

       JTAG  -> deshabilitado
       SWD   -> habilitado
       ================================================================= */

    LDR R0, =AFIO_MAPR

    LDR R1, [R0]

    BIC R1, R1, #(0x7 << 24)

    ORR R1, R1, #(0x2 << 24)

    STR R1, [R0]



    /* =================================================================
       3. CONFIGURAR PA0-PA7 COMO ENTRADAS DIGITALES FLOATING

       0x44444444
       ================================================================= */

    LDR R0, =GPIOA_CRL

    LDR R1, =0x44444444

    STR R1, [R0]



    /* =================================================================
       4. CONFIGURAR PB0-PB7 COMO SALIDAS PUSH-PULL 2 MHz

       PB2 también queda configurado como salida, tal como se hizo
       en CubeMX, aunque no se utiliza físicamente.

       0x22222222
       ================================================================= */

    LDR R0, =GPIOB_CRL

    LDR R1, =0x22222222

    STR R1, [R0]



    /* =================================================================
       5. CONFIGURAR PB8, PB9, PB13, PB14 Y PB15 COMO SALIDAS

       PB8  -> Resultado bit 7
       PB9  -> Carry
       PB13 -> LED D1
       PB14 -> LED D2
       PB15 -> LED D3

       PB10, PB11 y PB12 quedan sin utilizar.

       0x22200022
       ================================================================= */

    LDR R0, =GPIOB_CRH

    LDR R1, =0x22200022

    STR R1, [R0]



    /* =================================================================
       6. CONFIGURAR PC13 COMO ENTRADA PULL-UP

       PC13 se encuentra en GPIOC_CRH.

       MODE = 00
       CNF  = 10

       Configuración = 0x04
       ================================================================= */

    LDR R0, =GPIOC_CRH

    LDR R1, [R0]

    /* Limpiar configuración de PC13 */

    BIC R1, R1, #(0x0F << 20)

    /* Configurar PC13 como entrada Pull-Up/Pull-Down */

    ORR R1, R1, #(0x04 << 20)

    STR R1, [R0]



    /* =================================================================
       7. ACTIVAR PULL-UP EN PC13

       ODR = 1 -> Pull-Up
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

       Limpiar todas las salidas del Puerto B.

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
       Esperar primera pulsación
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
       Apagar LED D1
       Encender LED D2

       PB13 = 0
       PB14 = 1
       --------------------------------------------------------------- */

    LDR R0, =GPIOB_ODR

    LDR R1, =(1 << 14)

    STR R1, [R0]



/* ====================================================================
   PASO 3: CÁLCULO DE LA SUMA
   ==================================================================== */


    /* ---------------------------------------------------------------
       Esperar tercera pulsación
       --------------------------------------------------------------- */

    BL esperar_pulsacion



    /* ---------------------------------------------------------------
       Sumar Dato A + Dato B

       R4 = Dato A
       R5 = Dato B
       R6 = Resultado

       ADDS actualiza el Carry.
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
       --------------------------------------------------------------- */

    AND R6, R6, #0xFF



/* ====================================================================
   PASO 3.1: CONSTRUIR EL MAPEO FÍSICO DEL RESULTADO
   ====================================================================

   El resultado lógico es:

       R6 bit 0
       R6 bit 1
       R6 bit 2
       R6 bit 3
       R6 bit 4
       R6 bit 5
       R6 bit 6
       R6 bit 7

   Pero PB2 no está disponible físicamente.

   Por lo tanto:

       R6 bit 0 -> PB0
       R6 bit 1 -> PB1

       R6 bit 2 -> PB3
       R6 bit 3 -> PB4
       R6 bit 4 -> PB5
       R6 bit 5 -> PB6
       R6 bit 6 -> PB7
       R6 bit 7 -> PB8

       R7 bit 0 -> PB9
                  (Carry)

   ==================================================================== */


    /* ---------------------------------------------------------------
       R1 será el valor final que enviaremos a GPIOB_ODR.

       Comenzamos en cero.
       --------------------------------------------------------------- */

    MOV R1, #0



    /* =================================================================
       BIT 0 DEL RESULTADO -> PB0
       ================================================================= */

    AND R2, R6, #0x01

    ORR R1, R1, R2



    /* =================================================================
       BIT 1 DEL RESULTADO -> PB1
       ================================================================= */

    AND R2, R6, #0x02

    ORR R1, R1, R2



    /* =================================================================
       BITS 2-7 DEL RESULTADO

       Los bits 2-7 deben desplazarse una posición hacia la izquierda.

       Original:

           R6 bit 2 -> posición 2
           R6 bit 3 -> posición 3
           ...
           R6 bit 7 -> posición 7

       Después de LSL #1:

           posición 3 -> PB3
           posición 4 -> PB4
           ...
           posición 8 -> PB8
       ================================================================= */

    AND R2, R6, #0xFC

    LSL R2, R2, #1

    ORR R1, R1, R2



    /* =================================================================
       CARRY -> PB9

       R7 contiene:

           0 -> no hubo Carry
           1 -> hubo Carry

       Desplazamos 9 posiciones:

           R7 bit 0 -> PB9
       ================================================================= */

    LSL R7, R7, #9

    ORR R1, R1, R7



    /* =================================================================
       ENCENDER LED D3

       PB15 = 1

       D1 y D2 quedan apagados.
       ================================================================= */

    ORR R1, R1, #(1 << 15)



    /* =================================================================
       ESCRIBIR RESULTADO EN GPIOB
       ================================================================= */

    LDR R0, =GPIOB_ODR

    STR R1, [R0]



/* ====================================================================
   PASO 4: REINICIO DE LA SECUENCIA
   ==================================================================== */


    /* ---------------------------------------------------------------
       El resultado permanece visible.

       Esperar cuarta pulsación.
       --------------------------------------------------------------- */

    BL esperar_pulsacion



    /* ---------------------------------------------------------------
       Volver al inicio.

       Se limpian nuevamente las salidas y se comienza otra suma.
       --------------------------------------------------------------- */

    B inicio_proceso



/* ====================================================================
   BUCLE INFINITO DE SEGURIDAD
   ==================================================================== */

bucle_espera:

    B bucle_espera



/* ====================================================================
   SUBRUTINA: esperar_pulsacion

   El pulsador PC13 funciona con Pull-Up:

       PC13 = 1 -> botón sin presionar
       PC13 = 0 -> botón presionado

   La rutina espera:

       1. Presionar
       2. Antirrebote
       3. Soltar
       4. Antirrebote

   Después retorna al programa principal.
   ==================================================================== */

esperar_pulsacion:


    /* ---------------------------------------------------------------
       Cargar dirección del registro GPIOC_IDR
       --------------------------------------------------------------- */

    LDR R0, =GPIOC_IDR



/* ====================================================================
   ESPERAR PRESIONAR
   ==================================================================== */

esperar_cero:


    LDR R1, [R0]



    /* ---------------------------------------------------------------
       Comprobar PC13
       --------------------------------------------------------------- */

    TST R1, #(1 << 13)



    /* ---------------------------------------------------------------
       Si PC13 = 1:

       El botón todavía no ha sido presionado.
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
   ESPERAR SOLTAR
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
