# GDD — MMORPG 2D Grind/Farm (Working Title)

## Visión

MMORPG 2D de grindeo y farmeo puro. Combate **action-fighter** (movimiento libre, hitboxes, dodge) con alma **Imperium AO** (PvP skill-based, builds, magia, clanes, economía). Estética medieval fantástica con toques cozy/anime.

**Pitch:** Cada hora de juego se siente en el inventario, el craft y el mapa. Peleas se ganan con aim, dodge y lectura — no spameando click.

### Tres pilares

1. **El grind recompensa** — drops, skills, craft, metas cercanas
2. **Combate action-skill** — aim, dodge, animaciones; anti click-race
3. **Mundo Imperium-like** — social, riesgo, economía, clanes, casas

---

## Referentes

| Juego | Tomar | Evitar |
|--------|--------|--------|
| Imperium AO / AO | PvP, clanes, oficios, economía, WASD-rooted culture | Tile rígido, delay abstracto sin animación |
| Hades / Dead Cells | Feel de hit, dodge, telegraphs | Roguelike como estructura principal |
| OSRS | Skilling, rareza, metas largas | UI legacy |
| Stardew | Casas, cozy, ciclo día/noche | Ritmo 100% pacífico |

**Nicho:** Action combat 2D + grind MMO + housing cozy + rare drops (Steam tradeable más adelante).

---

## Core loop

```
Login → Grind / recursos → Loot → Craft / gear / trade
     → Casa / gremio / PvP → Zona más difícil → repeat
```

Sub-loops: combat grind, gathering, craft, housing, economy, social.

---

## Combate (fusión Action + Imperium)

### Movimiento

- **WASD**, 8 direcciones / continuo (sin grilla de combate)
- Aceleración corta + fricción (peso, no slippery)
- Colisión continua
- Soft-grid opcional solo en housing/interiores
- **Dodge/roll:** i-frames ~0.15–0.25s, cuesta stamina, no spameable

### Ataque

- Botón = swing/shot ligado a **animación** (no spam de click)
- Input buffer de 1 comando; **recovery frames** al final
- Combos cortos: Light → Light → Finisher (máx ~3)
- Light / Heavy opcionales (heavy más lento, más stagger)
- Hitboxes reales en arma/proyectil
- Mouse apunta dirección de ataque y hechizos

### Magia (puente AO)

- Wind-up visible + proyectil/AoE con hitbox
- Cast: root o move-speed reducido según escuela
- Interrumpible por hit fuerte / stun
- Maná limitado (no gunner infinito)
- Telegraphs legibles en PvP

### Anti click-spam (obligatorio)

| Sistema | Rol |
|---------|-----|
| Animation-lock | DPS max lo define el arma, no el APM |
| Attack Speed del item | Duración de animación |
| Stamina | Dodge, sprint, heavies |
| GCD global corto (0.3–0.4s) | Evita cancels rotos |
| Poise / stagger | Tanks no mueren por tick spam |
| Server-auth hits | Client solo predice |
| Ranged: draw/reload + projectile speed | Aim y spacing |

```
Tiempo entre hits = max(AnimaciónArma, GCD)
```

### Clases MVP

| Clase | Fantasy | Límite |
|-------|---------|--------|
| Guerrero | Combos, poise, block/parry | Heavy lento, stamina |
| Mago | Skillshots, AoE, blink corto | Cast + maná |
| Arquero | Aim, kite, traps | Draw/reload animado |
| Clérigo | Zones, shield timed | Cast commitment |

### Ritmo objetivo

- 1v1: 10–40s legible
- PvE pack: 2–5s satisfactorio
- Boss: patterns action + mecánicas MMO
- Teclas pocas: M1, M2, Dodge, 3–5 skills, 1 ult

### PvP / mundo

- Zonas Safe / Contested / Full PK
- Clanes, wars (post-MVP)
- Muerte: definir drop de gold / items no bound en wild

---

## Progresión y farm

### Skills

- Combat por estilo o unificado
- Gathering: Mining, Woodcutting, Fishing, Herbalism, Skinning
- Craft: Blacksmith, Alchemy, Tailor, Cooking, Enchanting
- Construction (casas)
- Niveles 1–100 (soft cap + endgame)

**Regla futura — herramienta obligatoria:** cada recurso requiere su herramienta
(hacha → talar, pico → minar, etc.). Hoy el prototipo permite recolectar con
cualquier ataque; más adelante se gatilla por tool equipada + skill check.

**Diseño futuro — nodos de farm:**
- **Nodos inmortales**: no se agotan; dan recurso en **cada hit** (como depósitos).
- **Auto-farm (AFK)**: una tecla activa farmeo automático sobre el nodo.
- **Bonus manual**: clickear/golpear a mano da **+20%** de minerales vs auto-farm.
- Balance: el AFK rinde menos; el manual premia al jugador activo.

**Implementado (prototipo):** venas de hierro inmortales + auto-farm (tecla G) + bonus manual del 20%.

### Rareza de items

| Tier | Rol | Trade |
|------|-----|--------|
| Common → Epic | Power y craft | In-game |
| Legendary | Power alto / flex | Bound o trade limitado |
| Mythic Steam | Status + economía Steam | Steam Market (fase tardía) |

**Regla:** Mythic Steam no es biS obligatorio de poder. Evita P2W.

### Craft

- Estaciones ciudad + casa
- Materials + blueprint + skill
- Quality rolls, enchants mid-late

---

## Mundo

- Overworld por regiones/biomas
- MVP: 5–8 zonas, 2 dungeons, hubs
- Cada zona: packs de mobs, nodes, mini-boss, dungeon corta
- Densidad de spawn > mapa vacío gigante

### Housing (cozy)

- Plot o instancia
- Interior editable, cofres, craft bonus, display
- Visitas public/guild/private
- Estética anime-cozy: emotes, pets cosméticos, día/noche

---

## Economía y monetización

- Gold sinks: repair, house, AH tax, teleports
- AH + trade con escrow
- Anti-dupe desde día 1 (server authoritative)
- Cash: cosméticos, battle pass cosmético, convenience no-P2W
- **Nunca:** gear de poder en cash shop, XP boost fuertes

---

## MVP (primer juego de verdad)

**Incluye**

- Customización simple
- 3 clases (Guerrero, Mago, Arquero)
- Combate action híbrido sólido
- 5–8 zonas + 2 dungeons
- Inventario, 80–150 items
- 4 gathering + 3 craft
- Ciudad: bank, repair, vendor
- Party + chat
- Casa simple

**Fuera del MVP**

- Steam Market items
- Sieges
- 4ª clase completa / 20 specs
- Monturas voladoras
- Housing AAA
- Narrativa cinematic

---

## Roadmap

| Fase | Objetivo |
|------|----------|
| 0 Preprod | GDD, art bible, engine, vertical slice design |
| 1 Slice | Move + dodge + 1 melee + 1 spell + 1 zona offline/online local |
| 2 Alpha | Servidor, 50–100 CCU test, 3 clases, trade, 4–6 zonas |
| 3 Beta | Mapa launch, PvP zones, guilds, housing editable |
| 4 EA | 40–80h metas, live ops cosméticos |
| 5 Live | Expansiones, mythic Steam si economía estable |

### Gate del slice

¿Es divertido grindear 2 horas y un duel 1v1? ¿El spammer pierde contra quien dodgea y puntea?

### Slice implementado (código)

- Combate action: WASD, dodge, LMB tap/hold, RMB guard, kits Warrior/Mage
- Chase mobs con AI, XP al matar, loot al piso, inventario (I), gold, level bar


---

## Métricas

- Session > 45 min
- D1/D7 retention (metas EA ~40% / 15%)
- Dupes = 0 tolerado
- % jugadores que craftean semanalmente

---

## Riesgos

| Riesgo | Mitigación |
|--------|------------|
| Scope | Freeze MVP, slice primero |
| Netcode action PvP | Tick fijo, server auth, rewind corto |
| Dupes/bots | Authority server, telemetry |
| Burnout solo-dev | Content pipeline > features raras |
| Economía rota | Sinks + analytics |
