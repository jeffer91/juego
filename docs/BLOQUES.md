# Plan de desarrollo por bloques

Este proyecto se construirá un bloque por chat. Cada bloque debe quedar funcional y preparar el siguiente.

## Bloques

| Bloque | Nombre | Estado |
|---:|---|---|
| 1 | Proyecto base | Creado |
| 2 | Mapa y rutas | Creado |
| 3 | Bases | Pendiente |
| 4 | Producción automática | Pendiente |
| 5 | Soldados | Pendiente |
| 6 | Movimiento por clic o toque | Pendiente |
| 7 | Combate básico | Pendiente |
| 8 | Captura de bases | Pendiente |
| 9 | Drones | Pendiente |
| 10 | IA enemiga | Pendiente |
| 11 | Victoria y derrota | Pendiente |
| 12 | Progresión de niveles | Pendiente |

## Regla principal

El juego debe mantenerse modular y ampliable. No se debe mezclar toda la lógica en un solo archivo.

Cada sistema debe poder crecer por separado:

- niveles;
- bases;
- unidades;
- grupos;
- rutas;
- combate;
- drones;
- inteligencia enemiga;
- victoria y derrota;
- interfaz.

## Último avance

El Bloque 2 creó el sistema inicial de rutas del nivel 1. Ahora el juego ya tiene puntos, segmentos de ruta y una forma de calcular el punto válido más cercano si el jugador toca fuera del camino.
