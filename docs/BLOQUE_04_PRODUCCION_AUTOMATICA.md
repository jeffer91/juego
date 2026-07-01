# Bloque 4: Producción automática

## Objetivo

Agregar producción automática a las bases.

Este bloque todavía no crea soldados caminando por el mapa. Lo que hace es acumular unidades dentro de cada base para preparar el Bloque 5, donde esas unidades ya se convertirán en soldados reales.

## Qué se creó

- `scripts/bases/BaseSpawner.gd`

## Qué se actualizó

- `scenes/bases/Base.tscn`
- `scripts/bases/Base.gd`
- `scripts/core/MainGame.gd`

## Regla de producción

Una base produce unidades solo si pertenece a un equipo activo.

| Estado de base | Produce |
|---|---|
| Azul / jugador | Sí |
| Roja / enemigo | Sí |
| Gris / neutral | No |

## Producción inicial

En este momento:

- la base azul produce soldados automáticamente;
- la base roja produce soldados automáticamente;
- las bases grises muestran defensores, pero no producen;
- cuando más adelante una base gris sea conquistada, podrá empezar a producir.

## Indicadores visuales

Cada base muestra un texto encima:

| Texto | Significado |
|---|---|
| `S: 0` | Soldados acumulados |
| `D: 0` | Drones acumulados |
| `Def: 5` | Defensores de una base neutral |

## Sistema modular

La producción quedó separada en `BaseSpawner.gd`.

Esto permite que después se puedan agregar más unidades sin reescribir todo.

Ejemplos futuros:

- base de soldados;
- base de drones;
- base de carritos;
- base de tanques;
- base de soldados rápidos.

Cada base podrá tener su propio tiempo de producción.

## Tiempos iniciales

| Unidad | Tiempo sugerido |
|---|---:|
| Soldado | cada 3 segundos |
| Dron | cada 7 segundos |
| Carrito futuro | cada 8 segundos |

## Preparación para el siguiente bloque

El Bloque 5 debe crear soldados reales.

La base ya acumula unidades. El siguiente paso será convertir esas unidades acumuladas en grupos visibles que puedan moverse por las rutas.
