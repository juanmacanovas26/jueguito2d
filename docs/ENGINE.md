# Godot vs Unity — decisión

## Recomendación: **Godot 4.x**

Para *este* juego (2D, action combat, MMO más adelante, equipo chico/solo), **Godot conviene más que Unity** como default.

### Por qué Godot gana acá

| Criterio | Godot 4 | Unity |
|----------|---------|--------|
| 2D nativo | Excelente (tiles, lights, physics 2D) | Bueno pero más “3D-first” |
| Peso / iteración | Editor liviano, proyecto simple | Más pesado |
| Costo / licencia | MIT, sin royalties | Runtime fee / términos variables (dolor de cabeza) |
| Multiplayer | Integrado (ENet, etc.) OK para slice y mid | Muy maduro (Netcode/NGO/Mirror/FishNet) |
| Pixel / action 2D | Escena tree + Area2D = hitboxes naturales | Igual de capaz, más boilerplate |
| Ownership del proyecto | Alto | Atado a Hub/ToS |
| Curva para MMO grande | Hay que construir más backend | Más ecosistema enterprise |
| C# | Soporte oficial | Nativo |
| GDScript | Ideal para prototipar combate rápido | — |

### Cuándo elegirías Unity

- Equipo que **ya** domina Unity y va a shippear en 3 meses
- Necesitás ecosistema maduro de networking third-party ya armado
- Target fuerte a consolas con pipeline Unity ya pagado
- Preferís C# only y tools de animación/Mecanim que ya conocés

### Cuándo Godot duele

- CCU masivo / sharding serio: vas a querer **servidor dedicado fuera del game client** (Rust/Go) igual que en Unity
- Assets store de MMO “plug and play” es más chico
- Algunas integraciones Steam/middleware tienen menos tutoriales que Unity

**Conclusión:** el cuello de botella de un MMORPG no es el engine 2D; es **scope, netcode y contenido**. Godot te deja llegar al vertical slice de combate más rápido y sin fricción de licencia. Si el juego crece, el game server se puede desacoplar sin tirar el cliente.

## Versión a instalar

- **Godot 4.3+ o 4.4/4.5 estable** (Standard)
- Si más adelante querés C# estricto: build **.NET** de Godot
- Para el slice: **GDScript está perfecto**

## Instalación (Windows)

1. https://godotengine.org/download/windows/
2. Bajá **Godot 4.x Standard** (zip, portable — no necesita instalador)
3. Extraé a p.ej. `C:\Godot\` y creá acceso directo
4. (Opcional) Godot en PATH o launcher
5. Abrí el editor → New Project en `C:\Users\Juanma\Desktop\Jueguito2D\game`  
   - Renderer: **Forward+** o **Compatibility** (Compatibility = PCs más flojas; para 2D pixel suele sobrar)

## Estructura de repo sugerida

```
Jueguito2D/
  docs/           # GDD y diseño (ya creado)
  game/           # Proyecto Godot (a crear)
  server/         # Más adelante si se separa
  tools/          # scripts de data, export
```

## Primer hito técnico post-install

1. Proyecto Godot `game/`
2. Personaje CharacterBody2D + movimiento WASD
3. Dodge + stamina
4. Attack animation-lock + hitbox Area2D
5. Un slime dummy

Eso valida el pilar de combate antes de cualquier MMO stack.
