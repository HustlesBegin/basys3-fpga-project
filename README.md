# Proyecto Basys3 – Sistema de Autenticación y Juego Adivina el Número (VHDL)
Proyecto en VHDL para implementar un sistema completo de autenticación y juego tipo “adivina el número” en la tarjeta Basys3. Incluye arquitectura estructural, módulos independientes, FSM, LFSR pseudoaleatorio, temporizadores y multiplexado de displays de 7 segmentos.

## 1. Descripción del Proyecto
El sistema está dividido en dos módulos principales:

### Módulo 1 – Autenticación
Permite:
- Configurar una clave de 4 bits mediante los switches.
- Guardar la clave con BTNC.
- Verificar la clave en modo de autenticación.
- Contar intentos (3 intentos).
- Bloquear el sistema 30 segundos después de tres fallos.
- Pasar automáticamente al Módulo 2 al ingresar la clave correcta.

### Módulo 2 – Juego “Sube/Baja/Oh”
- Genera un número pseudoaleatorio de 4 bits usando un LFSR.
- El usuario tiene 5 intentos para adivinarlo.
- Muestra mensajes en display: SUBE, BAJA u OH.
- Si falla los 5 intentos, muestra FAIL por 3 segundos y luego bloquea 15 segundos.
- Después del bloqueo inicia una nueva ronda.

---

## 2. Arquitectura del Sistema
El diseño usa arquitectura estructural en el `TOP.vhd`, donde se integran:
- **auth_block**
- **game_block**
- **clk_divider**
- **sec_timer**
- **attempt_counter_auth**
- **key_storage**
- **key_checker**
- **rnd4_lfsr**
- **game_comparator**
- Multiplexado del display.

Cada módulo se instancia explícitamente y se conecta mediante señales internas, siguiendo buenas prácticas de diseño jerárquico.

---

## 3. Estructura del Repositorio
```
/src
   auth_block.vhd
   game_block.vhd
   clk_divider.vhd
   sec_timer.vhd
   attempt_counter_auth.vhd
   key_checker.vhd
   key_storage.vhd
   rnd4_lfsr.vhd
   game_comparator.vhd
   TOP.vhd

/testbench
   tb_clk_divider.vhd
   tb_sec_timer.vhd
   tb_attempt_counter_auth.vhd
   tb_key_checker.vhd
   tb_key_storage.vhd
   tb_rnd4_lfsr.vhd
   tb_game_comparator.vhd
   tb_game_block.vhd
   tb_auth_block.vhd
   tb_top.vhd

/docs
   diagramas y capturas de simulación
```

---

## 4. Funcionamiento del LFSR (Pseudoaleatorio)
El número secreto del juego se genera mediante:
```
x^4 + x^3 + 1
```
Esto produce una secuencia máxima de 15 valores diferentes (excepto 0000).  
El LFSR avanza en cada ciclo y el módulo captura un valor en el momento de iniciar la ronda, garantizando variaciones reales en FPGA.

---

## 5. Simulaciones
Se incluyen testbenches para cada módulo.  
Cada TB demuestra:

- Comportamiento de FSM
- Contadores y temporizadores
- Lógica de comparación
- Multiplexado de display
- Pseudoaleatoriedad del LFSR
- Integración en el TOP

---

## 7. Instrucciones de Síntesis (Basys3 – Vivado)
1. Crear proyecto en Vivado.
2. Importar todos los archivos VHDL del módulo `/src`.
3. Configurar `TOP.vhd` como top module.
4. Asignar pines según el archivo XDC de Basys3:
   - CLK100MHZ
   - BTNC, BTNL, BTNR
   - SW0–SW3
   - LED0–LED15
   - AN0–AN3
   - SEG0–SEG6
5. Sintetizar, implementar, generar bitstream y programar.
