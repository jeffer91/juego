# Arquitectura del prototipo

## Datos

`ContentLoader` lee niveles, bases y unidades desde JSON. Los niveles describen puntos, conexiones, bases, dificultad y velocidad de la IA.

## Movimiento

`RouteManager` transforma los puntos y conexiones del nivel en un grafo `AStar2D`. `PathFinder` ajusta cada destino a una ruta válida y devuelve el camino que debe recorrer el grupo.

## Bases

Cada base es una escena reutilizable. `BaseSpawner` mantiene una única cantidad de unidades, produce por tiempo y notifica cualquier cambio. Las bases neutrales usan defensores; las bases conquistadas usan las unidades almacenadas como defensa.

## Unidades

`UnitGroup` representa soldados o drones. Los soldados se crean en grupos de cinco, pueden defender rutas y capturar bases. Los drones se crean individualmente, causan daño de área y no capturan.

## Coordinación

`MainGame` conecta selección, órdenes, combate, captura, inteligencia enemiga y resultados. `EnemyAI` ejecuta decisiones periódicas sin mezclar esa temporización con las unidades o las bases.

## Progresión

`GameManager` controla el estado general, pausa, victoria, derrota y progreso persistente. El avance se guarda en `user://progress.cfg`.
