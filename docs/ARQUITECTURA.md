# Arquitectura técnica

## Decisión de engine

**Godot 4.x** (ver `docs/ENGINE.md`).

---

# Contrato de netcode-readiness (OBLIGATORIO)

Todo el código se escribe para que el paso a servidor autoritativo sea **rápido y sin romper nada**.
Estas reglas son la "costura" donde después se enchufa el netcode.

## 1. La simulación es dueña del estado; la presentación solo lo lee

- **Estado** (dueño): `Health`, `Inventory`, `Progress`, posición, `Kit`/`DefendStyle`.
- **Presentación** (solo lee): `Polygon2D` (colores), `FloatingText`, `Hitbox` debug, HUD.
- Prohibido: que un nodo visual decida daño/loot/vida. El daño se calcula en scripts de lógica
  (`Health.take_damage`, `Hitbox`, `Projectile`) y la UI escucha señales.

## 2. Lógica en `_physics_process` (tick fijo), nunca en `_process`

Combate, movimiento, cooldowns y recolecta viven en `_physics_process` (timestep fijo = el "tick"
que el servidor puede reproducir). `_process` es solo para animación cosmética (bob, fade).

## 3. Acceso a mundo y entidades SOLO por `Game` (autoload)

- **Prohibido:** `get_tree().current_scene`, `get_nodes_in_group("player")`.
- **Permitido:** `Game.get_world()`, `Game.get_local_player()`, `Game.spawn()`.
- En netcode, `get_local_player()` se convierte en "mi entidad por id de red", y `spawn()` en un
  mensaje de spawn del servidor. No hay que tocar el resto.

## 4. Todo spawn dinámico pasa por `Game.spawn()`

Loot, proyectiles, textos flotantes — cualquier nodo creado en runtime se crea con `Game.spawn(scene, pos)`.
Ahí se emitirá el RPC de spawn cuando exista red.

## 5. Comunicación entre sistemas por señales

El daño, el inventario y los toasts ya viajan por señales de `Game` (`player_stats_changed`,
`inventory_changed`, `toast_msg`). Mantener este patrón: los sistemas no se llaman directo entre sí.

## 6. Random por `Game` (servidor como única fuente)

- Regla a futuro: usar `Game.randf()`, `Game.randi_range()` en vez de `randf()`/`randi_range()` globales,
  para que el servidor sea la única fuente de aleatoriedad (drops, críticos, miss).
- Hoy el código mezcla ambos; ir migrando progresivamente.

## 7. Inputs como comandos (a futuro)

La intención del jugador (move dir, ataque, dodge) se captura como **datos** (Vector2 / enums),
no como efectos directos. Hoy ya se hace en `_get_move_input()` y los `_try_*`. El paso siguiente
será empaquetar esos comandos y reejecutarlos en el server.

---

## Plan de migración al netcode (cuando toque)

1. **Snapshots de estado**: serializar `Health`/`Inventory`/`Progress`/posición → un `StateSync` por entidad.
2. **Comandos de input**: empaquetar move/attack/dodge y enviarlos al server a tick fijo.
3. **Server headless**: correr el mismo `world_zone` sin render; el cliente solo interpola.
4. **Spawn/despawn**: `Game.spawn()` emite RPC; los entities se registran por id.
5. **Autoridad de daño/loot**: mover `Hitbox`/`Projectile`/`LootDrop` al server; cliente solo predice.

---

## Visión de sistema (objetivo)

```
[Cliente Godot]  ←→  [Game Server autoritativo]  ←→  [PostgreSQL]
      ↓                       ↓
  Steamworks              Redis (sesiones, AH, presencia)
```

- **100% server-authoritative** en combate, inventario, loot, trade.
- Cliente predice movimiento/dodge y reconcilia.
- Data-driven: items, mobs, spells en JSON/DB.

## Stack sugerido

| Capa | Opción |
|------|--------|
| Cliente | Godot 4 (GDScript) |
| Server | Godot headless (slice) → Rust/Go cuando escale |
| DB | PostgreSQL (+ Redis) |
| Auth | Steamworks + cuenta propia |
| Net | ENet/WebRTC, tick fijo |

## Estructura de repo

```
game/           # cliente + simulación
  autoload/game.gd   # seam central (world/entidades/spawn/rng)
  scripts/combat/    # lógica pura (Health, Hitbox, Hurtbox, Projectile)
  scripts/player/    # estado del jugador (Inventory, Progress)
  scripts/world/     # zone, resource nodes, loot
  scripts/ui/        # solo lectura + inputs
docs/
server/         # futuro servidor desacoplado
```

## Seguridad (desde día 1)

- Nunca confiar daño/loot del cliente.
- Rate limit de acciones.
- Trade con escrow.
- Logs de economía y frags (transparencia estilo Imperium).
