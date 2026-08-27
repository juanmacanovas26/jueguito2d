# GDD — MMORPG 2D Grind/Farm (Working Title)

> Ver `docs/IDEAS2608.md` para el análisis completo detrás de la progresión emergente, la construcción persistente y la capa roguelite (secciones §2-5). Este documento resume las decisiones accionables; ese otro documenta el porqué y los riesgos con detalle.

## Visión

MMORPG 2D de grindeo y farmeo puro. Combate **action-fighter** (movimiento libre, hitboxes, dodge) con alma **Imperium AO** (PvP skill-based, builds, magia, clanes, economía). Estética medieval fantástica con toques cozy/anime.

**Pitch:** Cada hora de juego se siente en el inventario, el craft y el mapa. Peleas se ganan con aim, dodge y lectura — no spameando click. El personaje no se elige de un menú: se convierte en algo por cómo se juega, y ese algo queda anclado al mundo por lo que construyó.

### Tres pilares

1. **El grind recompensa** — drops, skills por uso, craft, metas cercanas
2. **Combate action-skill** — aim, dodge, animaciones; anti click-race
3. **Mundo Imperium-like con anclaje persistente** — social, riesgo, economía, clanes, casas + construcción libre con claims (estilo Rust)

---

## Referentes

| Juego | Tomar | Evitar |
|--------|--------|--------|
| Imperium AO / AO | PvP, clanes, oficios, economía, WASD-rooted culture | Tile rígido, delay abstracto sin animación |
| Hades / Dead Cells | Feel de hit, dodge, telegraphs; "1 de 3" al descubrir poder | Roguelike como estructura principal (acá no hay runs desechables) |
| OSRS | Skilling, rareza, metas largas | UI legacy |
| Stardew | Casas, cozy, ciclo día/noche | Ritmo 100% pacífico |
| Ultima Online | Progresión por uso, cap total de skills, sin clases cerradas | Menús de macro/UI datados |
| Rust | Construcción persistente con claims, decay/upkeep como válvula de escape | Wipes forzados mensuales (acá no hay wipe plan por defecto) |

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

### Arquetipos y progresión emergente

No hay clases cerradas: el arquetipo es punto de partida, no techo. Detalle completo en `docs/IDEAS2608.md` §3.

| Arquetipo base | Fantasy de partida | Límite de combate | Destinos posibles (emergentes) |
|-------|---------|--------|--------|
| Guerrero | Combos, poise, block/parry | Heavy lento, stamina | Tanque, Berserker, Bruiser, Clérigo (con magia curativa) |
| Mágico | Skillshots, AoE, blink corto | Cast + maná | Mago clásico, Nigromante, Druida, Clérigo, Sanador |
| Rogue | Aim, kite, traps, sigilo | Draw/reload animado | Arquero, Asesino, Domador de criaturas |

El arquetipo fija stats iniciales y acceso más barato a ciertas ramas de la red de skills; **no fija un techo**.

**Mecánica:**

- **Uso, no puntos:** las skills suben según cuánto se usan (pegar con espada sube "Espadas Pesadas", castear fuego sube "Piromancia"), no por asignación al subir de nivel.
- **Cap total de skills activas** por personaje (ref. Ultima Online, orden de ~700 pts, número exacto por calibrar): para subir una skill nueva en el tope hay que bajar otra. Fuerza especialización sin diseñarla a mano.
- **Red de skills abierta**, no árbol de clase cerrado: cualquier personaje puede aprender cualquier skill, más caro/lento si no es de su arquetipo. Así emergen los híbridos (Guerrero + magia curativa → Clérigo).
- **Descubrimiento:** tomos/pergaminos raros en el mundo, NPCs maestros condicionales (reputación/quest/build actual), "despertar" por combos de uso (mucho daño físico + fuego → skill híbrida nueva, ej. "Filo Incandescente").
- **Títulos emergentes** (Tanque, DPS a pecho descubierto, Clérigo...) al cruzar umbrales de build — cosmético/narrativo, **sin pasivo mecánico** (si llevaran pasivo, reabren el problema del meta).
- **Poder horizontal obligatorio:** con PvP confirmado, ninguna skill puede ser estrictamente superior a otra en todo contexto — fuerte en situaciones distintas, no "número más grande". Sin esto el PvP se rompe y toda la red queda decorativa salvo la build dominante.

**Capa roguelite (aleatoriedad controlada, `docs/IDEAS2608.md` §4):**

- Cada descubrimiento dispara un **roll independiente** en el momento en que ocurre, ponderado por el build actual — nunca un pool fijado al crear el personaje (un mal roll de nacimiento incentivaría tirar el personaje, y acá el personaje tiene casa/gremio/economía invertidos: ver Housing).
- Elección **"1 de 3"**: agencia real + ponderación por sinergia con lo que el jugador ya viene usando.
- **Núcleo garantizado**: 3–4 skills básicas del arquetipo siempre disponibles sin roll — el personaje es jugable pase lo que pase.
- **Wildcards raros** en drops/eventos, fuera de la ponderación normal (motor de historias tipo "encontré un tomo rarísimo y ahí arrancó mi build").
- **Válvulas de escape:** reroll limitado obtenido por logro/juego (**nunca cash shop** — sería pay-to-win directo sobre progresión), ventana de gracia con 1-2 rerolls gratis en niveles bajos.

### Ritmo objetivo

- 1v1: 10–40s legible
- PvE pack: 2–5s satisfactorio
- Boss: patterns action + mecánicas MMO
- Teclas pocas: M1, M2, Dodge, 3–5 skills, 1 ult

### PvP / mundo

- Zonas Safe / Contested / Full PK
- Clanes (fundación difícil: gente + ítems especiales), claims, wars (post-MVP)
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

**Implementado (prototipo) — progresión por uso:** no hay nivel de personaje ni
XP genérica; el poder es 100% la suma de skills (`game/scripts/player/skills.gd`).
Matar/craftear/recolectar suben la skill correspondiente (Espadas Pesadas,
Hechicería, Puntería, Tala, Minería, Herrería), con rendimientos decrecientes
cerca del cap individual (100) y un cap total compartido (700, por calibrar)
que fuerza a especializar. Toda ganancia también suma una fracción a
Vitalidad, de la que deriva el HP máximo. Todavía sin: rendimientos
decrecientes contextuales (grindear en un dummy sube igual).

**Implementado (prototipo) — red abierta de skills:** las abilities
casteables ya no están fijas por kit: `Player.known_abilities`
(`game/scripts/player/player.gd`) es lo que un personaje realmente conoce,
sembrado con el default del kit (`SkillDB.LOADOUTS`) al spawnear.
`learn_ability(id)` deja aprender una skill ajena al kit sin sacar las que ya
tenía. Q/E/F sigue siendo un toggle libre de testing (no la elección de
personaje final, que va a llegar con un creador de personaje real): cambiar
de kit en vivo resetea `known_abilities` y la progresión a los defaults del
kit nuevo, así cada uno se prueba desde cero en vez de acumular cross-kit.
Cargar una partida guardada no dispara ese reset. Todavía sin: costo/afinidad
real de aprender fuera de tu arquetipo (no hay arquetipo de partida
persistente todavía, sólo el kit actual — vuelve relevante recién con el
creador de personaje), UI de reasignar qué ability va en qué slot.

**Implementado (prototipo) — descubrimiento "1 de 3":** cruzar 25/50/75
puntos en una skill de combate (Espadas Pesadas/Hechicería/Puntería) dispara
`Game.discovery_offered` con 3 abilities que el personaje todavía no conoce,
ponderadas por afinidad con el kit actual (`Player._discovery_candidates()`,
`SkillDB.kit_of()`) — hoy con sólo 7 abilities en 3 kits sin solapamiento
esa ponderación no tiene efecto visible en la práctica (un kit siempre
conoce sus propias abilities desde el spawn), pero la mecánica está lista
para cuando haya más contenido por kit. El panel (`hud.gd`'s DiscoveryPanel)
deja elegir una o descartar sin costo. Todavía sin: núcleo garantizado como
concepto propio (hoy es un efecto lateral de que el kit siempre arranca con
sus defaults conocidos), wildcards raros fuera de la ponderación normal,
rerolls, tomos/maestros como fuente alternativa de descubrimiento.

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

### Housing y construcción persistente

Dos sistemas de costo muy distinto (detalle en `docs/IDEAS2608.md` §2.2-2.4):

- **Housing urbano (cozy), instanciado**: como un dungeon, solo carga cuando alguien entra — casi no pesa sobre el mundo abierto. Interior editable, cofres, craft bonus, display, visitas public/guild/private. Estética anime-cozy: emotes, pets cosméticos, día/noche.
- **Construcción libre + claims fuera de ciudad** (ref. Rust): estructuras persistentes en mapa abierto, existen aunque nadie esté cerca. Reglas no negociables **desde el día 1**, no como pulido posterior:
  - **Decay/upkeep**: sin upkeep pagado o claim inactivo X días → degrada y eventualmente se borra. Es la válvula de escape estructural; sin esto el mundo no entra en RAM al mes 2 (parámetros exactos por calibrar).
  - **Simulación por proximidad**: no calcular físicas/colisión de una estructura sin jugadores cerca.
  - **Indexado espacial** (grid/quadtree) para consultas de "qué hay cerca de este jugador" — retrofitearlo después es doloroso.
  - **Guardado incremental y asíncrono**, nunca un snapshot completo que bloquee el loop.
  - **Límite de piezas** por claim, para acotar el peor caso.
- **Claims exclusivos de clanes**: ningún jugador individual —sin importar cuántos personajes o slots tenga— puede reclamar tierra fuera de ciudad. Solo un clan puede. Esto vuelve irrelevante el riesgo de pay-to-win vía slots (el territorio nunca se compra directamente, se gana organizándose) y además reduce la cantidad total de claims en el mundo, lo que ayuda al presupuesto de RAM de §2.2.
- **Fundar un clan es difícil a propósito**: no alcanza con juntar gente. Además hace falta conseguir ítems especiales (fuente por definir: drop raro de mundo/boss, crafteo, quest — **nunca comprable**, para no reabrir el pay-to-win por otra puerta). El costo de fundación es la verdadera barrera de entrada al territorio.
- El **housing urbano instanciado sigue siendo por cuenta**, sin cambios — es el sistema barato al que cualquiera accede sin necesidad de clan. Ver Economía.

---

## Economía y monetización

- Gold sinks: repair, house, AH tax, teleports
- AH + trade con escrow
- Anti-dupe desde día 1 (server authoritative)
- Cash: cosméticos, battle pass cosmético, convenience no-P2W
- **Nunca:** gear de poder en cash shop, XP boost fuertes, reroll de skills
- Slots de personaje extra dan otra historia para jugar, **nunca territorio**: los claims fuera de ciudad son exclusivos de clanes y no se compran (ver Housing)

---

## MVP (primer juego de verdad)

**Incluye**

- Customización simple
- 3 arquetipos (Guerrero, Mágico, Rogue) con progresión por uso + cap + núcleo garantizado
- Descubrimiento básico ("1 de 3" en momentos clave, sin wildcards todavía)
- Combate action híbrido sólido
- 5–8 zonas + 2 dungeons
- Inventario, 80–150 items
- 4 gathering + 3 craft
- Ciudad: bank, repair, vendor
- Party + chat
- Casa simple (instanciada)

**Fuera del MVP**

- Steam Market items
- Clanes: fundación (gente + ítems especiales), claims fuera de ciudad con decay/upkeep, sieges/raideo
- Red de skills completa con todos los títulos emergentes
- Wildcards raros y economía de reroll afinada
- Monturas voladoras
- Housing AAA
- Narrativa cinematic

---

## Roadmap

| Fase | Objetivo |
|------|----------|
| 0 Preprod | GDD, art bible, engine, vertical slice design |
| 1 Slice | Move + dodge + 1 melee + 1 spell + 1 zona offline/online local |
| 2 Alpha | Servidor, 50–100 CCU test, 3 arquetipos con progresión por uso + cap, trade, 4–6 zonas, housing instanciado |
| 3 Beta | Mapa launch, PvP zones, **clanes (fundación difícil: gente + ítems especiales)** con claims persistentes exclusivos de clan y decay/upkeep desde el día 1, descubrimiento "1 de 3" + núcleo garantizado |
| 4 EA | 40–80h metas, live ops cosméticos, wildcards + economía de reroll, títulos emergentes |
| 5 Live | Expansiones, mythic Steam si economía estable, balance continuo de la red de skills abierta |

### Gate del slice

¿Es divertido grindear 2 horas y un duel 1v1? ¿El spammer pierde contra quien dodgea y puntea?

### Slice implementado (código)

- Combate action: WASD, dodge, LMB tap/hold, RMB guard, kits Warrior/Mage
- Chase mobs con AI, skills por uso al matar/recolectar/craftear, loot al piso, inventario (I), gold


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
| Sin decay desde el día 1 → el mundo no entra en RAM al mes 2 | Implementar decay/upkeep antes de abrir la construcción libre a jugadores |
| Balance de red abierta de skills con PvP, exponencialmente más difícil que clases cerradas | Poder horizontal obligatorio + aceptar que no hay balance perfecto |
| Grindeo degenerado en progresión por uso (muñecos de práctica, auto-click) | Ganancia contextual + rendimientos decrecientes |
| Cap de skills se siente punitivo al bajar una skill trabajada | Definir en implementación si baja o queda "dormida" y recuperable |
| Pocos clanes grandes acaparan todo el terreno construible | Límite de claims/piezas por clan, y costo de fundación que escale si hace falta |
| Ítems de fundación de clan mal definidos → problema de huevo y gallina (hace falta clan para conseguir territorio, pero el ítem no debería depender de ya tener territorio) | Fuente de los ítems independiente de poseer tierra: drop de mundo/boss, crafteo o quest, nunca comprable |
