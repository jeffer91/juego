# Juego Conquista de Bases

Juego 2D de estrategia en tiempo real para Android, desarrollado con **Godot 4**. El jugador controla el equipo azul, conquista bases neutrales y debe tomar la base roja antes de perder la propia.

## Estado del desarrollo

Los 12 bloques principales están implementados:

1. Proyecto base.
2. Mapa y rutas.
3. Bases reutilizables.
4. Producción automática.
5. Soldados en grupos de cinco.
6. Movimiento por clic o toque.
7. Combate automático.
8. Captura de bases.
9. Drones explosivos.
10. Inteligencia enemiga.
11. Victoria y derrota.
12. Progresión y desbloqueo de niveles.

## Cómo jugar

1. Toca una base azul para seleccionarla.
2. Toca una ruta o una base como destino.
3. Las bases de soldados envían grupos completos de cinco.
4. También puedes tocar un grupo azul y darle un nuevo destino.
5. Los grupos enemigos cercanos combaten automáticamente.
6. Los drones explotan al detectar enemigos y no pueden capturar bases.
7. Conquista la base roja para ganar. Si la base azul cae, pierdes.

## Niveles incluidos

- **Nivel 1: Primer combate.** Tres rutas y una base central de drones.
- **Nivel 2: Cruce estratégico.** Rutas cruzadas, más bases neutrales e IA más rápida.

El progreso se guarda en `user://progress.cfg` y el nivel 2 se desbloquea al superar el nivel 1.

## Estructura

```text
data/
  bases/       Definiciones de bases
  levels/      Mapas y dificultad
  units/       Estadísticas de unidades
scenes/
  bases/       Escenas de bases
  main/        Escena principal
  units/       Escena de grupos
scripts/
  ai/          Inteligencia enemiga
  bases/       Producción y captura
  core/        Estado y coordinación
  data/        Carga de contenido JSON
  movement/    Rutas y búsqueda de caminos
  ui/          Interfaz del juego
  units/       Soldados y drones
```

## Cómo abrir el proyecto

1. Descarga o clona el repositorio.
2. Abre Godot 4.
3. Selecciona **Importar**.
4. Elige `project.godot`.
5. Ejecuta `scenes/main/MainGame.tscn`.

## Principio de arquitectura

El código contiene las reglas, los JSON contienen el contenido y las escenas muestran el juego. Esto permite agregar niveles, bases y unidades sin reescribir el sistema central.
