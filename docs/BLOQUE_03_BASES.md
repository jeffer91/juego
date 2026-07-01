# Bloque 3: Bases

## Objetivo

Convertir las bases del mapa en escenas reales y reutilizables, no solo círculos dibujados dentro de la escena principal.

Este bloque prepara el juego para que las bases puedan cambiar de dueño, producir unidades, tener defensores y ser capturadas en bloques posteriores.

## Qué se creó

- `scenes/bases/Base.tscn`
- `scripts/bases/Base.gd`
- `scripts/bases/BaseFactory.gd`
- `data/bases/base_soldier.json`
- `data/bases/base_drone.json`

## Qué se actualizó

- `scripts/core/MainGame.gd`

Ahora `MainGame.gd` ya no dibuja las bases directamente. En su lugar, crea bases reales usando `BaseFactory.gd`.

## Qué hace una base ahora

Cada base puede guardar:

- identificador;
- punto del mapa;
- equipo dueño;
- tipo de base;
- unidad que produce;
- dificultad;
- defensores;
- estado de selección.

## Colores

| Equipo | Color |
|---|---|
| Jugador | Azul |
| Enemigo | Rojo |
| Neutral | Gris |

## Tipos iniciales de bases

| Base | Produce | Uso |
|---|---|---|
| Base principal | Soldados | Base inicial del jugador y enemigo |
| Base de soldados | Soldados | Bases laterales neutrales |
| Base de drones | Drones | Base central más difícil |

## Selección de bases

Ahora las bases tienen un área de clic/toque. Al tocar una base, esta se marca como seleccionada.

Esto servirá más adelante para mostrar información, producción, defensores o estado de captura.

## Preparación para el siguiente bloque

El Bloque 4 debe agregar producción automática.

Una base que pertenezca al jugador o al enemigo debe empezar a generar unidades según su tipo.

Ejemplo:

- base azul produce soldados;
- base roja produce soldados;
- base gris no produce nada;
- base gris conquistada cambia de dueño y empieza a producir.
