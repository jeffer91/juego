# Plan de desarrollo por bloques

El prototipo funcional quedó completado en 12 bloques.

| Bloque | Nombre | Estado |
|---:|---|---|
| 1 | Proyecto base | Creado |
| 2 | Mapa y rutas | Creado |
| 3 | Bases | Creado |
| 4 | Producción automática | Creado |
| 5 | Soldados | Creado |
| 6 | Movimiento por clic o toque | Creado |
| 7 | Combate básico | Creado |
| 8 | Captura de bases | Creado |
| 9 | Drones | Creado |
| 10 | IA enemiga | Creado |
| 11 | Victoria y derrota | Creado |
| 12 | Progresión de niveles | Creado |

## Resultado funcional

- Las bases producen unidades automáticamente.
- Los soldados se organizan en grupos de cinco.
- Los grupos recorren las rutas mediante un grafo `AStar2D`.
- El combate se activa automáticamente al acercarse equipos rivales.
- Las bases cambian de propietario cuando sus defensas son superadas.
- La base central produce drones explosivos.
- La IA conquista bases neutrales, responde a grupos cercanos y avanza hacia la base azul.
- La captura de la base roja genera victoria y la captura de la azul genera derrota.
- El progreso se guarda y desbloquea el siguiente nivel.
