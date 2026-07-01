# Bloque 2: Mapa y rutas

## Objetivo

Crear el sistema inicial de rutas del nivel 1 para que el juego sepa por dónde se puede mover el jugador.

Este bloque todavía no mueve soldados. Solo deja preparada la lógica de caminos válidos para el siguiente bloque.

## Qué se creó

- `scripts/movement/RouteManager.gd`
- `scripts/movement/PathFinder.gd`
- `data/levels/level_01.json`

## Decisiones del nivel 1

El nivel 1 tiene:

- una base azul del jugador;
- una base roja del enemigo;
- tres bases neutrales grises;
- ruta superior;
- ruta central;
- ruta inferior.

## Bases del nivel 1

| Base | Equipo inicial | Dificultad | Produce |
|---|---|---:|---|
| Base principal izquierda | Jugador | 0 | Soldados |
| Base principal derecha | Enemigo | 0 | Soldados |
| Base neutral superior | Neutral | 1 | Soldados |
| Base neutral central | Neutral | 2 | Drones |
| Base neutral inferior | Neutral | 1 | Soldados |

## Reglas de rutas

Los grupos solo podrán moverse por rutas válidas.

Si el jugador toca fuera del camino, el sistema puede buscar el punto válido más cercano.

Esto permite que el control sea simple en Android:

1. seleccionar grupo;
2. tocar punto del camino;
3. el grupo se mueve hacia el punto válido.

## Preparación para el siguiente bloque

En el Bloque 3 se crearán las bases como escenas reales, no solo como círculos dibujados.
