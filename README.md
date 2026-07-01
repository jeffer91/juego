# Juego Conquista de Bases

Juego 2D de estrategia en tiempo real, pensado para Android, desarrollado con **Godot** y organizado para trabajar también desde **Visual Studio Code**.

## Idea principal

El jugador controla el equipo azul y debe conquistar la base enemiga roja. En el mapa existen bases neutrales grises que tienen defensores. Al conquistar una base neutral, cambia al color del equipo ganador y empieza a generar unidades automáticamente.

## Estado del desarrollo

- Bloque 1: Proyecto base — creado.
- Bloque 2: Mapa y rutas — creado.
- Bloque 3: Bases — creado.
- Bloque 4: Producción automática — creado.
- Bloque 5: Soldados — pendiente.
- Bloque 6: Movimiento por clic o toque — pendiente.
- Bloque 7: Combate básico — pendiente.
- Bloque 8: Captura de bases — pendiente.
- Bloque 9: Drones — pendiente.
- Bloque 10: IA enemiga — pendiente.
- Bloque 11: Victoria y derrota — pendiente.
- Bloque 12: Progresión de niveles — pendiente.

## Herramientas recomendadas

- Godot 4.x
- Visual Studio Code
- GitHub
- Android SDK para exportar a Android más adelante

## Cómo abrir el proyecto

1. Descargar o clonar este repositorio.
2. Abrir Godot.
3. Elegir **Importar**.
4. Seleccionar el archivo `project.godot`.
5. Ejecutar la escena principal.

La escena inicial está en:

```txt
scenes/main/MainGame.tscn
```

## Avance actual

El juego ya tiene una estructura inicial con:

- escena principal;
- colores de equipos;
- tres rutas del nivel 1;
- base del jugador;
- base enemiga;
- tres bases neutrales;
- sistema inicial para detectar puntos válidos del camino;
- bases reales como escenas reutilizables;
- selección de bases por clic o toque;
- producción automática acumulada en bases azules y rojas.

## Regla del proyecto

El juego debe mantenerse modular. Cada sistema debe estar separado para poder agregar después más tipos de bases, soldados, drones, carritos, tanques y niveles sin rehacer todo el código.
