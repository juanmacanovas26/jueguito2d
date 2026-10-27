# Roadmap

La regla: **una milestone a la vez, cada una con un criterio de "terminado"
que se pueda verificar jugando.** El editor se toca solo cuando un mapa concreto
lo bloquea; lo que "estaría bueno" va a una lista.

La milestone actual es **M1**, y su diseño está en
[`ZONA_INICIAL.md`](ZONA_INICIAL.md).

## Diagnóstico: por qué se siente estancado

- **Mucha herramienta, poco juego.** Unas 15.000 líneas del editor de mundo
  (`scripts/world`, `addons`, `tools/`) contra unas 4.200 de combate, player y
  enemigos. Desde fines de septiembre casi todos los commits son de tooling, y
  la sección de Housing del GDD es en su mayoría un registro de fixes.
- **La zona de "Nuevo Juego" todavía no tiene juego.** En la versión subida,
  `praderas_del_alba.tscn` tiene casas y pintura pero ningún marker de mob ni
  de recurso; los que hay están en `pradera.tscn`, la zona de prueba.
- **Las casas.** Solo `house_small_a` tiene escena con collider, y ese collider
  cubre solo la pared. No hay Y-sort en el proyecto.
- **Una sola IA de enemigo** (`chase_mob.gd`). El combate tiene buena base
  (animation-lock, GCD, parry, dodge), pero ningún enemigo obliga a usarlo.
- **`DEBUG_GIVE_EVERYTHING := true`** en `player.gd`: la progresión no se
  puede sentir.

## Milestones

### M0 — Congelar el editor (días)
- Sin pinceles ni categorías nuevas; las ideas van a una lista.
- Sacar el registro de fixes del GDD a un `CHANGELOG.md`, para que el GDD
  vuelva a ser diseño.

### M1 — Zona jugable ← actual
- Y-sort y colliders de los edificios que se usan.
- Blockout de Praderas del Alba (el cuadrante (0,0)), calibrar, después decorar.
- `DEBUG_GIVE_EVERYTHING` en false y log de progresión.

**Terminado cuando:** Nuevo Juego → 20 minutos de farm, loot, craft y equipar,
sin teclas de debug ni atravesar nada.

### M2 — Enemigos y combate
- Separar la IA en piezas reutilizables (movimiento, ataque con telegraph,
  poise) en vez de seguir creciendo `chase_mob.gd`.
- 3–4 arquetipos: melee, a distancia, embestida con telegraph que obliga a
  esquivar, pesado con poise que obliga a usar heavy o guard.
- El Rey Slime con 2–3 patrones. Después: hitstop, shake, sonido.

**Terminado cuando:** contra el jefe, el que spamea click pierde contra el que
esquiva y castiga (el test de `COMBATE.md`).

### M3 — Prueba de red (~2 semanas, acotada)
- 2 clientes por ENet: moverse, pegarle a un mob sincronizado, que caiga loot.
- No es para dejarlo terminado: es para ver qué parte del "contrato de
  netcode-readiness" (`ARQUITECTURA.md`) no aguanta, mientras el código todavía
  es chico.

### M4 — NPCs y economía
- Componente "interactuable" (tecla E), compartido con la puerta.
- Vendedor, herrero con estación de craft, tablón de encargos.
- Diálogos como datos (JSON o Resources), no hardcodeados.

**Terminado cuando:** el loop de M1 tiene un para qué: vender, comprar,
cumplir un encargo.

### M5 — Pasada de UI
- Un tema único, inventario en grilla con tooltips, equipo, barras, pausa.
- Va recién acá, cuando ya existen los flujos que tiene que mostrar.

### M6 — Housing
- Comprar un lote. El tamaño del lote (chico, mediano, grande, finca) fija el
  tier máximo de la casa: ver `ZONA_INICIAL.md`.
- Interior con muebles sobre grilla y cofres como almacenamiento real.
- Subir de tier e impuesto, después.

### M7 — Segundo cuadrante
- El cuadrante vecino de Praderas del Alba, con una mazmorra corta, como escena
  propia de 8000 × 6000 con los bordes coincidiendo.
- Pasar de un cuadrante a otro al cruzar el borde.
- Si un cuadrante sale en días y no en semanas, el editor rindió.

## Por qué este orden

M1 y M2 dan algo para jugar y juzgar. M3 baja el riesgo técnico antes de
apilar más sistemas. M4 y M5 convierten el prototipo en juego. M6 y M7 son el
contenido que promete el MVP del GDD.
