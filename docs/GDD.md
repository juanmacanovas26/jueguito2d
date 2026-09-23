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

- **Housing urbano (cozy)**: el **interior** es instanciado —como un dungeon, solo carga cuando alguien entra—, y el **lote con su patio está en la ciudad, a la vista** (ver "el sistema de lotes" abajo). Interior editable, cofres, craft bonus, display, visitas public/guild/private. Estética anime-cozy: emotes, pets cosméticos, día/noche.
- **Construcción libre + claims fuera de ciudad** (ref. Rust): estructuras persistentes en mapa abierto, existen aunque nadie esté cerca. Reglas no negociables **desde el día 1**, no como pulido posterior:
  - **Decay/upkeep**: sin upkeep pagado o claim inactivo X días → degrada y eventualmente se borra. Es la válvula de escape estructural; sin esto el mundo no entra en RAM al mes 2 (parámetros exactos por calibrar).
  - **Simulación por proximidad**: no calcular físicas/colisión de una estructura sin jugadores cerca.
  - **Indexado espacial** (grid/quadtree) para consultas de "qué hay cerca de este jugador" — retrofitearlo después es doloroso.
  - **Guardado incremental y asíncrono**, nunca un snapshot completo que bloquee el loop.
  - **Límite de piezas** por claim, para acotar el peor caso.
- **Claims exclusivos de clanes**: ningún jugador individual —sin importar cuántos personajes o slots tenga— puede reclamar tierra fuera de ciudad. Solo un clan puede. Esto vuelve irrelevante el riesgo de pay-to-win vía slots (el territorio nunca se compra directamente, se gana organizándose) y además reduce la cantidad total de claims en el mundo, lo que ayuda al presupuesto de RAM de §2.2.
- **Fundar un clan es difícil a propósito**: no alcanza con juntar gente. Además hace falta conseguir ítems especiales (fuente por definir: drop raro de mundo/boss, crafteo, quest — **nunca comprable**, para no reabrir el pay-to-win por otra puerta). El costo de fundación es la verdadera barrera de entrada al territorio.
- El **housing urbano instanciado sigue siendo por cuenta**, sin cambios — es el sistema barato al que cualquiera accede sin necesidad de clan. Ver Economía.

#### Housing urbano — el sistema de lotes

El bullet de arriba dice *qué* es (instanciado, barato); esto dice *cómo*
funciona. Cinco piezas: lote, impuesto, tier, interior, patio.

**1. Un lote por ciudad, por cuenta.** Cada ciudad/pueblo tiene una cantidad
finita de lotes en su barrio residencial y una cuenta puede tener **como
máximo uno en cada ciudad** — no dos en la misma, ni uno por personaje. Es
por cuenta y no por personaje a propósito: si fuera por personaje, comprar
slots compraría suelo y se reabre el pay-to-win por la puerta de atrás (mismo
razonamiento que los claims de clan, ver arriba y §5.4 de IDEAS2608). El
límite por ciudad hace que expandirse sea *geográfico* — tener casa en tres
ciudades significa haber pagado tres impuestos y haberse comprometido con
tres lugares, no haber acumulado oro en uno.

Lotes finitos es lo que le da valor al sistema y lo que lo puede romper: si
las cuentas viejas nunca sueltan, la ciudad se llena y el jugador nuevo no
entra nunca. Esa es la razón de ser del impuesto.

**2. Impuesto periódico con 3 días de gracia.** El lote paga impuesto cada
ciclo (propuesta: semanal, calibrable). El jugador carga oro en el arca del
lote y el cobro es automático; el arca acepta adelantar varios ciclos, así
irse de vacaciones es una decisión previsible y no una trampa.

Si un ciclo no se puede cobrar, el lote entra en **mora** y arrancan los 3
días de gracia. Durante la mora: la casa sigue entrable y los cofres siguen
accesibles, pero se apagan los beneficios (bonos de craft, huerta, punto de
retorno) y queda bloqueado construir, decorar y subir de tier. La deuda es
visible desde la calle — un cartel en la fachada —, tanto para presionar al
dueño como para avisarle al vecindario que ese lote puede quedar libre.

Vencida la gracia, **el lote se libera pero al jugador no se le destruye
nada**: el layout del interior y del patio se guarda como *plano* (blueprint)
en la cuenta, y el contenido de los cofres pasa a un depósito de recuperación
en la ciudad. Recuperarlo cuesta pagar la deuda atrasada. Volver a comprar un
lote y aplicarle el plano reconstruye la casa tal cual estaba, pagando de
nuevo los materiales. Esto es deliberado: el objetivo del impuesto es
**rotación de suelo y gold sink**, no castigar con la pérdida de 200 horas de
decoración — un sistema que borra el trabajo del jugador por dos semanas sin
jugar hace que la gente directamente no juegue al housing.

El impuesto **escala con el tier**. Es lo que evita que todo el mundo suba al
tier máximo "por las dudas": una casa grande es una cuota grande, y mantener
un tier alto obliga a seguir generando oro. Un jugador que dejó de jugar
pierde el lote sin que nadie tenga que decidirlo a mano.

**3. Tiers de casa.** El lote arranca con una casa de tier 1 — una planta,
interior chico. Cada tier sube cuatro cosas a la vez: área de la planta,
cantidad de pisos (escalera; el tier 2 es el que estrena el segundo piso),
cap de piezas colocables, y slots de cofre. Subir de tier cuesta oro (sink) +
materiales crafteados, y debería llevar tiempo de obra en vez de ser
instantáneo, para que la ciudad muestre casas en construcción.

Regla dura: **subir de tier nunca destruye lo ya colocado**. La planta
existente se conserva y el espacio nuevo se anexa; el jugador no tiene que
rearmar la casa cada vez que crece.

**4. La instancia de interior, estilo Habbo.** Entrar a la casa carga una
instancia propia (como un dungeon), y ahí adentro el dueño arma y decora a
gusto sobre grilla. Concretamente:

- Grilla de celdas, snap y rotación por dirección — la misma matemática del
  build mode de la herramienta de mapeo (`BuildGrid`, `TILE_SIZE = 32`), que
  está escrita como código reusable justamente para esto.
- Cada mueble ocupa un *footprint* de celdas y declara si se puede caminar
  sobre él, sentarse, apilarle cosas encima (mesa) o colgarlo de la pared. De
  ahí sale la sensación Habbo: sillas ocupables, mesas con objetos arriba,
  cuadros en la pared.
- Piso y pared son repintables por separado (ya hay tilesets Wang y capa de
  pintura en el prototipo).
- **Cap de piezas por tier**, no ilimitado — es el punto 5 de §2.4 de
  IDEAS2608: acota el peor caso de memoria y de tiempo de guardado.
- Permisos de visita: privado / amigos / clan / público. El modo edición es
  solo del dueño.
- El interior se guarda como un blob por lote, al salir del modo edición — no
  en cada movimiento de mueble.

**5. Cofres y almacenamiento.** Los cofres de casa son almacenamiento real,
no adorno: su contenido vive en la DB de la cuenta, separado del layout, para
que un error de decoración nunca pueda comerse ítems. Diseñarlos contra el
banco de ciudad y no encima: el banco es **caro en slots pero accesible desde
cualquier ciudad**; los cofres de casa son **mucho espacio y barato, pero hay
que ir hasta la casa**. Si los cofres fueran un banco global, el banco deja
de existir.

**6. El patio construible, a la vista desde la ciudad.** El lote no es solo
la puerta: tiene patio, y ahí el jugador pone decoración y estructuras útiles
para diferenciarse del resto. **Decidido: el patio está en la ciudad, a la
vista** — nada de esconderlo dentro de la instancia. Es lo único que los
demás ven sin que los invites, y ese escaparate es la mitad del valor del
sistema; pagarlo vale la pena.

Es también lo único del housing que no es gratis en costo de servidor, pero
el costo acá es acotado y chico, y la razón es estructural: **los lotes por
ciudad son finitos y las piezas por lote tienen cap**. El peor caso se conoce
de antemano — lotes × cap × ciudades — y no crece con el tiempo. Esa es la
diferencia entera con los claims de clan fuera de ciudad (§2.2/§2.4 de
IDEAS2608), donde el mundo puede llenarse sin techo: ahí el decay es la
válvula porque no hay otra; acá el techo ya está puesto por diseño.

Lo que mantiene ese costo en casi nada —y hay que sostenerlo, no es
automático:

- Las piezas de patio son **datos estáticos**: no tickean, no tienen física
  activa, no corren IA. Al cargar la zona se arma su colisión estática y nada
  más.
- **Cap de piezas por tier**, igual que el interior. Es lo que hace
  predecible el peor caso.
- El patio es **decoración y estructuras útiles, no fortificación** — no hay
  raideo ni robo en ciudad, así que ninguna pieza necesita estado de daño,
  durabilidad ni simulación de ningún tipo.
- Guardado **por lote y al salir del modo edición**, nunca un snapshot de la
  ciudad entera.

El costo que sí conviene vigilar no es la RAM del servidor sino la **ciudad
como punto de congregación**: es el lugar donde coinciden muchos jugadores y
muchas piezas a la vez, o sea el peor caso de replicación y de render del
juego. Si aparece un problema de performance en ciudad, va a venir por ahí —
cuánto hay que mandarle y dibujarle a cada cliente parado en la plaza—, no
por tener las casas guardadas.

De paso esto responde la pregunta abierta de §2.3 de IDEAS2608 (una ciudad de
puertas instanciadas se siente distinta a una con casas realmente ahí): las
casas están realmente ahí; lo instanciado es solo el interior.

Estructuras útiles candidatas para el patio: banco de craft, huerta
(gathering pasivo y lento), buzón, vitrina de venta, piedra de retorno. Cada
una con su costo y su propio cap — son las que dan la razón para visitar el
patio de otro, no solo mirarlo.

**Límites duros del sistema.** El housing no da poder de combate. El lote, el
tier y las estructuras se ganan con oro y materiales — el cash shop solo
vende skins de muebles, nunca lotes, tiers ni cap de piezas. En ciudad no hay
PvP, raideo ni robo de cofres.

**Decisiones por resolver:**

- Cómo se ve desde la calle un lote en mora o ya liberado. Que el patio esté
  a la vista significa que el abandono también se ve: hace falta decidir si
  queda tal cual (barrio con casas fantasma), si se degrada visualmente, o si
  al liberarse vuelve a un lote vacío limpio hasta que lo compre otro.
- Si los lotes son parcelas prefabricadas iguales dentro del barrio o
  polígonos hechos a mano por ciudad con la herramienta de mapeo.
- Período del impuesto (semanal vs. otro) y monto por tier. Solo se calibra
  probando: tiene que doler a quien dejó de jugar y ser trivial para quien
  juega.
- Cuántos lotes por ciudad, y qué pasa cuando no queda ninguno (¿lista de
  espera, subasta del lote liberado, o simple "primero que llega"?).
- Si el plano (blueprint) de recuperación es gratis o cuesta, y cuánto dura
  el depósito de recuperación antes de vaciarse.
- Cuántos tiers en total y cuánto interior suma cada uno.

**Implementado (prototipo) — piezas de estructura en la herramienta de
mapeo:** el build mode (Fase 2) suma una categoría "ESTRUCTURA" — pintar
celdas de pared con auto-tiling (piso/pared/esquina según vecinos, mismo
principio que el Wang de pasto/tierra) y un techo a 4 aguas que se compone
solo sobre el bounding box del piso (`StructureGrid`, `game/scripts/world/`).
StructureGrid es pura geometría (qué rol tiene cada celda según sus vecinos)
y no le importa qué arte la representa — eso lo decide `StructureTileset`,
que sí cambió de fuente una vez:

- v1 usó un kit generado con PixelLab (`create_building_kit`, proyección
  **oblicua**) con una pieza distinta por rol (wall_n/wall_s/corner_ne/...,
  26 PNGs). Se abandonó: costó mucho ajuste (escala global para cerrar huecos
  entre celdas, `texture_origin` por pieza) para terminar viéndose mal
  ("no es una casa cuadrada" — feedback real), y una casa pre-compuesta
  (`HouseMarker`/`HousePieceMarker`, con arte de Szadi art) tapaba el
  problema de fondo en vez de resolverlo: el punto de la herramienta de
  mapeo es poder construir pared por pared, celda por celda, a mano — no
  soltar una casa entera de un click. Ambos sistemas (kit PixelLab y casas
  Szadi) fueron reemplazados por completo.
- v2 (actual) usa 4 tiles PLANOS recortados de "Medieval Village Exterior"
  de Hypnobius (top-down recto, no oblicuo — ver
  `game/assets/world/structures/LICENSE.txt`): `wall.png` (piedra gris),
  `door.png`, `floor.png` (adoquín, celda totalmente rodeada) y `roof.png`
  (pizarra), reescalados de 48px a los 32px de la grilla del juego. El pack
  no trae arte direccional por rol (no hay wall_n vs wall_e, ni esquinas, ni
  piezas de techo modulares — son texturas planas repetibles) así que
  `StructureTileset.WALL_FILES`/`ROOF_FILES` mapean TODOS los roles de pared
  (los 4 lados, las 4 esquinas, PILLAR) al mismo `wall.png`, y TODOS los
  roles de techo al mismo `roof.png` — StructureGrid sigue decidiendo qué
  celda es pared/esquina/piso/puerta, solo que ahora todas las paredes
  comparten la misma textura sin distinción direccional. Mucho más simple
  que v1 y, al ser top-down recto (no oblicuo), ya no hace falta que el
  layer del techo se desplace un tile extra hacia arriba — el techo cubre
  directamente las mismas celdas que sus paredes.
Todavía sin: formas en L (hoy solo rectángulos — el bounding box de una forma
no rectangular cubre celdas que no existen), colisión física (las paredes no
bloquean movimiento todavía), transparencia real al entrar (heurística de
posición, no una vista "interior" de verdad), techo con piezas de hip/ridge
reales (hoy es una sola textura plana repetida), y soporte multi-cuarto real
(el bounding box del techo se computa sobre TODAS las celdas ocupadas de la
zona juntas — dos cuartos separados con un hueco en el medio comparten un
solo techo gigante en vez de dos techos independientes; no se resolvió,
sigue siendo la misma limitación v1 documentada en `StructureGrid`). Sigue
siendo dev-only (`BuildCatalog`), no es construcción jugable — ese salto es
el mismo de siempre: sacar `dev_only` cuando exista la UI real.

**Implementado (prototipo) — materiales de pared y techo:** el pack trae 4
texturas de pared (piedra, ladrillo, tabla lisa, madera) y 2 de techo
(pizarra, teja roja), no solo una. Cada `StructureMarker` ahora tiene su
propio `wall_material`/`roof_material` (`game/scripts/world/
structure_marker.gd`) en vez de un material fijo para toda la zona — el rol
de la celda (pared/esquina/piso/puerta) lo sigue decidiendo `StructureGrid`
como antes, pero la TEXTURA de una celda de pared es una elección aparte,
guardada por celda para que sobreviva save/reload. 4 ids nuevos en el
catálogo ("wall_brick"/"wall_plain"/"wall_wood", más el "wall" original que
ahora es explícitamente "piedra"). El techo (una sola forma por zona, ver
limitación arriba) usa el material que tenía seleccionado `Game.build_roof_
material` (tecla R en build mode) en el momento en que se pintó cada celda
de piso — ver `world_zone.gd`'s `_rebuild_structures()`.

**Implementado (prototipo) — "grounds" pintables:** categoría "GROUND" en
el build mode, con `GroundMarker`/`GroundTileset` (`game/scripts/world/
ground_marker.gd`/`ground_tileset.gd`) — un sistema mucho más simple que las
paredes: sin auto-tiling ni lógica de vecinos (`StructureGrid` no aplica
acá), cada celda es directamente la textura elegida (pasto o adoquín del
mismo pack), pintada una por una igual que "wall" (mismo grid, mismo
dedup/bounds-only). Deliberadamente NO es el mismo sistema que el piso
procedural de la zona (`FloorTileset`'s Wang de pasto/tierra) — es un stamp
de build mode para marcar una plaza/camino de adoquín o un parche de pasto
distinto, no el terreno base.

**Implementado (prototipo) — más decoración:** 6 props sueltos más en la
categoría "DECORACIÓN" (mismo `DecorMarker` de antes): una puerta de madera
lisa (sin arco de piedra, alternativa a la de "ESTRUCTURA"), una antorcha
(un solo frame estático de la hoja animada de 6 frames — no se implementó
animación, ver más abajo), 2 chimeneas (roja/azul) y 2 "techos prefab" — los
2 gráficos de techo a dos aguas COMPLETOS del pack (edificio entero, no
modulares), pensados para taparle el techo a un cuarto armado a mano en vez
del auto-tile plano de "ESTRUCTURA". Recorte de las chimeneas: el sheet no
las separa limpiamente por celda (cada chimenea es en realidad varias
piezas — tapa, cuerpo, remate — dibujadas pegadas sin margen transparente
entre sí, como ya había pasado con el barril), así que se escaneó una
columna vertical del canal alfa para encontrar el hueco real entre la
chimenea y los elementos de al lado en vez de cortar por grilla a ciegas.
Pendiente / explícitamente fuera de alcance por ahora: animar la antorcha,
separar las chimeneas en piezas modulares (tapa/cuerpo/remate) como un
kit propio.

**Implementado (prototipo) — edificios prefab para acelerar ciudades:**
categoría nueva "EDIFICIOS (prefab)" (`BuildingMarker`, `game/scripts/world/
building_marker.gd`) — un sprite ÚNICO por edificio (pared+techo+puerta ya
compuestos), en vez de armar pared por pared con "ESTRUCTURA"/"TECHO". 9
piezas generadas con PixelLab (vista "high top-down", igual convención que
`decor_roof_gable_*`): 2 casas chicas, 2 medianas, mansión, herrería, banco,
mercado y muelle (`game/assets/world/buildings/`). Se puede colocar desde el
dock del editor (`build_dock.gd`) igual que cualquier otro prop.

Por qué NO reutiliza StructureMarker/RoofMarker para esto: esos markers
guardan su celda en `grid_pos` (un Vector2i), y `_rebuild_structures()` pinta
el TileMapLayer usando ESE valor directamente — no la posición del nodo. Eso
significa que agrupar una casa armada a mano bajo un nodo y guardarla como
escena para instanciarla en otro lugar (el patrón "prefab" que
`zone_builder.gd`'s `_all_descendants()` menciona) NO es reubicable: todas
las copias pintarían las mismas celdas absolutas, superponiéndose en vez de
aparecer en el lugar nuevo. `BuildingMarker` esquiva el problema entero
siendo libre (como `DecorMarker`/`POIMarker`, `global_position`, sin grid,
sin TileMapLayer) — mover, duplicar o rotar la instancia funciona con el
transform normal de Godot, sin ningún caveat.

Espaciado: al ser un sprite grande, el `MIN_MARKER_SPACING` plano de 20px que
usa cualquier otro prop suelto (evitar que dos barriles se pisen) es
insuficiente para un edificio — `BuildingMarker.clearance_for(id)` devuelve
la mitad del lado más largo del sprite (+ margen) y tanto
`world_zone.gd`'s `is_placement_valid()` como la copia del editor en
`plugin.gd`'s `_place()` usan ese valor (para el candidato Y para cualquier
marker existente que ya sea un `BuildingMarker`) en vez del fijo — así un
edificio no se estampa encima de otro, ni una decoración chica cae dentro
del footprint de un edificio ya puesto.

Limitaciones v1, iguales en espíritu a las de "ESTRUCTURA": sin colisión
física (decoración de ciudad, no bloquea movimiento todavía), sin interior
real (es un sprite plano, no se puede entrar), y el set de variantes es fijo
— agregar un edificio nuevo hoy es generar el PNG y sumar una entrada a
`BuildingMarker._PATHS`/`BuildIcons.BUILDING_ART`/`BuildCatalog.ENTRIES`, no
hay pipeline de generación in-editor.

**Implementado (prototipo) — rotación por tipo de edificio, mansión/casas
más grandes:** pedido real: casas/mansión tienen que ir SIEMPRE de frente
(el arte solo se generó desde un lado, rotarlas se ve roto), pero
mercado/herrería/muelle sí tienen que poder orientarse hacia una calle o el
agua. `BuildingMarker.FIXED_FRONT_KINDS` (casas, mansión, y `bank` por la
misma razón — su arte es una fachada formal de un solo lado) siempre plantan
a rotación 0 sin importar qué rotación esté seleccionada.
`BuildingMarker.CARDINAL_ROTATE_KINDS` (`market`, `blacksmith`, `dock`) en
cambio SNAPEAN al múltiplo de 90° más cercano — ni los 45° libres que tiene
cualquier prop suelto (Q/E en juego), ni los 0 fijos de las casas.
`BuildingMarker.placement_for(id, rotación_pedida)` es el único lugar que
decide esto (rotación Y facing, ver más abajo), y tanto
`world_zone.gd`'s `_place_marker()`/build_ghost.gd (preview) en juego como
`plugin.gd`'s `_place()` en el editor lo llaman — nunca aplican la rotación
cruda. El dock del editor no tenía ningún control de rotación (el build mode
in-game usa Q/E, pero el editor no tiene `Game`/input de juego) — se sumó un
botón "⟳ Norte/Este/Sur/Oeste" en `build_dock.gd` que cicla de a 90°, con
tooltip aclarando que solo aplica a mercado/herrería/muelle.

Tamaños: la mansión pasó de 256×288 a 400×400 (el máximo de canvas de
`create_image_pixflux` por lado) y se re-generó con una fachada mucho más
elaborada (tres pisos, dos alas simétricas, torres) para que la diferencia
de escala se note más allá del canvas — un canvas más grande con la misma
silueta simple no "se siente" más grande. El banco se agrandó al mismo
400×400 y nivel de detalle que la mansión (pedido explícito: "tan grande
como la mansión"). Las casas chicas/medianas también se agrandaron
(128×160→176×224 y 160×224→224×288 respectivamente) — el pedido original de
que "las casas de por sí son pequeñas" resultó ser una crítica de tamaño, no
una confirmación de que estaban bien así. Como `BuildingMarker.clearance_for()`
lee el tamaño real del PNG en vez de un valor hardcodeado, el espaciado
mínimo entre edificios se ajustó solo, sin tocar código.

**Implementado (prototipo) — fondo blanco/composición diagonal en el
generador, y sprites de 4 direcciones reales para la herrería:** dos bugs de
generación reportados por separado, ambos en `create_image_pixflux`:

1) `no_background=true` no se respeta de forma confiable en composiciones
grandes/detalladas — mansión, banco y las casas medianas volvían con
alpha=255 sólido (blanco u gris claro) en vez de transparente, verificado
píxel a píxel, no a ojo (el visor de esta herramienta no distingue
"transparente" de "blanco real" — inspeccionar el alpha real fue necesario).
Pelear esto por prompt no dio resultados consistentes; la solución fue un
post-proceso propio (`ChromaKey.MakeTransparent`, C# vía `Add-Type` en
PowerShell — no vive en el repo, es una herramienta de una vez): flood-fill
desde el borde de la imagen usando el color promedio de las 4 esquinas como
referencia (no un "blanco" hardcodeado — el relleno salió blanco puro en
algunos casos y gris claro en otros), con tolerancia de distancia de color,
así los detalles interiores del sprite (ventanas blancas, etc.) no se tocan.
2) Para casas medianas/mansión, el mismo prompt a veces volvía en vista
frontal plana correcta y otras en 3/4 isométrico (dos paredes visibles, línea
de techo diagonal) — no hay un parámetro que lo garantice de forma
determinística, terminó siendo prueba y error por generación (varios
intentos hasta quedarse con el que salió bien compuesto).

Para la herrería, el problema era otro y más terco: pedirle 3 veces (texto a
imagen, 2 rondas) una "pared lateral/trasera en blanco, sin puerta, sin
ventanas" del mismo edificio devolvía sistemáticamente OTRA casita completa
con puerta — el modelo se resiste a dibujar "una pared" cuando el prompt dice
"building"/"workshop". La herramienta correcta para esto no es texto-a-imagen
independiente por dirección sino un turnaround real:
`create_8_direction_object` (PixelLab) genera las 8 direcciones de UN mismo
objeto con geometría consistente en una sola pasada — con esta, N/E/S/O
salieron coherentes al primer intento (mismo material, mismo techo, sin
alucinar una casa distinta), y ya vienen con canal alfa transparente real
(no hizo falta el chroma-key). `BuildingMarker._PATHS["blacksmith"]` es ahora
un Dictionary `{"n":.., "e":.., "s":.., "w":..}` en vez de un String — el
único miembro de `CARDINAL_ROTATE_KINDS` con arte direccional real por
ahora (`has_directional_art()`); mercado y muelle siguen rotando su único
sprite (el fallback viejo) hasta que se genere lo mismo para ellos.
`BuildingMarker.facing_steps` (0-3, exported) selecciona cuál de las 4 se
dibuja; para un edificio direccional, "rotar" ya NO aplica ninguna
`Transform2D.rotation` (queda en 0) — cambia el sprite en su lugar. El
mapeo N/E/S/O de este proyecto es arbitrario respecto al de PixelLab (su
"south" es la vista con la fragua/entrada visible, la mapeamos a nuestro
índice 0/"n" = el frente por defecto) — no hay una brújula real en juego
para un edificio, solo importa que rotar cicle por 4 vistas distintas y
consistentes.

**Implementado (prototipo) — segunda pasada: muelle/mercado seguían en
diagonal, casa de paja también, laterales de herrería casi iguales a la
trasera:** reportado después de la pasada anterior. Dos causas distintas:

1) `dock.png`, `market.png` y `house_small_a.png` eran los ÚNICOS tres
archivos que quedaron sin tocar desde el batch original (el primero de
todos) — nunca pasaron por la técnica "front facade"/"FLAT FRONT ELEVATION"
que terminó arreglando casas medianas/mansión/banco en la pasada anterior.
No era aleatoriedad, era simplemente que no se habían regenerado. `market` y
`house_small_a` salieron bien al primer/segundo reintento con esa técnica;
`dock` resultó mucho más terco — **6 intentos en total** contando ambas
pasadas, con `create_image_pixflux` (`view="high top-down"` y `view="side"`,
con y sin la frase "FLAT FRONT/SIDE ELEVATION") y con `create_map_object`,
todos volvieron en 3/4 isométrico igual. Lo que sí funcionó: `create_8_direction_object`
(la misma herramienta de turnaround que arregló la herrería) — se le pidió
un objeto de 8 direcciones y se usó SOLO su vista frontal como `dock.png`
plano; las otras 7 direcciones generadas se descartan (el muelle no tiene
arte direccional real, ver siguiente punto). Conclusión práctica: para un
edificio bajo/achatado de una sola planta, el turnaround da resultados
frontal-plano mucho más confiables que pedirle una "imagen" suelta al modelo
de texto-a-imagen — si aparece otro caso terco como este, ir directo a
`create_8_direction_object` y quedarse con una sola cara, en vez de iterar
prompts de texto-a-imagen a ciegas.

2) Los laterales E/O de la herrería de la pasada anterior se veían casi
idénticos entre sí y a la trasera — la descripción no especificaba la forma
del edificio, y salió de planta casi cuadrada: en un edificio cuadrado con
techo a dos aguas, LOS 4 LADOS son geométricamente parecidos (cada uno es un
extremo de gablete), así que no hay verdadero "lateral" que mostrar por más
que el turnaround sea consistente — no era un bug de la herramienta, era que
el objeto generado no tenía un lateral distinto en primer lugar. Se
regeneró especificando explícitamente planta RECTANGULAR ALARGADA (el doble
de largo que de ancho) con el techo corriendo sobre el eje largo — con esa
forma, N/S (los extremos cortos, gabletes) y E/O (los lados largos, perfil
de techo inclinado sin gablete) salieron genuinamente distintos. Lección:
`create_8_direction_object` da consistencia geométrica entre direcciones,
pero la DIFERENCIACIÓN entre ellas depende de que la forma descrita
realmente tenga lados distintos — pedirle una "casita" sin más no alcanza.

**Implementado (prototipo) — mercado: 3 carpas distintas, sin disco de
piso:** reportado: el mercado se generaba con un círculo de arena sólido
bajo la carpa (se ve como una base/piso propia en vez de flotar sobre el
terreno real de la zona), y pedía varias carpas con decoración distinta en
vez de una sola repetida. `building_market` (un solo id) se reemplazó por
3: `market_produce` (verdulería, la carpa original con toldo dorado),
`market_textiles` (una carpa cónica de telas, toldo violeta/verde azulado)
y `market_spices` (especias, toldo bordó, tarros y atados de hierbas) — las
3 en `CARDINAL_ROTATE_KINDS` como el mercado original.

El disco de arena resultó MUY terco: ni `no_background=true` ni pedirle
explícitamente "no ground, no sand, no floor patch, floating cutout" en el
prompt lo evitó en ninguna de las 3 (probado también `inpaint_image` sobre
la franja inferior pidiendo "nothing, empty space" — resultado, PEOR: el
inpaint agregó más objetos de escena ahí en vez de vaciarlo, confirmando que
estas herramientas interpretan "vaciar una región" como "rellená esto con
algo que tenga sentido en la escena", no como borrar). La solución que
funcionó fue post-proceso dirigido: `ChromaKey.MakeTransparentFromSeed()`/
`ClearColorInRegion()` (mismo archivo de una vez, `ChromaKey.cs`) — a
diferencia del flood-fill desde el BORDE que ya arreglaba fondos blancos
completos (ver arriba), el disco de arena no toca el borde del canvas (hay
margen transparente real alrededor de toda la composición), así que hizo
falta: 1) samplear el color real de la arena a mano (variaba: dorado/tostado
en verdulería y telas, más claro en especias — nunca "blanco", por eso el
chroma-key de borde no lo tocaba), 2) limpiar por color DENTRO de una franja
acotada por altura (`minY`) en vez de detectar por conectividad — el disco
no siempre es un blob conectado (hay parches de arena sueltos bajo cada pata
por separado), y el color de la arena se pisa con el de partes reales del
objeto (postes de madera, toldo) más arriba en el canvas, así que el
recorte por color SOLO es seguro acotado a la banda inferior donde se sabe
que no hay nada más que arena. Quedó un resto mínimo de "polvo" de un par de
píxeles en la base de alguna — aceptable, no es el disco sólido reportado.

**Actualización — el recorte por color no alcanzó, verdulería seguía en
diagonal, muelle sin identidad de muelle:** el usuario reportó, tras la
pasada anterior, que verdulería seguía en 3/4 (el mostrador es una caja con
profundidad — inherentemente más difícil de aplanar que una fachada) y que
telas/especias TODAVÍA tenían arena visible de sobra (el recorte por color
dejó bastante más de lo que el resultado final mostraba en esta
conversación — subestimé cuánto quedaba). Se abandonó `create_image_pixflux`
+ post-proceso para el mercado y se pasó directo a
`create_8_direction_object` (la herramienta que ya venía siendo confiable
para muelle/herrería) para las 3 variantes — funcionó al primer intento en
las 3, plano y sin arena, sin necesitar ningún recorte manual después.
Lección reforzada: para un objeto bajo tipo "mueble sobre el piso" (mercado,
muelle), ir directo al turnaround en vez de iterar `create_image_pixflux`
ahorra tiempo y créditos — la ruta texto-a-imagen+post-proceso quedó
oficialmente descartada para esta categoría de asset.

Aparte, el muelle original (arreglado en la pasada anterior con la misma
herramienta) había perdido su identidad de muelle en el proceso — al
simplificar la descripción para evitar el sesgo isométrico, terminó como
una cabaña de madera genérica sin pilotes, pasarela, red ni soga, casi
indistinguible de la herrería. Se regeneró con la descripción enriquecida
de vuelta (pilotes visibles, pasarela de madera, red y soga colgando, poste
de amarre) manteniendo `create_8_direction_object` — la herramienta no fue
el problema esa vez, fue haber recortado demasiado la descripción.

**Implementado (prototipo) — fixes de build mode reportados en uso real:**
1) el ghost/preview de colocación forzaba SIEMPRE un cuadrado fijo de 48x48
sin importar el tamaño real de la textura (`build_ghost.gd`) — un banderín
de 64x16 o un grifo de 12x13 se veían estirados/aplastados en el preview y
después aparecían con su tamaño y proporción reales al confirmarse, un
"preview que miente". Ahora el preview dibuja al tamaño nativo real de la
textura (excepto paredes/ground, que siempre llenan una celda de 32px).
2) Nuevo toggle de snap a grilla (`Game.build_snap_to_grid`, tecla T): apagado
por defecto (dispersión orgánica libre para arbustos/rocas/mobs), prendido
alinea cualquier pieza de colocación libre (decoración/recursos/mobs/POIs) a
la misma grilla de 32px que "wall" ya usa siempre, para pegar decoración
prolijo contra una pared en vez de cazar el pixel a mano.

**Bugs reportados tras usar la herramienta con el catálogo ya grande — dos
más:**
1) La puerta se dibujaba colgando fuera del edificio, con la celda de la
puerta vacía (pasto de fondo) y el sprite completo aparecía una fila más al
sur, afuera de la pared. Causa: `StructureTileset`'s `texture_origin` para
`door.png` (más alto que una celda) restaba `(alto_textura - TILE_SIZE)`
asumiendo que Godot ancla un tile más grande que la celda por su esquina
superior izquierda — pero Godot ya lo ancla por ABAJO-IZQUIERDA por
defecto, creciendo hacia arriba, que es exactamente el look de "puerta que
se levanta sobre su propia celda" que se buscaba. Esa resta de más lo
empujaba doblemente. Confirmado por prueba y error con renders reales
(`texture_origin.y = -32` → colgaba afuera; `+32` → se pasaba de largo para
el otro lado, con hueco en la base; `0` → encaja perfecto). Ahora
`texture_origin.y` siempre es 0; solo el eje X sigue centrado a mano (para
un tile más ANCHO que una celda — ninguno del arte actual lo es, pero deja
la cuenta lista si algún día lo es, ya que Godot no auto-centra el ancho de
la misma manera que auto-ancla el alto).
2) El panel de build mode tenía tamaño fijo y sin scroll — con ~37
placeables ya no entraba todo, y el fix anterior (bloquear el zoom del
mundo mientras el mouse está sobre el panel) no alcanzaba porque no había
nada que efectivamente scrollee el contenido. Se agregó un `ScrollContainer`
real alrededor de "Categories" (`hud.tscn`) y se agrandó el panel.

**Implementado (prototipo) — el techo tapa espalda/costados, solo la
fachada queda visible:** pedido explícito tras ver el primer render con
paredes en las 4 direcciones a la vista completa — no se lee como un
edificio real así, se lee como 4 paredes sueltas con un techo flotando
encima. Ahora `_rebuild_structures()` solo deja SIN techo la fila que da al
jugador/cámara (sur, +Y — confirmado antes que sur es "hacia el jugador" en
este proyecto): pared sur, sus 2 esquinas, y la puerta si está ahí
(`FRONT_FACING_PIECES`). Todo lo demás (pared norte, este, oeste, sus
esquinas, y el piso interior) queda cubierto por el techo, como el alero de
un techo real tapando las paredes de atrás y los costados. El resultado
final: desde afuera solo se ve el techo + la fachada frontal con la puerta,
igual que Stardew Valley/Zelda.

**Fix — la puerta reescalada para no dominar la pared:** el primer recorte
de `door.png` (32x64) era fiel al tamaño del sprite fuente, pero al lado de
una pared plana de 32x32 se leía como una pieza 2x más grande y desproporcionada.
Se recortó de nuevo, más chica (24x48 en vez de 32x64 — angosta como una
puerta real dentro de su tramo de pared, alta pero no el doble). Dos bugs
reales aparecieron al hacer este cambio, ninguno relacionado con el tamaño
en sí:
1) `StructureTileset._load_or_placeholder()` exigía que CUALQUIER textura
midiera al menos `TILE_SIZE` (32px) en ambos ejes — una salvaguarda vieja
que asumía que ninguna pieza real sería más chica que una celda. Con la
puerta ahora angosta (24 < 32) esa validación la rechazaba en silencio y
caía al color placeholder marrón sólido — se veía como "falta el arte" pero
en realidad el arte cargaba bien, la validación era demasiado estricta.
2) El recorte en sí apuntaba al archivo fuente equivocado (quedó pegado el
mismo x/y que se usaba para B.png pero apuntando a `Props_Decor.png` por
error) — el resultado era un pedazo del gráfico del TECHO, no de la puerta.
Ambos corregidos; confirmado con un render real que la puerta se ve
proporcionada y centrada en su celda.

**Fix — anclaje de tiles más grandes que su celda (el pie de la puerta al
ras del piso):** reportado como "el pie de la puerta no está al ras del
pasto". Causa raíz: `StructureTileset._add_sources()` venía calculando
`texture_origin` **a partir de suposiciones sobre cómo Godot ancla un tile
más grande que el `tile_size` del TileSet**, y las suposiciones estaban mal
— dos intentos anteriores (uno con signo negativo, otro con positivo)
ajustaron el número hasta que "se veía bien" en vez de medir la regla real,
y ninguno de los dos dejaba el pie realmente al ras (la pared quedaba
dibujada una celda entera más abajo de su celda lógica, error invisible
porque TODAS las paredes se corrían igual; la puerta, al ser de otra altura,
se corría distinto y ahí sí se notaba el desfasaje entre las dos).
La regla real, medida poniendo `texture_origin = 0` y escaneando el render
resultante: **Godot dibuja el tile CENTRADO en la celda**, y `texture_origin`
con valores **positivos mueve la imagen hacia ARRIBA/IZQUIERDA** (al revés
de lo que sugiere el nombre). Con eso la cuenta correcta sale sola:
`texture_origin = (0, (alto_textura - TILE_SIZE.y) / 2)` — X en 0 porque
centrado ya es lo que se quiere para una puerta/ventana dentro de su tramo
de pared, e Y subiendo exactamente el sobrante para que la BASE quede
pegada al borde inferior de la celda. Verificado midiendo en world-coords:
pared, puerta y el fantasma de preview ahora caen los tres exactamente en la
misma línea de piso (el borde inferior de la celda), sin importar que cada
pieza tenga una altura distinta.

**Fix — el preview (ghost) mentía sobre tamaño y posición:** encontrado
mientras se buscaba lo anterior. `build_ghost.gd` forzaba las piezas de
estructura a un cuadro fijo de 32x32 (aplastando la pared de 32x64 y la
puerta) y las centraba en el cursor, cuando el tile ya colocado se ancla por
su BASE sobre la celda. Ahora el ghost dibuja al tamaño nativo real de la
textura y con el mismo anclaje que tendrá al colocarse. Nuevo dev tool
`tools/ghost_preview_screenshot.gd`: renderiza el ghost al lado de la MISMA
pieza ya colocada, para poder comparar preview-vs-resultado en una sola
captura — ninguno de estos dos bugs era detectable headless (son puramente
"dónde caen los píxeles") ni evidente mirando solo el resultado colocado.

**Fix — fachada frontal completa + ventanas levantadas del piso:**
reportado como "una ventana ocupa toda una pared y lo mismo con la puerta,
esto no es lógico". Medido antes de tocar nada: la pared es de 2 celdas
(64px) pero el techo de la fila de adelante le tapaba los 32px de arriba, así
que la fachada VISIBLE era de una sola celda — y una puerta de 48px no solo
la llenaba entera sino que se pasaba (su arco quedaba recortado detrás del
techo). Dos cambios:
1) Nueva TileMapLayer "Facade" (z_index 51, por encima del techo en 50) que
re-pinta SOLO la fila frontal de pared. Así la pared frontal muestra sus
64px completos y el techo se lee por DETRÁS de ella — el look Stardew/Zelda
que se venía buscando. "WallDecor" subió a z_index 52 para seguir por encima
de la fachada; a cambio, una celda que el techo sí tapa (paredes de atrás y
de los costados) directamente no pinta su decoración, en vez de atravesar el
techo. Una puerta nunca entra en ese caso porque ya estaba exenta del techo.
2) `StructureTileset.WALL_DECOR_RAISE`: cuánto se levanta del piso cada tipo
de decoración de pared. La puerta queda en 0 (se camina a través de ella,
tiene que tocar el piso); las ventanas y la antorcha NO — una ventana al ras
del piso se lee como un agujero, no como una ventana. Valores ajustados
contra un render real de la fachada de 64px, dejando pared visible arriba Y
abajo de cada pieza.
3) Alero norte: una fila extra de techo por encima del borde superior del
edificio. Al corregir el anclaje (punto anterior) las paredes subieron 32px,
y como la pared de atrás mide 2 celdas parada sobre 1, su mitad de arriba
quedaba asomando por encima del techo — una banda de pared visible arriba de
todo, que no debería verse desde afuera. La fila extra la tapa, y de paso es
lo que hace un alero real al sobresalir de la pared.

**Fix — la pared no repetía bien (se cortaba al poner varias):** reportado
como "la pared se corta al poner varias, no se une de forma limpia".
Confirmado midiendo la hoja original, no a ojo: en el pack **cada material
de pared es una unidad SEAMLESS de 96x96 hecha de 2x2 tiles de 48px**, no
cuatro tiles intercambiables. Yo estaba usando UNA sola de las dos columnas
y repitiéndola. Delta promedio por píxel en la costura: repetir una sola
columna = **151**; el bloque de 2 columnas cerrando sobre sí mismo = **30**;
la costura interna del bloque = **56**. O sea: una columna sola deja un
corte visible en cada celda. `StructureTileset.WALL_MATERIALS` ahora mapea
cada material a sus DOS variantes horizontales y `world_zone.gd`'s
`_wall_source_id()` alterna por `posmod(cell.x, 2)` (posmod y no `%`: las
celdas de un edificio son habitualmente negativas y el signo de `%` daría
vuelta la alternancia de un lado del origen). Eso reproduce el período de
96px del pack, que a la escala 2/3 del proyecto son exactamente 2 celdas.
También se regeneraron TODOS los tiles repetibles (paredes, piso, techo) con
`WrapMode.TileFlipXY` en el escalado: sin eso GDI+ muestrea píxeles vecinos
de la hoja al reducir, y ese sangrado dejaba líneas tenues en cada borde.
**Nota de calidad pendiente:** el README del pack pide escalar solo hacia
ARRIBA, nunca hacia abajo, y el proyecto reduce 48px→32px para entrar en su
grilla. Hay una pérdida inherente por eso. La solución de fondo sería pasar
la grilla del juego a 48px — cambio grande (TILE_PX, BuildGrid, FloorTileset),
deliberadamente NO hecho todavía.

**Implementado — techo con cumbrera y alero (antes era un rectángulo de
tejas):** el techo automático se veía plano/raro. Medido: NO era problema de
costura (la textura repite bien en ambos ejes). El motivo real es que el
pack **no trae kit modular de techo** — no hay piezas de limatesa, valle ni
esquina; solo una textura de relleno. Pero la hoja `Roofs.png` sí tiene algo
más que relleno: los **12px de arriba de cada material son una banda de
CUMBRERA** distinta, y el campo repetible arranca recién en y=12 con período
48 (medido comparando cada fila contra una fila de campo conocida: y=12 da
delta 0 contra y=60). Entonces un tile cortado de y=0..47 es "cumbrera +
campo" y apila sin costura sobre el tile de campo cortado de y=48..95.
`ROOF_MATERIALS` pasó a ser `[field, ridge, eave]` por material, y
`_rebuild_structures()` elige la variante según dónde cae la celda: la fila
más alta de cada COLUMNA (no global, para que una planta no rectangular
también quede rematada) lleva cumbrera, la más baja lleva alero, el resto
campo. El alero no tiene arte propia en el pack: es el tile de campo con sus
filas de abajo multiplicadas más oscuras, derivado de los píxeles del propio
arte para no meter un color inventado.
Todavía sin: limatesas/valles reales en las esquinas (seguiría necesitando
arte que el pack no tiene). Los 2 techos completos prefabricados del pack
(`decor_roof_gable_red`/`_blue`) siguen disponibles en DECORACIÓN para
techar a mano cuando se quiera algo más elaborado.

**Auditoría del pack — qué faltaba exponer:** se revisó hoja por hoja qué
trae el pack contra qué estaba en la paleta. Faltaban 4 piezas, ya agregadas
a DECORACIÓN: las **2 buhardillas** (dormers, ventanitas de techo — van
sueltas y no como `wall_decor` porque pertenecen a un TECHO, y el mecanismo
de wall_decor solo pinta sobre celdas de pared), una **tabla de madera**
suelta, y la **plataforma de piedra**. Esa última merece una nota: el README
del pack la cuenta como una de sus "3 texturas de piso auto-tile", pero
midiendo no tiene NINGÚN período de repetición vertical — es una plataforma
fija de 2x3 con los bordes/cordones dibujados en su anillo exterior. O sea
que no puede funcionar como piso pintable al lado de pasto/adoquín; va como
prop entero. Con esto el pack queda expuesto completo salvo la animación de
la antorcha (6 frames, se usa solo el primero — sigue pendiente).

**Implementado — la herramienta de mapeo acercándose a un world editor:**
tres cosas que son las que más duelen mapeando a mano:
1. **Pintar arrastrando.** Mantener el click y barrer rellena una tirada de
celdas en vez de exigir un click por celda — de lejos el mayor costo de
tiempo al levantar un edificio o un camino. Click derecho arrastrando borra
igual. Deliberadamente SOLO para tipos de grilla (paredes / decoración de
pared / pisos): un prop de colocación libre barrido por la pantalla
escupiría decenas de barriles superpuestos, así que esos siguen siendo un
click por objeto — que es además como se comportan los editores de verdad
(pincel para tiles, click para objetos).
2. **Deshacer (Ctrl+Z).** Con la propiedad que importa: **un gesto = un
paso**. Un arrastre que pintó 30 celdas se deshace de una, no de a treinta,
o el undo no sirve para mapear. Los markers borrados se guardan vivos
(huérfanos, sin `queue_free()`) justamente para que el undo devuelva EL
MISMO nodo con todas sus propiedades intactas en vez de reconstruir una
aproximación; recién se liberan cuando la acción se cae del fondo de la pila
(`MAX_UNDO_ACTIONS`). Deshacer un `wall_decor` restaura el que había antes,
no vacío.
3. **Ocultar el techo (H).** El techo tapa todo el interior por diseño, así
que sin esto las celdas de piso/interior son imposibles de mirar mientras se
edita. Todo editor de tiles real tiene un toggle de capa.
Un bug que el test agarró y que se habría escapado: el undo usaba
`is_inside_tree()` para decidir si desparentar un marker, pero una zona bajo
test (y una zona del lado del editor) está ella misma fuera del árbol, así
que el chequeo daba falso y el undo no removía nada. Lo correcto es mirar
`get_parent()`.
4. **Techo automático activable/desactivable.** R ahora cicla tres estados
en vez de dos: pizarra → teja roja → **sin techo**. Se resolvió como una
tercera opción del control de techo que ya existía y no como una tecla
aparte, porque "sin techo" es simplemente otra opción de la misma decisión,
y mantiene chica la superficie de controles del build mode. Igual que el
color, se guarda por celda en `StructureMarker.roof_material` (valor
`"none"`), así que **sobrevive save/reload** — no es un flag de sesión. Con
esto se pueden hacer patios amurallados, ruinas y corrales abiertos, y
también dejar limpio el lugar para colocar a mano uno de los techos
prefabricados del pack. Implementación: las celdas marcadas "none" ni
siquiera entran a `compute_roof()`, así que una construcción totalmente sin
techo no genera bounding box y por lo tanto no genera techo alguno (en vez
de generarlo y filtrarlo después).
Bug latente encontrado al implementar esto: las celdas interiores de un
cuarto HUECO (cuando se pinta solo el contorno) no tienen marker propio, así
que no pueden responder "¿de qué material?" — y el código las mandaba a un
"slate" fijo. O sea que un cuarto de teja roja dibujado como contorno tenía
el interior de pizarra. Ahora heredan el material más común entre las celdas
que sí tienen marker. Cubierto con test.
Todavía sin (siguiente tanda natural para el editor): rehacer (Ctrl+Y),
herramienta de rectángulo/relleno, seleccionar y mover markers existentes,
copiar/pegar un edificio entero como prefab reutilizable, buscador en la
paleta (ya son 41 ids), y overlay de grilla visible.

**Fix — paredes por orientación (modularidad real):** reportado como "se ve
raro cuando metés varias paredes juntas" y "que sea 100% modular, que pueda
hacer una casa del tamaño que quiera". Diagnosticado con un render sin techo
(`tools/wall_configs_screenshot.gd` — el techo tapa los costados y el fondo,
así que la ÚNICA forma de juzgar el arte de pared es construir sin techo y
mirar): una tirada horizontal se veía bien, pero una **vertical** salía como
una cinta alta rarísima y un **cuarto hueco** se leía como un bloque relleno
con agujeros en vez de un contorno. Causa: se usaba la MISMA textura de cara
alta (32x64) para las 4 orientaciones, y esa solo sirve para la pared que
mirás de frente. Una pared tiene UNA celda de espesor, así que desde arriba
llena exactamente su propia celda. Ahora hay dos vistas por material
(`WALL_MATERIALS` = cara alta, `WALL_TOP_MATERIALS` = vista desde arriba,
cortada del tope del bloque para que arranque con la cornisa que el pack
dibuja ahí) y `_rebuild_structures()` elige según el rol que ya calculaba
`StructureGrid`: la fila sur es fachada (cara alta, 2 celdas), norte/este/
oeste y sus esquinas son pared vista desde arriba (1 celda). Con eso se puede
pintar una casa de cualquier tamaño y forma y se lee bien.

**Implementado — pintar techo a mano (`RoofMarker`):** pedido explícito
("no puedo pintar techo manualmente"). Nueva categoría "TECHO (pintar)" con
`roof_slate`/`roof_red`, que colocan un `RoofMarker` por celda igual que el
pintado de pisos. Convive con el techo automático y no lo reemplaza: los
markers manuales se fusionan al conjunto de celdas de techo ANTES del pase
de cumbrera/alero, así que un techo dibujado a mano recibe su remate y su
fascia exactamente igual que uno generado, y los dos se pueden mezclar en el
mismo edificio. Una celda manual gana sobre el material automático (es la
decisión más específica). Esto es lo que destraba las formas que el techo
automático nunca va a poder expresar por construir sobre un bounding box
rectangular: casas en L, galerías/aleros que sobresalen de las paredes,
techo sobre un hueco entre dos construcciones. Combinado con R -> "sin
techo", se puede desactivar el automático y dibujar el techo entero a mano.

**Rediseño — autotiling de paredes por bitmask, capas desacopladas:**
pedido como rediseño con arquitectura explícita. Auditoría previa, con
mediciones, antes de tocar código:

- *La costura cada 2 tiles.* La primera hipótesis (que el escalado por
  columnas separadas rompía el empalme) se **descartó midiendo**: escalar
  cada mitad por separado vs. escalar el bloque de 96px entero y cortarlo da
  resultados idénticos. La causa real es que el bloque **no es
  auto-tileable**: su borde izquierdo y su borde derecho llevan AMBOS un
  poste oscuro (brillo por columna 72 y 81 contra ~100-116 del interior), así
  que al alternar A,B,A,B cada vuelta pegaba las dos columnas oscuras y
  pintaba una banda doble cada 64px = 2 celdas. Lección de método: la
  métrica de "delta bajo entre bordes = sin costura" estaba MAL PLANTEADA —
  un delta bajo solo dice que los bordes se parecen, y acá se parecían
  porque los dos eran oscuros. El artefacto era duplicación, no
  discontinuidad.
- *El techo disparado por el pincel de pared.* `_place_marker()` estampaba
  `Game.build_roof_material` en el marker y llamaba a `_rebuild_structures()`,
  que escribe en CUATRO capas de una (Structures, Facade, Roof, WallDecor).
  Un solo trazo del pincel de pared escribía en la capa de techo.
- *Fallback silencioso.* `img.fill(Color(0.55,0.4,0.25,0.9))` — marrón
  sólido, indistinguible de arte real. Ya había costado tiempo de debug antes
  en esta misma sesión.
- *TILE_SIZE.* Cinco definiciones independientes de 32, coincidentes por
  casualidad.

Lo implementado:
1. **Una sola constante**: `BuildGrid.TILE_SIZE` (+ `TILE_SIZE_2I`), y las
   otras cuatro pasan a referenciarla.
2. **Capas independientes**: nueva `Walls` autotileada, y el pincel de pared
   NO toca el techo. El techo sale solo de `RoofMarker` — pintado a mano, o
   por la acción explícita `generate_roof_over_walls()` (tecla G), que sí
   conserva las dos exenciones que hacían legible un edificio (fila sur
   destapada y puertas nunca techadas).
3. **Autotiling por bitmask de 4 direcciones**:
   `StructureGrid.compute_wall_masks()` es geometría pura (17 checks
   unitarios) y `WallTileset` compone 16 sprites por material —el relleno se
   muestrea del INTERIOR del material, nunca de sus bordes oscuros, que es lo
   que elimina la banda duplicada— con un reborde en cada lado sin vecino.
   El repintado recalcula el set completo, así que el bitmask de un VECINO se
   actualiza al borrar, no solo al pintar (`StructureGrid.affected_by()`
   documenta la versión incremental para cuando esto deje de ser barato).
   Verificado midiendo el render: los bordes de celda pasaron de ser el par
   más oscuro de la textura a avg 26 / max 69 contra avg 28 / max 128 del
   interior — ya no son outliers.
4. **Fallback visible**: damero magenta/negro (`WallTileset._error_image()`)
   en vez de color sólido.
5. **Overlay de debug (F3)**: dibuja el bitmask sobre cada celda, en su
   propio CanvasItem por encima (el zone está en z_index -5, dibujar ahí
   quedaba detrás de los propios tiles que anota). Existe porque el test
   unitario prueba que los NÚMEROS están bien, pero no puede ver si el número
   correcto maneja el SPRITE correcto — que es justo donde falla un
   autotiler.

Bug real encontrado al implementar: la capa nueva se llamó `Walls`, pero ese
nombre ya lo tenía el `StaticBody2D` de los límites de la zona, así que
`get_node("Walls")` devolvía un StaticBody2D donde se esperaba un
TileMapLayer. El colisionador pasó a llamarse `WorldBounds`, que es lo que
siempre fue.

**Implementado — mapear a mano desde el editor de Godot:** el build mode
in-game es un prototipo; el editor de tilemaps de Godot es una herramienta
madura (relleno por rectángulo, cubeta, picker, undo, autotiling nativo).
Hasta ahora era IMPOSIBLE usarlo: `pradera.tscn` solo tenía `Floor`, las
capas Ground/Walls/Roof se creaban en runtime por código, y los TileSets se
generaban en memoria — o sea, ni había dónde pintar ni con qué. Tres
cambios:
1. **`tools/bake_tilesets.gd`** hornea los TileSets a `.tres` reales (+ sus
   atlas PNG) en `assets/world/baked/`. El de paredes se hornea con un
   **terrain de Godot por material en `TERRAIN_MODE_MATCH_SIDES`** — el
   modelo de 4 lados, que es exactamente el bitmask de `StructureGrid`. Eso
   hace que el pincel de terreno del editor autotile solo mientras pintás:
   arrastrás y Godot elige la pieza correcta de las 16. Reusa
   `WallTileset.compose_images()`, la MISMA rutina que el runtime, así que
   las dos no pueden divergir.
2. **Las capas viven en la escena** (`Ground`/`Walls`/`Roof` en
   `pradera.tscn`, con el mismo offset de media celda que usa el runtime), y
   el runtime las REUSA en vez de crear las suyas — `_ensure_layer()`. Antes
   creaba siempre, y Godot renombraba la nueva a "Walls2" dejando la
   pintada a mano sin usar.
3. **El repintado ya no hace `clear()`**: `_repaint_owned()` recuerda qué
   celdas puso este script y borra solo esas, así que lo pintado a mano en
   el editor SOBREVIVE. Sin esto, abrir una zona hecha a mano la borraba
   entera en el primer rebuild.
El runtime carga los mismos `.tres` horneados (con fallback a componer en
memoria si no existen todavía), así que una pared hecha a mano y una hecha
con el build mode significan lo mismo.
**Flujo para mapear a mano:** correr el baker una vez, abrir `pradera.tscn`,
seleccionar la capa `Walls`, y usar la pestaña TileMap con el pincel de
terreno. Los mobs/recursos/POIs siguen siendo markers (son entidades, no
tiles) y se agregan como nodos bajo `Markers`.
**Agujero del harness encontrado de paso:** una sección de test que abortaba
por un error de script dejaba la suite en ALL GREEN igual, porque el piso
`MIN_CHECKS` estaba en 30 contra ~270 checks reales. Subido a 250, que es lo
que convierte "una sección se murió" en un fallo visible. Pasó de verdad en
este mismo cambio: 13 checks desaparecieron sin que la suite se quejara.

**Generalización — "pintar" puerta/ventanas/decoración de pared, no solo
la puerta:** pedido explícito de seguir — el mismo mecanismo de "click en
una pared existente" tenía que servir también para ventanas y para
decoración tipo antorcha, no ser exclusivo de la puerta. `StructureMarker`
cambió `is_door: bool` por `wall_decor: String` (""/"door"/"window_small"/
"window_medium"/"window_large"/"window_arched"/"window_flowerbox"/"torch",
ver `StructureTileset.WALL_DECOR`) — un dato por celda, no un caso especial
de la puerta. Nueva TileMapLayer "WallDecor" (reemplaza a la vieja "Doors"),
separada de "Structures" — `_rebuild_structures()` computa el rol de pared
de cada celda IGNORANDO wall_decor por completo (`compute_walls(occupied,
{})`), así que la pared se sigue pintando completa siempre sin importar qué
esté pintado encima; el wall_decor (puerta/ventana/antorcha) se pinta
aparte, encima, solo en las celdas marcadas — un solo wall_decor por celda
(pintar uno nuevo reemplaza al anterior, pintar el mismo lo saca — el mismo
toggle que ya tenía la puerta). "window_arched/small/medium/large/
flowerbox" y "torch" se movieron de la categoría DECORACIÓN (donde no tenía
sentido colocarlos sueltos en el aire) a ESTRUCTURA (donde se pintan sobre
una pared, "click en pared", igual que la puerta). El chequeo de "qué fila
tapa el techo" (`FRONT_FACING_PIECES`) sigue exceptuando cualquier celda con
PUERTA sin importar el lado (una puerta tapada no serviría de nada); una
ventana/antorcha NO tiene esa excepción — si están en una pared que el techo
ya tapa desde afuera, quedan tapadas también, tiene sentido (una ventana en
una pared oculta tampoco se vería en la vida real).

**Fix — la pared ahora ocupa 2 celdas de alto x 1 de ancho:** pedido
explícito, "para que sea todo más decente" — con 1x1 (32x32) la pared se
leía chata/achatada al lado de una puerta ya más alta. Los 4 materiales de
pared (`wall.png`/`wall_brick.png`/`wall_plain.png`/`wall_wood.png`) se
recortaron de nuevo tomando la COLUMNA COMPLETA del sheet original (ambas
filas, 48×96px) en vez de solo la fila de abajo (48×48px) — de paso suma un
detalle de remate/moldura real en la parte de arriba de cada material
(estaba ahí en el pack, no se inventó), no es solo estirar la textura vieja.
Reescalado al mismo factor 2/3 de siempre: 32×64 en vez de 32×32. No hizo
falta tocar código — `StructureTileset._add_sources()` ya calculaba
`texture_origin` de forma genérica para CUALQUIER tile más alto que una
celda (la misma fórmula que ya resolvía puerta/ventanas), así que la pared
más alta quedó bien anclada (parada sobre su propia celda, creciendo hacia
arriba) sin ningún ajuste nuevo. La ventana/puerta/antorcha pintadas encima
siguen alineadas bien contra la base de la pared, sin cambios.
**Todavía sin implementar — vista de interior:** el pedido original también
incluía que la pared de atrás se vea COMPLETA (no angosta) desde adentro, y
que la pared de adelante no se vea o se vea "recortada estilo Sims" desde
adentro — eso requiere un sistema nuevo (detectar cuándo el jugador está
DENTRO del edificio y cambiar qué se dibuja) que hoy no existe: ahora mismo
si el jugador camina bajo el techo simplemente queda tapado por él (mismo
z_index=50 de siempre), no hay una vista de interior real. Quedó
deliberadamente afuera de este pase — es una feature aparte, más grande, no
un ajuste de tileset.
Bug real que salió del primer render en vivo (no lo agarró ningún test
headless): al sacar el desplazamiento del roof layer, el techo quedaba
pintado en la MISMA celda que su pared — un tile de 32x32 tapando otro de
32x32 encima, así que cualquier pared con techo arriba desaparecía por
completo bajo un techo plano. `_rebuild_structures()` ahora solo pinta techo
sobre las celdas interiores (piso, `Piece.FLOOR`); una celda que ya tiene
pared/esquina/puerta se queda sin techo encima y su pieza se ve. Confirmado
con un render real, no alcanzaba con el test de wiring (que solo miraba
`source_id`, nunca "se ve la pared o no").

**Implementado (prototipo) — decoración suelta:** categoría "DECORACIÓN" en
el build mode, con `DecorMarker` (`game/scripts/world/decor_marker.gd`) —
mismo patrón que `POIMarker`/el viejo `HousePieceMarker`: un prop suelto por
click, libre (no grid-snapped como "wall"), anclado abajo-al-centro. 15 props
recortados de `RawAssets/Props_Decor.png` del mismo pack de Hypnobius
(barril, cajón, cajones apilados, banderines, carreta, rueda de carreta,
arbusto, grifo de pared, cerca, jardinera, y 5 variantes de ventana). Cada
recorte se ajustó a su bounding box real por canal alfa (no a ojo) — un
primer intento ingenuo cortando por celda de 48px agarró de rebote parte del
cajón de la celda de al lado dentro del sprite del barril (las piezas de este
sheet a veces se tocan/superponen sin margen transparente entre celdas, así
que un corte por grilla no siempre alcanza); se corrigió acotando la altura
del recorte hasta el hueco real entre objetos, confirmado escaneando la
columna central en busca de píxeles transparentes. Sin colisión física
todavía, igual que el resto de build mode.

**Implementado (prototipo) — zoom de cámara en build mode + modo GM:**
pensado para mapear áreas grandes sin la vista de combate normal encima.
La rueda del mouse, mientras `Game.build_mode` está activo, aleja/acerca la
`Camera2D` del jugador entre zoom 1.0 (normal) y 3.5 (`world_zone.gd`,
`_zoom_build_camera()`); al salir de build mode el zoom vuelve a 1.0 solo
(`hud.gd`'s `_toggle_build_mode()`). Aparte, F2 (`Game.gm_mode`, cualquier
momento, no solo en build mode) da un modo de vuelo/no-clip: velocidad muy
por encima de la de combate, `collision_mask` en 0 (atraviesa paredes/
obstáculos) mientras está activo, cero daño recibido (`resolve_incoming_hit()`
corta antes de aplicar cualquier golpe, igual que ya hacía el chequeo de
i-frames) y click central del mouse (rueda) teletransporta al jugador donde
esté apuntando (`player.gd`'s `_unhandled_input()`). No reemplaza el estado
de combate normal — mientras `gm_mode` está activo el resto de
`_physics_process()` (ataques, stamina/mana, etc.) no corre, es un modo
aparte pensado solo para explorar/mapear.
Bug real reportado tras usarlo: el BuildPanel no tiene ScrollContainer, así
que una rueda de mouse sobre el panel nunca era "consumida" por la UI y le
llegaba igual al zoom de cámara — scrollear el panel zoomeaba el mundo de
fondo. `world_zone.gd`'s `_unhandled_input()` ahora chequea
`get_viewport().gui_get_hovered_control()` antes de aplicar el zoom: si hay
un control de UI bajo el mouse, no hace nada.

**Rearquitectura — kit modular de PixelLab, piezas colocadas a mano en vez de
auto-asignadas:** pedido explícito de subir la calidad de la herramienta de
mapeo — columnas, esquinas, paredes lisas, más completo — y de que el
jugador elija cada pieza en vez de que el código la infiera de los vecinos
(como venía haciendo el autotiling por bitmask del pase anterior). Auditoría
previa: el pack Hypnobius nunca tuvo arte de esquina/pilar real, así que el
bitmask terminaba componiendo un "rim" de sombreado procedural sobre una
textura plana en vez de dibujar una esquina de verdad — techo de calidad,
no un bug puntual.

1. **Kit nuevo vía PixelLab** (`mcp__pixellab__create_building_kit`,
   `tile_type="square_topdown"`, 32px directo — evita la pérdida de calidad
   por downscale 48→32 que el pack viejo tenía, documentada más arriba). Al
   pedirlo el kit devolvió mucho más vocabulario del esperado: pared por
   dirección (N/E/S/W), esquinas EXTERIORES **e** INTERIORES (dos sets, no
   uno — cierra un cuarto cóncavo, cosa que el sistema viejo no podía),
   columna/pilar, un set de **paredes de partición/interiores** con sus
   propios cruces, y un kit de techo completo: aleros, límatesas, **limahoyas
   (valles)** — algo que `docs/GDD.md`'s notas de v1 ya habían marcado como
   imposible con el pack anterior —, cumbreras en los dos ejes, remates y
   pirámide. 6 llamadas en total (piedra/ladrillo/liso/madera para pared,
   pizarra/roja para techo vía `floor2_description`, que el kit liga al
   "segundo piso/techo" en vez de a la pared) exportadas a
   `game/assets/world/structures/kit/`.
   **Diagonales a 45°, descartadas para este v1:** dos intentos de generación
   fallaron por razones distintas (con referencia de estilo, el modelo
   devolvió más paredes/esquinas en ángulo recto ignorando el pedido de 45°;
   sin referencia, devolvió renders de escena/interior en vez de piezas de
   tile planas). Paredes rectas + esquinas interiores/exteriores ya cubren
   cualquier planta rectangular o en L; diagonales quedan pendientes.
2. **`StructureMarker.piece`/`RoofMarker.piece`** (String) reemplazan la
   inferencia por vecinos como fuente de verdad del render — un dato por
   celda, estampado directo desde el botón de la paleta que se clickeó, igual
   de explícito que como ya funcionaba el material. `StructureGrid` perdió
   todo el cálculo de rol por vecinos (`Piece` enum, `compute_walls()`,
   `compute_wall_masks()`, el bitmask de 4 bits, `affected_by()`); conserva
   solo `RoofPiece`/`compute_roof()`, que sigue siendo el motor del relleno
   rápido por bounding box (tecla G) — "automático" y "manual" terminan en el
   mismo dato (`RoofMarker.piece`), así que un click manual puede pisar
   cualquier celda que haya puesto el auto-fill, y viceversa nunca hay dos
   sistemas de render compitiendo.
3. **Forma y material son ejes separados de verdad.** Antes "wall"/
   "wall_brick"/"wall_plain"/"wall_wood" eran 4 botones que en el fondo eran
   el mismo shape en 4 materiales — no había elección de FORMA. Ahora la
   paleta tiene un botón por forma (`wall_n/e/s/w`, 4 esquinas exteriores, 4
   interiores, partición×4+cruce, columna, piso — 19 ids de "ESTRUCTURA"; 20
   más de "TECHO (pintar)": aleros/límatesas/limahoyas/cumbreras/remates/
   pirámide/campo) y el material se elige aparte, como ya hacía el techo con
   R: `Game.build_wall_material` (tecla **Y**, cicla piedra→ladrillo→liso→
   madera). Catálogo total: 43 → 76 ids.
4. **Se eliminó el flujo de pintar en el editor de Godot** (`bake_tilesets.gd/
   .tscn`, el terrain `TERRAIN_MODE_MATCH_SIDES`, la capa `Walls` autotileada,
   `wall_mask_overlay.gd`/F3) junto con `WallTileset` — decisión explícita:
   con piezas manuales en el build mode in-game, mantener un segundo sistema
   de autotile en paralelo (para el mismo arte, con una lógica distinta) era
   más código para divergir, no una herramienta que se fuera a usar. El
   pack viejo de Hypnobius (wall/floor/roof, no las ventanas/puerta/antorcha,
   que siguen del mismo pack) se borró del repo por quedar sin ningún
   consumidor.
5. **`StructureTileset` reescrito**: una tabla `piece_id -> {material_id ->
   source_id}` para paredes y otra para techo, en vez de los `WALL_MATERIALS`/
   `WALL_TOP_MATERIALS`/`ROOF_FIELD`/`ROOF_RIDGE`/`ROOF_EAVE` del pack viejo.
   El anclaje "centrado + empujar hacia arriba por el sobrante" que ya se
   había medido contra un render real (ver el fix de anclaje más arriba) se
   generalizó sin cambios — las piezas del kit nuevo llegan todas al mismo
   canvas 52×87 (32×32 de celda + margen para la altura/perspectiva "low
   top-down" de 2 pisos de pared), así que una sola fórmula cubre pared,
   esquina, columna, piso y techo por igual.
6. **Piel visual del build mode — pivot durante la sesión.** Pedido aparte:
   mejorar la UI del panel para que no se vea "pelada" (tema por defecto de
   Godot sin ningún StyleBox propio). Primer intento con
   `create_ui_asset` de PixelLab (piedra+madera, remaches) salió bien, pero
   al mostrar referencias reales de New World quedó claro que esa UI es
   **plana** — panel negro translúcido, borde dorado fino, sin talla ni
   textura — y que una herramienta de pixel art no iba a dar ese look por
   más que se le pidiera "sobrio" (un segundo intento sin referencia de estilo
   se acercó pero seguía leyéndose pixelado). Se cortó la generación por IA
   para el chrome del panel: `game/resources/ui/build_panel_theme.tres` (un
   `Theme` de Godot, `StyleBoxFlat` a mano) aplicado al `BuildPanel` en
   `hud.tscn`, con cascada automática a los botones que `hud.gd` sigue
   armando por código desde `BuildCatalog` — cero cambios de lógica.
   Confirmado con un render real (nuevo dev tool
   `tools/ui_theme_screenshot.gd`), no solo mirando los valores del `.tres`.
7. Test suite ajustada a la nueva forma: `validate_structure_grid.gd` perdió
   los tests de rol-por-vecinos/bitmask (esa API ya no existe) y ganó
   cobertura de `roof_piece_id()`; `validate_build_mode.gd` reescribió su
   sección de rendering para probar el wiring pieza→material→source_id en
   vez de una forma computada. Se borraron dos dev tools que existían
   específicamente para juzgar el autotile por vecinos
   (`wall_configs_screenshot.gd`, `pack_expansion_screenshot.gd`) — sin ese
   mecanismo, no tenían nada que mostrar. 982 checks, ALL GREEN.
Todavía sin: diagonales a 45° (ver arriba), colisión física de paredes
(sigue siendo la misma limitación de siempre), y multi-cuarto real para el
auto-fill de techo (`compute_roof()` sigue operando sobre un solo bounding
box por zona — ahora importa menos porque las limahoyas manuales sí pueden
tapar la unión entre dos construcciones, pero el auto-fill en sí no cambió
en ese sentido).

**Fix — se había perdido el alero norte al reescribir `_rebuild_structures()`:**
reportado como pedido ("el techo debería taparlo todo desde afuera, salvo la
pared de frente"). La versión vieja tenía un paso extra — repetir la celda de
techo más al norte una fila más arriba, porque una pieza de pared es más alta
que una celda y su mitad de arriba sube a la fila que el techo (una celda por
celda) no llega a cubrir — que se cayó en la Fase 5 al simplificar el pintado
de techo a leer `RoofMarker.piece` directo, sin el post-procesamiento que
antes operaba sobre el `Dictionary` intermedio. Repuesto en
`_rebuild_structures()`: por cada celda de techo pintada, si la celda al
norte no tiene techo ni pared propia, se repite el mismo `source_id` ahí.
Aplica igual a techo automático (G) y pintado a mano, porque opera sobre el
resultado ya pintado, no sobre cómo se decidió cada celda. Confirmado con un
render real (antes: banda de pared gris asomando arriba del techo oscuro;
después: el techo tapa limpio hasta el borde).

**Ajuste — alineación de piezas tocable a mano:** el usuario pidió poder
ajustar alineaciones sueltas sin depender de otro pase de código.
`StructureTileset._add_piece_source()` pasó de recibir un `extra_raise: int`
(solo usado por `WALL_DECOR_RAISE`) a un `nudge: Vector2i` genérico —
positivo mueve el sprite derecha/abajo (al revés del `texture_origin` nativo
de Godot, para poder pensarlo en términos de pantalla normales) — y
`StructureTileset.PIECE_OFFSETS` (vacío por default) permite un corrimiento
en píxeles por `piece` id, aplicado a los 4 materiales de esa forma por
igual (comparten el mismo tamaño de canvas). Dos formas de tocar la
alineación sin volver a pedirle a Claude que edite código: (1) editar
directamente el PNG en `game/assets/world/structures/kit/<material>/
<piece>.png` (el ancla se calcula solo del tamaño del canvas, así que mover
el contenido dentro del canvas mueve el sprite en pantalla), o (2) sumar una
entrada a `PIECE_OFFSETS` con el nudge en píxeles. Verificado que el cambio
de firma no rompió el anclaje existente de puerta/ventana/antorcha con un
render real (la ventana y la antorcha siguen levantadas del piso, la puerta
sigue al ras).

**Fix — el fix del alero duplicaba piezas de techo sueltas:** reportado en
uso real ("el techo por alguna razón ahora genera 2 sprites en lugar de 1")
inmediatamente después del fix anterior. Causa: la extensión hacia el norte
se aplicaba a CUALQUIER celda de techo, sin distinguir si esa celda en
verdad estaba tapando una pared (con arte más alto que su celda, que
necesita el alero) o era una pieza de techo suelta pintada a mano sobre
pasto — sin pared debajo, no hay nada que tapar, y la extensión la
duplicaba en dos tiles visibles. Acotado a `if not piece_cells.has(cell):
continue` antes de extender — solo se repite la celda de techo que cae
justo encima de una `StructureMarker` real. Verificado con dos renders (una
pieza suelta ahora es un solo tile; la habitación techada sigue tapando el
remate de la pared trasera) y con dos asserts nuevos en
`validate_build_mode.gd` (uno por caso, para que esta regresión puntual no
se vuelva a colar sin que la suite se queje).

**Fix — puerta/ventanas/antorcha regeneradas al tamaño del kit nuevo:**
reportado ("hay que redimensionar las ventanas/puertas para que encajen en
los nuevos tamaños"). El pack Hypnobius viejo (door.png/window_*.png/
torch.png) seguía en pie desde antes del rearme — su escala se pensó contra
la pared vieja de 32×64, y contra el canvas nuevo de 52×87 (más alto) leían
chicas. Se regeneraron con PixelLab (`create_tiles_pro`, sin
`style_images`): un solo pedido numerado con 6 piezas contra una pared de
piedra descripta a mano, `tile_size=32`/`tile_height=84` explícito para que
el canvas de salida ya tenga la proporción real de la pared nueva en vez de
un tile plano de 32×32 (primer intento, sin `tile_height`, salió a esa
escala vieja — se nota comparando ambos intentos, no a ojo). Salieron 16
variaciones, se eligió una por tipo (puerta, ventana chica/mediana/grande/
arqueada/con jardinera, antorcha) y se sobreescribieron los mismos 7
archivos que ya usaba `StructureTileset.WALL_DECOR` — cero cambios de
código en el mecanismo de wall_decor, la puerta y las ventanas siguen siendo
compartidas entre los 4 materiales de pared (igual que en el pack viejo, eso
no cambió). `WALL_DECOR_RAISE` se resetió a 0 en los 7 (los valores viejos
se habían medido contra el canvas viejo y no traducen) — un primer intento
de volver a levantar ventana/antorcha del piso con valores a ojo se
descartó tras renderizar (las alejaba del piso más de lo esperado); 0 ya
se ve bien porque esta vez se le pidió al generador que centrara el
contenido dentro del canvas en vez de dejarlo pegado abajo. Nota: la ventana
"grande" y la "mediana" salieron del mismo pedido con la misma descripción
(dos variaciones, no dos tamaños reales) — quedan visualmente parecidas;
diferenciarlas de verdad queda pendiente si hace falta.

**Fix — el primer intento no matcheaba el estilo del kit:** reportado con
captura real ("los nuevos generados no coinciden con los materiales
generados previamente"). Causa: el primer pedido describió la pared desde
cero en texto ("plain gray stone wall") en vez de referenciar el arte real
del kit — PixelLab no es determinístico entre llamadas separadas aunque el
prompt sea parecido, así que el linework/sombreado/paleta salieron
parecidos pero no iguales. Reintentado con `style_images` apuntando al
`wall_s.png` real ya generado (52×87, el mismo canvas que la pared, así que
de paso quedó resuelto el tamaño sin tener que pedir un `tile_height` a
mano) — a diferencia del intento fallido de diagonales de la Fase 0 (que
fallaba por pedir una GEOMETRÍA que la referencia no tenía), acá la
geometría "abertura en una pared plana" ya está en la referencia (la propia
pared), así que el estilo copió bien. Un job de esta tanda quedó
inusualmente lento (~35 min en vez de los 1-3 min habituales, causa no
identificada del lado de PixelLab) pero terminó solo mientras se evaluaba
cancelarlo. Mismos 7 archivos reemplazados, mismo mecanismo de
`WALL_DECOR` sin cambios de código; esta vez además la ventana "mediana" y
la "grande" salieron en tamaños realmente distintos (ver capturas), no solo
dos variaciones del mismo pedido.

**Fix — el estilo matcheaba pero seguía habiendo costura, por composición:**
reportado con captura ("los nuevos generados no coinciden con los
materiales generados previamente" — se veía una banda de piedra ligeramente
distinta alrededor de la ventana/puerta). Causa real, distinta de la del fix
anterior: cada pieza de `WALL_DECOR` seguía siendo "una pared entera con el
objeto adentro" — al pintarse ENCIMA de la celda de pared ya pintada (así
funciona el overlay, ver `_rebuild_structures()`), quedaban DOS paredes
independientes superpuestas, y por más que el estilo matcheara, ninguna
generación separada reproduce el mismo patrón de ladrillo pixel a pixel —
de ahí la costura visible. Solución (pedida explícitamente): generar cada
pieza como objeto AISLADO con fondo transparente
(`mcp__pixellab__create_map_object`, pensado para esto) en vez de "pared
con objeto" (`create_tiles_pro`) — así el overlay deja ver la pared real de
abajo en todos lados menos donde está el objeto en sí. `background_image`
+ `inpainting` (máscara custom por tipo: puerta =  rectángulo alto llegando
al piso, ventana/antorcha = óvalo centrado) usando la misma `wall_s.png`
como referencia de estilo.
Dos problemas nuevos en el camino:
1. La imagen de referencia completa (52×87) fallaba al decodificar del lado
   del servidor ("unrecognized data stream contents") de forma consistente,
   pese a verificarse válida en un roundtrip local — un límite de tamaño/
   transmisión no documentado para este parámetro. Se resolvió reduciendo la
   referencia a 32×54 (mínimo que acepta la herramienta) antes de mandarla;
   con eso decodificó bien.
2. Consecuencia de lo anterior: al auto-detectar el canvas de salida desde
   una referencia más chica, los objetos volvieron a salir chicos contra la
   pared real de 52×87 — mismo síntoma del primer fix, causa distinta. Se
   reescalaron x1.625 (52/32) con `NearestNeighbor` antes de guardarlos como
   assets finales.
El torch salió prácticamente en blanco en el primer intento (máscara
demasiado chica) y se regeneró con un óvalo más grande y una descripción
más explícita — mejoró pero sigue leyendo más como un aro abstracto que
como un brazo de hierro; queda como pendiente si hace falta insistir.
`window_large` no tiene arte propia todavía en este pase — reusa el archivo
de `window_medium` como placeholder temporal.

**Fix — máscara de inpainting mal puesta (centrada, no la custom):** reportado
con captura ("quedaron feos los modelos, la puerta debería estar alineada al
pie de la pared, las ventanas deberían ir entre los dos tiles de la pared").
Causa: para evitar el problema de decodificación del fix anterior se había
cambiado de máscara CUSTOM (rectángulo alto pegado abajo para la puerta,
óvalo centrado para ventana/antorcha) a los modos automáticos `"rectangle"`/
`"oval"` de la herramienta — que centran el área en el canvas completo, no
donde hace falta. La puerta terminó flotando a media pared en vez de tocar
el piso. Solución: máscaras custom de nuevo, esta vez ya redimensionadas a
32×54 (la referencia chica que sí decodifica) en vez de a 52×87 — la puerta
con un rectángulo alto que llega hasta el borde inferior del canvas, las
ventanas con un rectángulo centrado en la franja media (ni pegado arriba ni
abajo, la lectura de "entre los dos tiles de la pared"). De paso mejoró la
calidad visible del detalle (líneas de tablas en la puerta, cruces de
plomo en el vidrio) — probablemente al usar una máscara más alta/ajustada en
vez del óvalo genérico, hay más lugar para dibujar detalle reconocible.
El torch tuvo un intento más (van 4 en total): describirlo como antorcha
CON llama en vez de solo el brazo de hierro apagado — una llama naranja es
una silueta mucho más reconocible a este tamaño que un gancho de hierro
abstracto, y esta vez sí quedó clara. Confirmado con render real: puerta al
ras del piso, ventana centrada en la pared, antorcha con llama visible, sin
costura en ningún caso.

**Fix — ventana un poco alta:** ajuste fino tras otro render real,
`WALL_DECOR_RAISE` de las 5 ventanas de 0 a -8 (ver la nota de signo de
`_add_piece_source()` — negativo baja la pieza). Sin regenerar arte, un
solo número por tipo.

**Fix — wall_e/wall_w no conectaban con las esquinas:** reportado con
captura (dos bloques de pared sueltos, flotando, sin tocar la esquina de
al lado). Medido por primera vez el bounding box real de contenido no
transparente de cada pieza (antes solo se había mirado "a ojo" en la
auditoría de Fase 0): `wall_e`/`wall_w` tienen su contenido en y=[7,30] de
un canvas de 87px, mientras que `wall_n`/`wall_s`/las esquinas llegan hasta
y=63-78. La fórmula de anclaje (misma para todas las piezas, centrada en
X + al ras abajo) asume que el contenido visual llega cerca del borde
inferior del canvas — para `wall_e`/`wall_w` eso deja ~57px de canvas vacío
entre la pieza y el piso, que se ve como el tramo de pared flotando separado
del resto. No es un bug de la fórmula (que sigue siendo correcta y compartida
por todas las piezas) sino que el arte de estas dos piezas específicas del
kit es más corta que el resto. Corregido con la tabla `PIECE_OFFSETS` que ya
existía para esto: `wall_e`/`wall_w` con un nudge de +48px hacia abajo, para
que su contenido termine cerca de y=78 igual que las esquinas sur. Verificado
con un render real de una habitación completa: las paredes laterales ahora
conectan sin salto visible entre la fachada y la pared trasera.

**Fix real — wall_e/wall_w no eran arte de pared, eran un poste con remate:**
el fix anterior (offset +48) solo corregía la posición contra UNA esquina;
con una fila larga de `wall_e` seguida (reportado con captura: bloques
sueltos como cuentas de un collar, sin conexión entre sí) quedó claro que el
problema era más profundo. Al hacer zoom real al contenido de `wall_e.png`
(antes solo se había medido el bounding box, nunca mirado de cerca) se vio
que la pieza en sí es una banda horizontal (remate/cornisa) sobre un poste
delgado — un diseño de "poste con tapa", no un tramo de pared lisa — así
que ninguna cantidad de desplazamiento la iba a hacer tilear consigo misma:
cada copia repite su propio remate, y eso es el efecto "cuentas de collar".
Mismo defecto confirmado en los 4 materiales (mismo bounding box exacto en
piedra/ladrillo/liso/madera).
Solución: en vez de pedirle a PixelLab una cuarta ronda de generación,
`wall_e.png`/`wall_w.png` se reconstruyeron **recortando el borde este/oeste
de `wall_s.png` de cada material** (una imagen ya validada, con mampostería
real que sí tilea) — el borde este de una pared vista de frente ES,
físicamente, la misma mampostería que se vería mirándola de canto. Sin
generación nueva, sin costura, y la pieza quedó con la misma altura de
contenido que el resto (y=22 a 79), así que el offset manual de la vez
anterior se sacó por completo — ya no hace falta. Verificado con un dev tool
nuevo (`tools/sidewall_column_screenshot.gd`) que reproduce exactamente el
caso reportado: una fila de 6 `wall_e` más una esquina abajo. Resultado: una
pared continua de punta a punta, sin ningún salto.

**Limitación conocida — wall_e/wall_w no calzan con una esquina NORTE:**
reportado con dos capturas más ("se ve horrible", "debería alinearse con la
vuelta de la esquina", "solo se debería ver la parte de arriba"). Investigado
a fondo con mediciones reales de bounding box por columna (no a ojo):
- `corner_out_se`/`sw` (esquinas SUR) tienen su brazo este/oeste ALTO
  (y=7 a 78, casi el canvas completo) — por eso el fix anterior (recorte
  angosto del borde de `wall_s`) calza perfecto contra una esquina sur.
- `corner_out_ne`/`nw` (esquinas NORTE) tienen ese mismo brazo CORTO
  (y=7 a 30 nada más) — mucho más angosto que el recorte de `wall_s`, así
  que ahí sí se nota un salto/escalón donde una pared lateral se topa con
  una esquina norte.
Probado un segundo enfoque (usar el ancho COMPLETO de `wall_s`, igual que
`wall_n`, para que `wall_e`/`wall_w` calcen con cualquier esquina en ancho)
— resuelve el salto contra la esquina norte, pero rompe el caso más común
(una habitación real): la pared lateral se vuelve tan ancha como el piso
interior y lo pisa, dejando una hendidura visible. Ninguna de las dos
versiones gana en los dos casos con una sola pieza estática — haría falta
una pieza de catálogo separada para "pared lateral que arranca de esquina
norte" vs. "que arranca de esquina sur", lo que hoy no existe. Decisión con
el usuario: por ahora se mantiene la versión angosta (mejor para el caso
común, habitaciones reales) y el salto contra esquinas norte en una fila
aislada queda como limitación conocida, no bloqueante.

**Fix definitivo — la textura correcta ya estaba ahí, era la banda de
remate:** el usuario marcó con capturas exactamente qué estaba mal: el
recorte de `wall_s` usado hasta acá traía la textura de la CARA de la pared
(la mampostería con junta de mortero, más oscura) en vez de la vista desde
arriba de una pared lateral, que tiene que verse como la superficie
superior — más clara. Midiendo fila por fila el propio `wall_n.png` (antes
solo se había medido el bounding box de contenido, nunca el color por fila)
se encontró la banda exacta: y=8 a 15 es un color PLANO y uniforme
(116,121,124 en piedra, sin ninguna variación de píxel a píxel) — el remate/
cornisa de la pared — y recién en y=16 arranca la mampostería con junta.
Un color completamente plano tilea sin costura por definición, así que
`wall_e.png`/`wall_w.png` se reconstruyeron repitiendo esa banda de 8px
verticalmente hasta cubrir todo el rango y=7-79 (el mismo que usan las
esquinas), en vez de usar un solo recorte más alto de la cara oscura. Este
cambio resolvió LOS TRES problemas reportados a la vez: el color/diseño
ahora es el correcto (vista de arriba, clara), tilea perfecto consigo mismo
en una fila larga, y calza sin salto contra CUALQUIER esquina (norte o
sur), porque el remate es del mismo color plano en toda la pieza — ya no
hace falta elegir entre "se ve bien en la habitación" o "se ve bien en la
fila sola", las dos cosas salen bien con la misma pieza. Aplicado a los 4
materiales. Verificado con los dos dev tools (`sidewall_column_screenshot.gd`
con esquina en las dos puntas, y `structure_screenshot.gd` con la
habitación completa).

**Ajuste — el remate no puede ser un color 100% liso:** pedido explícito
("debería mantener ese color pero tener cortes de piedra") tras ver el
resultado anterior — la banda plana de 8px es, literalmente, un solo color
sin ningún detalle, y aunque tilea perfecto se lee como plástico, no como
piedra. En vez de inventar una textura nueva, se tomó un ciclo completo de
la mampostería real (16px, con sus juntas de mortero) y se reescaló cada
canal de color por el cociente `remate_promedio / mampostería_promedio` —
misma sombra relativa entre bloque y junta, tono general llevado al del
remate en vez de al de la cara oscura. Aplicado a los 4 materiales.
Resultado: se ven las divisiones de piedra individuales sin perder el tono
claro pedido. Mismos dos dev tools confirman que esto no reintrodujo el
salto contra las esquinas ni rompió la habitación.

**Fix — el mapa se regeneraba en cada Play, invisible en el editor:**
pedido explícito ("necesito que el mapa ya se vea generado en el editor, no
que se genere al darle Play"). Causa: a diferencia de Ground/Roof/
Structures (que ya viven baked en `pradera.tscn` desde el pase "mapear a
mano", ver más arriba), la capa `Floor` (pasto/tierra con Wang) SOLO se
pintaba en runtime, dentro de `_build_floor()`, llamada desde `_ready()` —
abrir la escena en el editor mostraba el nodo `Floor` completamente vacío, y
cada Play la recalculaba desde cero (con semilla fija, así que el resultado
siempre es igual, pero el trabajo se repetía y no había nada que mirar ni
tocar a mano en el editor). Mismo patrón que ya se usa para las otras capas:
1. `_build_floor()` ahora revisa si `$Floor` ya tiene celdas pintadas
   (`get_used_cells()`) y si las tiene, no vuelve a pintar — solo repone el
   `tile_set` si faltara. Una escena nueva sin hornear (su `Floor` arranca
   vacío) sigue cayendo en la generación procedural de siempre, así que esto
   no rompe un escenario de test nuevo.
2. `tools/bake_floor.gd`+`.tscn`: instancia `pradera.tscn` SIN agregarla al
   árbol (así `_ready()` completo —spawn de jugador, registro en `Game`,
   HUD— nunca corre, ningún efecto colateral fuera de `Floor`), llama
   `_build_floor()` directo, y vuelve a empaquetar y guardar la escena
   completa. Correrlo una vez horneó las 4275 celdas del mapa actual
   directo en `pradera.tscn` (el `TileSet` de pasto queda como sub-resource
   con sus texturas por `ExtResource`, no como píxeles crudos — el .tscn
   pasó de sin piso a 88KB, nada exagerado). Hay que volver a correrlo si
   cambia `world_size`/`dirt_coverage`/`dirt_patch_scale`, porque ahora el
   runtime ya no repinta solo.
De paso, encontrado en el mismo pedido: `pradera_markers.tscn` (donde
"Guardar zona" persiste lo construido en build mode) estaba con el nombre
cambiado a `.tscn.parked` desde hacía dos días — probablemente un tool de
capturas de este mismo proyecto lo dejó así a mitad de una corrida anterior
sin restaurarlo. Mientras estuvo así, el juego no tenía nada que cargar y
arrancaba siempre con el layout base de `pradera.tscn`, sin lo guardado.
Restaurado al nombre correcto; el archivo en sí solo tenía mobs/recursos,
no estructuras, así que no se perdió construcción alguna en el proceso —
pero es la clase de estado que puede pasar desapercibido si un tool externo
se corta a mitad de camino, vale la pena tenerlo presente.

**Build mode en el editor — `EditorPlugin` real, no solo Play:** pedido
explícito ("¿no se puede agregar una tool al editor? en Unity lo hice") tras
explicarle la limitación de edición manual por Inspector — quería la
experiencia real de un editor tool tipo Unity: un dock, click en el
viewport 2D, la pieza aparece ahí mismo, sin darle Play. Se armó
`game/addons/build_mode_editor/` como `EditorPlugin` de Godot 4, habilitado
en `project.godot` (`[editor_plugins]`):

- `build_dock.gd`: mismo panel de paleta que `hud.gd` ya arma en juego
  (categorías/botones/iconos leídos de `BuildCatalog`/`BuildIcons`, así que
  agregar un id nuevo sigue sin tocar dos lugares), pero con estado propio
  (`tool_active`, `selected_kind`, `wall_material`, `roof_material`) en vez
  de leer el autoload `Game` — un autoload solo existe corriendo el juego,
  no mientras se edita una escena, así que el dock no puede depender de él.
  `tool_active` arranca en `false` a propósito: un click cualquiera en el
  viewport 2D (mover un nodo, seleccionar) no debe empezar a colocar piezas
  hasta activarlo explícitamente.
- `plugin.gd`: `_handles()` solo reclama escenas que tengan un nodo
  "Markers" (así no roba clicks en escenas sin build mode); convierte el
  click del viewport a coordenadas de mundo y arma el marker (`StructureMarker`/
  `RoofMarker`/`GroundMarker`/`DecorMarker`/mob/recurso/POI) igual que
  `world_zone.gd._instantiate_marker()` en runtime, pero sin tocar `Game` en
  ningún punto (mismo motivo que el dock). Colocar y borrar pasan por
  `EditorUndoRedoManager` (`get_undo_redo()`), no por `add_child()` directo —
  es lo que da Ctrl+Z real dentro del editor y lo que marca la escena como
  no guardada; sin eso, colocar piezas en el editor no dispararía el aviso
  de "hay cambios sin guardar" y sería fácil perder trabajo. Después de
  cada colocación/borrado llama `zone._rebuild_structures()`/
  `_rebuild_ground()` (los mismos métodos que ya usa el runtime, confirmado
  que no dependen de `Game`) para repintar el sprite real en el momento,
  no un gizmo de color.
- Bug real encontrado al validar en headless (`godot --headless --editor`,
  la única forma de chequear un `EditorPlugin` sin abrir la ventana): el
  dock se creaba como `Control.new()` con el script de `build_dock.gd`
  pegado encima, pero ese script hace `extends PanelContainer` — Godot
  rechaza asignar un script a un nodo de un tipo nativo distinto al que el
  script declara ("Script inherits from native type 'PanelContainer', so it
  can't be assigned to an object of type 'Control'"). Fix: instanciar
  `PanelContainer.new()`, no `Control.new()`.
**Fix — colocar una pieza en el editor no pintaba nada:** primera prueba real
del usuario: el marker se colocaba (el gizmo cuadrado azul/dorado aparecía)
pero el sprite real nunca se veía. Causa: `Structures`/`Facade`/`WallDecor`
(y las tablas `piece -> source_id` que `_rebuild_structures()` necesita) se
crean en `_build_structures()`/`_build_ground()`, llamadas únicamente desde
`_ready()` — que solo corre al darle Play, nunca por estar editando una
escena. `_rebuild_structures()` se corta al toque si esas capas no existen
(`get_node_or_null(...) == null → return`), así que en el editor el marker
se agregaba pero el repintado real jamás pasaba de esa primera línea.
Fix en dos partes:
1. `_build_structures()` ahora reusa capas existentes vía `_ensure_layer()`
   para `Structures`/`Facade`/`WallDecor` (antes solo `Roof` lo hacía) —
   necesario para que llamarla más de una vez sea seguro, ya que el plugin
   de editor la dispara por fuera del ciclo de vida normal de Play.
2. Nuevo método público `world_zone.gd.ensure_render_layers()` (llama
   `_build_ground()` + `_build_structures()`, nada más — sin spawnear
   entidades vivas, registrar en `Game` ni leer el layout guardado, todo
   eso Play-only y sin sentido en modo edición) que `plugin.gd` invoca una
   vez por sesión de edición, antes de la primera colocación/borrado.
Verificado con `godot --headless --editor` (carga sin error) y
`run_tests.ps1` (985/985) — el click-to-place en sí sigue sin poder probarse
sin la ventana real del editor, pendiente de confirmación del usuario.

**Fix — el plugin dejaba de recibir clicks apenas se seleccionaba otra
cosa:** primera prueba real completa del usuario. Dos bugs encadenados:
1. Las dos piezas de prueba (`piece = "eave_s"`) quedaron guardadas dentro
   de `pradera.tscn` en algún momento (Ctrl+S o autoguardado), contaminando
   el mapa base que usan los tests ("pintar pared no debe tocar el techo"
   fallaba porque esas dos celdas de techo YA estaban ahí antes de que el
   test tocara nada). Sacadas del `.tscn`.
2. La causa real de "ahora no pone nada": Godot solo reenvía clicks del
   viewport 2D a un plugin que "reclamó" el nodo ACTUALMENTE SELECCIONADO
   vía `_handles()`/`_edit()` — pero clickear en el viewport reselecciona
   lo que haya debajo del cursor (en la práctica, casi siempre `Floor`, el
   TileMapLayer que cubre todo el mapa), lo cual le saca el "reclamo" al
   plugin en el primer click y lo deja bloqueado para siempre, sin importar
   qué se seleccione después a mano. Fix: `set_input_event_forwarding_
   always_enabled()` en `_enter_tree()` (que Godot reenvíe SIEMPRE, sin
   depender de selección) + una `_current_zone()` que resuelve la zona
   activa desde `get_editor_interface().get_edited_scene_root()` — la
   ESCENA abierta en el viewport, no el nodo seleccionado. Ahora da lo
   mismo qué esté seleccionado en el árbol/Inspector; lo único que importa
   es qué pestaña de escena está abierta.
Verificado con headless (`--editor`, carga sin error) y `run_tests.ps1`
(985/985). El click-to-place real sigue pendiente de confirmación del
usuario — sin ventana real no hay forma de simular el mouse desde acá.

**Fix real — `world_zone.gd` sin `@tool` daba una "instancia placeholder"
en el editor:** con logging agregado paso a paso en `plugin.gd` (impreso a
la pestaña "Salida") se aisló el corte exacto: el click SÍ llegaba, el
marker SÍ se creaba (confirmado: aparecía en el árbol), pero
`_edited_zone.call("ensure_render_layers")` tiraba, en la pestaña
"Depurador → Errores" (un panel aparte de "Salida", por eso no se veía
antes): `Invalid call function 'ensure_render_layers (via call)' ...
Attempt to call a method on a placeholder instance. Check if the script is
in tool mode.` — el error exacto de Godot para "este script no es `@tool`".
Un script sin `@tool` adjunto a un nodo mientras se está EDITANDO (no
jugando) recibe una instancia placeholder: expone las `@export` para el
Inspector pero no permite invocar métodos reales — de ahí que colocar el
marker funcionara (es un script `@tool` aparte) pero repintar nunca.
Fix: `@tool` en `world_zone.gd`, con `_ready()`/`_unhandled_input()`
guardados por `Engine.is_editor_hint()` al principio, para que ninguno de
sus efectos de Play (spawnear jugador, registrar en `Game`, convertir
markers de mob/recurso/POI en entidades vivas) dispare por estar editando
— exactamente el mismo comportamiento de antes se sigue viendo solo al
darle Play de verdad. `run_tests.ps1` en 985/985 confirma que el guard no
rompió nada del lado runtime. Pendiente: confirmación visual real del
usuario, ahora que la causa de fondo está resuelta.

**Fix — lo ya guardado no se veía al abrir la escena, solo lo recién
colocado:** confirmado con el fix del `@tool` de arriba: colocar una pieza
la pintaba, pero guardar/cerrar/reabrir la dejaba invisible otra vez. Causa:
el repintado real (`_rebuild_structures()`/`_rebuild_ground()`) solo se
disparaba como efecto secundario de que el PLUGIN colocara o borrara algo
— nunca por el simple hecho de abrir la escena, así que cualquier pared/
techo ya guardado de una sesión anterior arrancaba sin pintar hasta la
primera interacción. Con `@tool` ya puesto, `_ready()` ahora SÍ corre en
el editor (antes de este fix directamente cortaba con un `return`) — se
aprovechó eso para que, en modo editor, llame `ensure_render_layers()` +
`_rebuild_structures()` + `_rebuild_ground()` apenas se abre la escena,
pintando todo lo que ya esté guardado sin necesitar tocar nada. Sigue sin
llamar `_load_markers_override()` ni spawnear entidades vivas — eso
seguiría siendo Play-only, mezclarlo acá pisaría el contenido autoría de
"Markers" con el archivo de guardado de una partida jugada, algo que abrir
el `.tscn` para editar nunca debería hacer. `run_tests.ps1` 985/985.

**Mejora — mobs/recursos mostraban un círculo de color en vez del sprite
real:** pedido explícito tras ver que las paredes ya se pintaban bien. No
era un bug — `MobSpawnMarker`/`ResourceNodeMarker` siempre dibujaron un
gizmo de color a propósito, mismo patrón que Unity para un spawn point sin
prefab asignado — pero como el resto del build mode ahora sí muestra arte
real, un círculo al lado se sentía inconsistente. Ambos SÍ tienen arte real
disponible (no son casos "no hay arte, hace falta el gizmo"):
`ResourceNodeMarker._draw()` ahora carga la misma textura que
`ResourceNode.ART_PATHS` usa en runtime (tree/rock/vein.png), escalada al
mismo `visual_radius` que `zone_builder.gd._build_resource()` termina
usando (24px para vena, 26px default) — así el preview no solo se ve real,
coincide en tamaño con la entidad que realmente se genera.
`MobSpawnMarker._draw()` dibuja el frame "idle" del slime
(`MobSprites.build_slime()`, cacheado una vez ya que hoy todo mob comparte
el mismo SpriteFrames) teñido con `body_color`, igual que
`chase_mob.gd`'s `sprite.modulate = body_color` en runtime. El círculo de
color se mantiene como fallback si el arte no carga (mismo criterio "nunca
un placeholder silencioso" que ya usa `structure_tileset.gd`). No confundir
con las piezas de pared/techo — esas SÍ eran un bug real (ver los tres fixes
anteriores); esto es una mejora de fidelidad visual sobre un gizmo que
siempre funcionó como estaba pensado. `run_tests.ps1` 985/985.

**Nota de diseño — por qué gizmo dibujado y no un Sprite2D hijo real:**
pregunta explícita del usuario pensando en el MMORPG final, no solo en el
editor. Lo que importa para eso es el costo en PRODUCCIÓN (servidor +
clientes con potencialmente miles de entidades), no en el editor. El
`_draw()` propio, gateado por `Engine.is_editor_hint()`, tiene costo CERO
fuera del editor: ni se ejecuta en el cliente (donde `ZoneBuilder` ya
reemplazó/acompañó al marker con la entidad real) ni en un servidor
dedicado headless (que no renderiza nada en absoluto). Un Sprite2D real
como hijo necesitaría ocultarse/liberarse a mano en runtime para no
duplicar el sprite con la entidad ya spawneada — trabajo extra para llegar
al mismo cero, con más riesgo de bug (doble render) en el camino. De paso,
revisando esto se encontró un descuido real: `ResourceNodeMarker._ready()`
llamaba `_load_texture()` sin ese guard, cargando una `Texture2D` en
memoria en CADA marker de recurso incluso en el juego real, donde
`_draw()` nunca la usa (la usa solo el editor). Corregido — ahora
`_load_texture()` solo corre bajo `Engine.is_editor_hint()`, tanto en
`_ready()` como en el setter de `kind`. `MobSpawnMarker` ya estaba bien
(su carga de textura solo ocurre dentro de `_draw()`, que corta antes por
el mismo guard). `run_tests.ps1` 985/985.

**Feature — agrupar markers en "prefabs" reutilizables (casas):** pedido
explícito: armar una casa una vez y poder replicarla, el equivalente a un
Prefab de Unity. En Godot ese equivalente ya existe (cualquier rama del
árbol se puede guardar como su propia escena e instanciarse las veces que
haga falta) pero no funcionaba acá: `ZoneBuilder.collect_structures()`/
`collect_roofs()`/`collect_ground()`/`build()` y las búsquedas por celda de
`world_zone.gd`/`plugin.gd` solo miraban **hijos directos** de "Markers" —
agrupar las piezas de una casa bajo un nodo contenedor las hacía
invisibles para el repintado, porque ya no eran hijos directos.
Fix: `ZoneBuilder._all_descendants()` (recorrido recursivo nuevo) y los
cuatro `collect_*()`/`build()` pasan a usarlo en vez de `get_children()`
plano — nesting pasa a ser puramente una conveniencia de autoría, sin
efecto en qué se pinta. Los lookups por celda de `world_zone.gd`
(`_structure_marker_at`/`_roof_marker_at`/`_ground_marker_at`) se
reescribieron para reusar `ZoneBuilder.collect_*()` en vez de duplicar la
búsqueda; `plugin.gd` recibió el mismo tratamiento. Dos lugares necesitaban
además filtrar "es un marker de verdad" (`_is_marker()`, nuevo en ambos
scripts) para no confundir el nodo contenedor del grupo con una pieza real:
el chequeo de espaciado de contenido libre (`is_placement_valid()`/el loop
de `_place()`) y el borrado por proximidad (`_remove_nearest_marker()`/
`_remove_nearest()`) — sin el filtro, acercarse al ORIGEN del grupo
bloqueaba colocar algo ahí, o clickear cerca de una casa agrupada borraba
el contenedor entero en vez de una pieza. De paso, `_remove_nearest()` del
plugin capturaba mal el padre para el undo (siempre asumía "Markers" como
padre) — si la pieza borrada estaba anidada, Ctrl+Z la resucitaba mal
puesta, suelta bajo "Markers" en vez de donde realmente estaba; ahora
captura `closest.get_parent()` real antes de borrar.

Flujo real para "armar una casa y replicarla" (Godot, no un botón nuevo,
son herramientas nativas del editor que ahora sí funcionan con este
sistema): (1) armar la casa con el plugin como siempre; (2) seleccionar
todos sus markers en el árbol (click + Shift/Ctrl); (3) click derecho →
"Reparent to New Node..." para agruparlos bajo un Node2D nuevo (ej.
"Casa1"); (4) click derecho sobre ese nodo → "Save Branch as Scene" →
guarda `casa1.tscn` y lo reemplaza in-place por una instancia de esa
escena; (5) para replicar, arrastrar `casa1.tscn` desde el FileSystem a
"Markers" (o Ctrl+D sobre la instancia ya puesta) las veces que haga
falta, y mover cada copia a su lugar. Pendiente de aviso al usuario: para
volver a EDITAR los markers de adentro de una instancia ya guardada como
escena aparte, Godot exige activar "Editable Children" en esa instancia
primero (protección nativa contra editar sin querer el contenido de un
prefab) — no se automatizó, es el flujo estándar de Godot y no hacía
falta reinventarlo. `run_tests.ps1` 985/985.

**Fix — el guardado local de zona (`pradera_markers.tscn`) tapaba lo
construido en el editor:** reportado como "ingame no se ve la estructura
que hice, me parece que al darle Play se carga otra cosa" — exactamente
eso: `_load_markers_override()` (llamada desde `_build_world()`, solo en
Play) reemplaza el nodo "Markers" entero por lo que haya en
`pradera_markers.tscn` si ese archivo existe, sin importar qué haya
autoría de verdad en la escena. Encontrado un archivo de esos, de una
sesión de Play anterior a que se armara la casa, sin una sola pieza de
estructura — por eso Play mostraba el mapa base de siempre. Renombrado a
`.stale_backup_20260831` (reversible; no tenía contenido único, mismo set
de mobs/árboles/rocas/venas que ya vive baked en `pradera.tscn`).

Decisión explícita del usuario al preguntarle si desactivar esto por
completo, dado que el juego va a ser multiplayer: un archivo de override
LOCAL por cliente nunca tuvo sentido para un MMO server-authoritative (ver
"Economía y monetización"/"Riesgos" — anti-dupe y autoridad de servidor
desde el día 1), y durante esta etapa de armar contenido a mano activamente
mordía. Fix: `_build_world()` ya NO llama `_load_markers_override()` — la
escena de la zona, autoreada a mano en el editor, pasa a ser la única
fuente de verdad que Play lee, mismo principio que `ensure_render_layers()`
ya documentaba del lado editor. El botón "Guardar zona" del `BuildPanel`
(y su handler `_on_build_save_pressed()` en `hud.gd`) se sacaron del todo
— dejarlo hubiera sido peor que no tenerlo: el jugador cree que guardó su
progreso y en realidad escribe a un archivo que ya nadie lee. `Game.get_world()`
sigue teniendo el flag; nada de esto es relevante para `SaveButton` de
`PausePanel` (`SaveSystem`/`_on_save_pressed()`), que es el guardado real
de partida (inventario/oro/etc.) y no se tocó.

`save_markers_layout()`/`_load_markers_override()`/`_markers_override_path()`/
`_reown_recursive()` quedan en el script sin llamarse desde el flujo normal
— siguen cubiertas por el round-trip de `validate_build_mode.gd` ([2] y
[9]), por si el mecanismo de pack/instantiate sirve de base el día que
haya guardado real del lado servidor. `run_tests.ps1` 985/985.

**Fix — el alero (eave) del techo se veía "acolchado"/ondulado en un techo
real:** reportado con captura de una casa completa ("es un desastre").
Causa, confirmada mirando los PNG de cerca: `eave_n/e/s/w` tienen cada uno
una silueta con relieve propio (tipo teja en abanico) — se ve bien como
pieza única, pero al repetirse pegada una al lado de la otra en todo un
borde, esas muescas se acumulan en el patrón ondulado reportado. `interior`
("campo"), en cambio, es plano y ya tilea perfecto (es la pieza de relleno
masivo). Mismo diagnóstico y misma solución que el saga de `wall_e`/
`wall_w` de esta sesión: en vez de regenerar con PixelLab, se reconstruyó
cada `eave_*` recortando la textura YA PROBADA de `interior` en el mismo
bounding box que ocupaba el eave original (`eave_n`=y[42,87), `eave_s`=
y[24,79), `eave_e`=x[0,42), `eave_w`=x[10,52), sobre el canvas 52×87
compartido) — mismo footprint/anclaje que antes, mismo tono, pero sin la
silueta que no tileaba. Aplicado a los 2 materiales (`roof_slate` y
`roof_red`, mismos bounding box en ambos). Nuevo dev tool
`tools/roof_wide_screenshot.gd/.tscn` (cámara mucho más alejada que
`structure_screenshot.gd`, pensado para juzgar un borde completo, no solo
la fachada) confirma el resultado: borde recto, esquinas límatesa limpias,
sin ondulado. `run_tests.ps1` 985/985.

**Cambio de diseño — el techo pasa a cubrir también la pared frontal:**
pedido explícito del usuario, revirtiendo a propósito una decisión tomada
antes en esta misma sesión (el look "Stardew/Zelda" donde la fachada sur
se veía completa por encima del techo). Hasta ahora `generate_roof_over_
walls()` ("G") saltaba deliberadamente la fila frontal (`FRONT_FACING_
PIECES`: `wall_s` y sus esquinas), y una capa "Facade" aparte volvía a
pintar esa fila POR ENCIMA del techo (z=51 contra z=50) para que se viera
completa. Sacado todo eso: `generate_roof_over_walls()` ya no exceptúa la
fila frontal (solo sigue exceptuando celdas con puerta, por la razón de
siempre: una puerta que no se ve no sirve), y la capa "Facade" se eliminó
por completo — `_build_structures()`/`_rebuild_structures()` ya no la
crean ni la pintan. Ventanas/antorcha en la pared frontal ahora se ocultan
igual que en cualquier otra pared si el techo las cubre (mismo mecanismo
que ya exceptuaba puertas, sin cambios ahí). Actualizados los tests que
afirmaban el comportamiento viejo de Facade en `validate_build_mode.gd`
([10]); de 985 a 983 checks totales (se sacaron 2 aserciones que ya no
aplican, no hay checks nuevos que agregar acá). Confirmado con
`roof_wide_screenshot.tscn`: la fachada sur ya no asoma por encima del
techo, solo la puerta queda visible. `run_tests.ps1` 983/983.

**Fix — el alero sur no pegaba bien con las esquinas (este/oeste sí):**
reportado apenas visible el techo cubriendo la fachada. Causa, confirmada
comparando píxeles: `hip_sw`/`hip_se` tienen un remate con textura
"acanalada" (tejas/listones) a lo largo de su borde recto (no el borde en
diagonal — ese es la línea de límatesa), y el `eave_s` reconstruido en el
fix anterior (recortado de `interior`, textura de puntitos redondos) no
tenía nada de esa textura — de ahí el corte visible en la costura. Un
diff de píxeles confirmó además que `interior.png` y el borde limpio de
`hip_se` NO son idénticos (media de diferencia ~8.6/255 incluso lejos del
corte diagonal) — son texturas generadas por separado, solo parecidas a
simple vista, así que ningún recorte de `interior` iba a calzar del todo.
Fix real: en vez de `interior`, `eave_s` se reconstruyó tomando el borde
limpio de CADA esquina que toca — la mitad izquierda (x=[0,26)) copiada
del propio borde derecho limpio de `hip_sw` (x=[26,52) en su canvas), la
mitad derecha copiada del borde izquierdo limpio de `hip_se` (x=[0,26)) —
mismo patrón de "recortar de la pieza vecina real" que ya había funcionado
para `wall_e`/`wall_w`, esta vez con dos fuentes (una por lado) en vez de
una sola. `eave_n`/`eave_e`/`eave_w` NO se tocaron — confirmados por el
usuario como ya correctos. Aplicado a los 2 materiales (mismos bounding
box en `roof_red`, verificado antes de aplicar). Confirmado con una tira
compuesta `hip_sw+eave_s+eave_s+eave_s+hip_se` en Python (más confiable
que pelear con el encuadre de cámara del dev tool — su nota interna
documenta que el encuadre del borde sur quedó sin resolver del todo,
tapado por la hotbar del HUD). `run_tests.ps1` 983/983.

**Fix real — un solo click pintaba 2 celdas de techo, alero este/oeste se
veía como bloque grande "frontal":** reportado con captura ("no están de
costado, se ven frontales... el de la derecha pinté uno de más"). Causa
encontrada reproduciendo el caso exacto en un dev tool nuevo
(`tools/eave_repro_screenshot.gd/.tscn`, guardado como regresión
permanente): la extensión "sube una fila hacia el norte" que existe para
tapar el sangrado de una pared alta por encima de su propia celda
(`_rebuild_structures()`) se disparaba para CUALQUIER pieza de pared con
la celda de arriba vacía — no solo para paredes que dan al norte, que es
el único caso real donde hace falta. Al colocar `roof_eave_e`/`roof_eave_w`
sobre un tramo de pared este/oeste AISLADO (sin nada arriba, típico al
estar construyendo de a partes, no una habitación ya cerrada), esa
extensión se disparaba igual, duplicando la pieza una celda arriba y
armando un bloque de 2 celdas de alto que no se leía como alero lateral.

Primer intento de fix (restringir por el tipo de PARED debajo, ej. solo
`wall_n`/esquinas norte) rompió un test existente: `floor_cell` en
`_check_structure_rendering()` tiene un marker de PARED "floor" (sin
dirección) pero el relleno automático (`generate_roof_over_walls()`) le
pone ahí una pieza de TECHO `hip_ne` real — que sí necesita la extensión,
igual que la esquina vecina. Fix correcto: restringir por la pieza de
TECHO en sí (`NORTH_FACING_ROOF_PIECES = ["eave_n","hip_ne","hip_nw"]`),
no por la pared debajo — esas piezas de techo son las únicas cuyo propio
arte sube más allá de su celda (mismo motivo de anclaje que las paredes),
así que son las únicas que necesitan que se les tape ese sangrado copiando
la pieza una fila arriba. `eave_e`/`eave_w`/`eave_s`/etc. nunca lo
necesitaron — en una habitación real y cerrada esto nunca se notaba
porque toda pared este/oeste siempre tiene una esquina norte u otra pared
encima tapándola; solo un tramo incompleto (como el que armaba el usuario)
lo exponía. Agregado test de regresión en `validate_build_mode.gd`: una
`wall_e` aislada con un solo `roof_eave_e` encima debe pintar exactamente
esa celda, no la de arriba. `run_tests.ps1` 985/985 (2 checks nuevos).

**Regenerado — alero este/oeste se veía como bloque plano "frontal" en vez
de inclinado:** pedido explícito tras ver el fix de la duplicación
("deberían verse en diagonal, se ven como una aleta recta"). No había
backup del arte original (se pisó sin querer en un fix anterior de esta
misma sesión), así que se regeneró con PixelLab (`create_tiles_pro`, modo
`style_images` con una versión achicada de `hip_ne.png` como referencia de
estilo — mismo truco anti-corrupción de base64 de la saga puerta/ventana:
referencia chica, de ~1150 caracteres base64, no los ~2500 que dio el
recorte directo). El pedido explícito de "líneas diagonales de tejas,
como el corte de una esquina límatesa pero corriendo toda la pieza" dio
16 variaciones con buena definición diagonal, pero TODAS traían además un
recorte/muesca en la esquina (heredado de la referencia) que no tileaba
en una fila — mismo tipo de problema que ya se había resuelto para
`eave_s`: se recortó la franja limpia (sin muesca, ~20px de 32) de la
variación elegida y se repitió (wrap) para llenar el ancho completo,
antes de escalar ×1.625 al tamaño real de canvas (52×87, mismo truco que
puerta/ventana). `eave_w` es el espejo horizontal exacto de `eave_e` — no
hizo falta pedirle una segunda pieza a PixelLab. Para el material rojo no
se generó de nuevo: se recoloreó por el mismo cociente de canal
`rojo_promedio / piedra_promedio` que ya se usó para el remate de
`wall_e`/`wall_w`, calculado entre `interior.png` de cada material.
`run_tests.ps1` 985/985 — confirmado visualmente con
`eave_repro_screenshot.tscn`, pendiente de que el usuario lo vea en su
propia casa.

**Fix real — el techo dejaba residuo horneado que ningún repintado podía
borrar:** encontrado investigando por qué el fix de arriba rompió
`validate_build_mode.gd` (dos checks que asumían un techo vacío al
arrancar). Causa: el nodo `"Roof"` de `pradera.tscn` conservaba un
`owner` heredado de antes de esta re-arquitectura (cuando el techo SÍ se
guardaba a mano en el editor nativo) — así que cada vez que se guardaba
la escena con alguna celda de techo pintada, Godot horneaba esas celdas
como si fueran contenido de autoría real (`tile_map_data`/`tile_set`
quedaron literalmente escritos en `pradera.tscn`). El problema real:
`_repaint_owned()` solo borra las celdas que ÉL MISMO pintó en la sesión
actual (`_owned_cells`, que arranca vacío en toda instancia nueva) — así
que ese residuo horneado nunca podía limpiarse solo, ni sacando el
`RoofMarker` que lo originó ni con ningún repintado posterior; quedaba
ahí para siempre, celda fantasma sin ningún marker detrás. Fix en
`_build_structures()`: `roof_layer.owner = null` (para que un guardado
futuro ya no vuelva a hornearlo) + `roof_layer.clear()` (para borrar lo
que ya haya, ya que el techo es 100% derivado de `RoofMarker` ahora — no
hay ningún dato "real" viviendo en la capa en sí). Limpiado además el
residuo ya existente en `pradera.tscn` a mano. `run_tests.ps1` 985/985.

**Regeneración completa del kit de techo (20 piezas × 2 materiales):**
pedido explícito tras ver el resultado del fix puntual de `eave_e`/`eave_w`
("quedó completamente horrible... regenera todas las partes del techo,
más simple, y que pueda hacerse un techo en diagonal o uno con aleros
planos también"). Aclarado con el usuario: no son dos kits separados, es
un solo kit con estilo más simple y consistente, cuyas piezas de remate
(`end_n/e/s/w`) ya alcanzan para armar un techo a dos aguas estilo cabaña
a mano (sin límatesas), sin necesitar arte aparte.

Regenerado con `create_building_kit` (la misma herramienta que generó el
kit original) en vez de `create_tiles_pro` pieza por pieza — un solo
pedido con `floor2_description` describiendo explícitamente "textura
plana y simple, líneas diagonales de tejas claras en cada superficie
inclinada, nada de ruido ni detalle random" dio las 20 piezas de techo
(índices 60-79 de un building kit de 80) con estilo mucho más uniforme
que el kit viejo (que mezclaba puntitos redondos en `interior` con cortes
acanalados en las esquinas). De paso, el resultado vino con
`profile=gable` — el propio generador ya entiende este kit como un techo
a dos aguas con límatesas opcionales, no solo a cuatro aguas, coincide
con lo que pedía el usuario. Tamaño de salida 52×87 exacto (no hizo falta
el truco de escalar ×1.625 de rondas anteriores). Material rojo, igual
que las veces anteriores, no se generó de nuevo: recoloreado por cociente
de canal contra `interior.png` de cada material. `run_tests.ps1`
985/985, confirmado con `roof_wide_screenshot.tscn` (borde recto,
esquinas limpias, tira sur `hip_sw+eave_s+eave_s+eave_s+hip_se` sin
costura visible) — pendiente la confirmación del usuario en su propia
casa, que es lo que en definitiva importa acá.

**Fix real — las esquinas norte también se duplicaban con 1 clic:**
reportado ("las esquinas se ponen dobles con 1 clic") apenas probado el
kit nuevo. Causa: al arreglar la duplicación de `eave_e`/`eave_w`, la
condición de la extensión hacia el norte pasó a mirar SOLO el tipo de
pieza de techo (`NORTH_FACING_ROOF_PIECES`), sin exigir además que
hubiera una pared/piso real debajo (`piece_cells.has(cell)`) — ese
segundo requisito se había sacado sin querer al reescribir la condición.
Resultado: colocar `hip_ne`/`hip_nw` sola, sin nada debajo (probando una
esquina suelta, igual que el caso del alero), igual duplicaba la celda
hacia arriba, porque no hay ninguna pared cuyo sangrado tapar ahí. Fix:
la extensión ahora exige LAS DOS condiciones a la vez — pieza de techo
que da al norte Y una pieza real debajo — que es exactamente la
justificación original ("tapar el sangrado de LA PARED"). Agregado test
de regresión específico (`roof_hip_ne` suelto, sin pared, no debe
duplicar) además del de `eave_e` que ya existía — son bugs relacionados
pero con gatillos distintos, mejor cubrir los dos por separado.
`run_tests.ps1` 987/987 (2 checks nuevos).

**Fix — el techo tapaba la ventana/antorcha de la fachada:** reportado con
captura ("el alero debería ser más pequeño (medio tile) para que no tape
la ventana y la puerta"). El diagnóstico del usuario apuntaba a achicar el
arte del alero, pero la causa real no era de tamaño: `wall_decor` (puerta/
ventana/antorcha) usaba un chequeo binario por celda ("¿hay techo pintado
acá? entonces no pinto la ventana") sin ninguna noción de superposición
real en píxeles — un alero más chico no lo hubiera arreglado, seguiría
siendo todo o nada por celda. La puerta YA tenía una excepción ("nunca se
tapa, en ningún lado") por la razón obvia (una puerta que no se ve no
sirve); el fix extiende esa misma excepción a ventana y antorcha — tiene
sentido arquitectónico además: son aberturas/objetos en la CARA vertical
de la pared que se está mirando, no en el plano horizontal del techo, así
que el techo cubriendo esa celda estructuralmente no debería hacer
desaparecer lo que hay en la cara de la pared. Cambio puramente de código
(la capa `WallDecor` ya pintaba por encima del techo en z-order; solo
hacía falta dejar de saltear el pintado), sin arte nuevo. Confirmado con
`structure_screenshot.tscn`: puerta, ventana y antorcha visibles juntas
sobre el techo. `run_tests.ps1` 987/987 (sin tests nuevos — no había
ninguno que afirmara el comportamiento viejo).

**Fix — el alero achicado dejaba las esquinas más altas que el resto (y
por qué el fix de arriba no era lo que hacía falta):** el usuario insistió
en que el pedido original era correcto — el alero necesitaba ser más
chico VERTICALMENTE, el fix de la excepción de wall_decor (arriba) no
sustituía eso, aunque solucionaba un problema real aparte. Se recortaron
`eave_n/e/s/w` a la mitad de su alto (manteniendo el borde inferior fijo,
recortando desde arriba) en los 2 materiales — pero eso solo, dejando
`hip_ne/nw/se/sw` con su alto original, dejaba las esquinas sobresaliendo
por encima del alero recortado (reportado con captura: el borde de la
fachada quedaba disparejo, las esquinas más altas que el tramo con puerta
y ventana). Fix: las 4 esquinas se recortaron a la altura de la menor de
sus dos piezas de alero vecinas (`hip_se`/`hip_sw` al alto de `eave_s`;
`hip_ne`/`hip_nw` al alto de `eave_e`/`eave_w`, que quedó más bajo que
`eave_n`), para que el borde quede parejo en las cuatro direcciones.
Confirmado con una tira `hip_sw+eave_s+eave_s+eave_s+hip_se` y otra
`hip_ne+eave_e+eave_e+hip_se`: borde superior parejo en ambas. Efecto
secundario ya señalado y todavía sin resolver: como el techo ahora
sobresale menos, un poco de pared (la fila norte específicamente) asoma
por arriba del alero en la parte de atrás de la casa — pendiente de que
el usuario confirme si eso también hay que corregirlo o si así está bien.
`run_tests.ps1` 987/987.

**Fix real, con captura marcada — el corte iba al revés:** varias vueltas
fallidas antes de llegar acá (recortar altura sin tocar esquinas, después
con esquinas parejas, después un intento de mover el ANCLA en vez de
recortar contenido — confirmado con una pieza aislada,
`tools/eave_repro_screenshot.gd`, que eso dejaba el techo flotando
separado de la pared con un hueco, mal). El usuario mandó una captura con
una línea naranja marcando exactamente dónde debía cortar el alero, y ahí
se vio el error de fondo: todos los intentos anteriores recortaban
manteniendo la parte de ABAJO del contenido (pegada a la pared) y sacando
la de ARRIBA — cuando en realidad hay que hacer lo contrario: mantener la
parte de ARRIBA (la que se ve más lejos/más alta en pantalla) y sacar la
de ABAJO (la que pegaba contra la pared). Al sacar la parte de abajo, no
queda un hueco — la propia pared (capa "Structures", debajo del techo en
z-order) ya tiene su propia cornisa clara pintada ahí, así que esa cornisa
pasa a verse en vez del techo, sin ningún hueco ni pieza nueva. Recorte
final: `eave_s`/`hip_se`/`hip_sw` mantienen solo y=[24,44) de su canvas
original (antes y=[24,79)), descartando el resto. Confirmado pixel a
pixel contra la captura marcada del usuario (pieza aislada,
`eave_repro_screenshot.tscn`) y en contexto de una habitación completa
(`structure_screenshot.tscn`): techo arriba, cornisa/pared abajo, puerta/
ventana/antorcha visibles, sin huecos. Tira sur
`hip_sw+eave_s+eave_s+eave_s+hip_se` sigue pareja, sin costura.
`run_tests.ps1` 987/987.

**Ajuste — un poco más de alero, después de todo:** con la captura marcada
confirmada como el criterio correcto, el usuario pidió duplicar el alto
recién fijado (y=[24,44) → y=[24,64), el doble) — "el tamaño de lo
naranja+lo negro". Cambio de una sola línea numérica (mismo mecanismo de
recorte que el fix anterior, solo cambia el rango), sin volver a tocar
esquinas ni conexión con `hip_se`/`hip_sw`. `run_tests.ps1` 987/987.
Confirmado por el usuario ("Ahora sí") — cierra el saga del alero sur que
arrancó varios mensajes atrás.

**Ajuste — ventana/antorcha un poco más abajo (puerta sin cambios):**
pedido de seguimiento inmediato, ya con el techo resuelto. `WALL_DECOR_
RAISE` (ver su nota: "negative lowers a piece") pasó de -8 a -16 para
todas las ventanas, y de 0 a -8 para la antorcha; la puerta se dejó en 0
(nunca se reportó mal). Confirmado con `structure_screenshot.tscn`: puerta
en el piso, ventana y antorcha visiblemente más abajo que antes.
`run_tests.ps1` 987/987.

**Implementado (prototipo) — 4 tilesets Wang nuevos (agua, arena, piedra,
barro), solo el asset por ahora:** pedido: poder generar agua y varios
pisos distintos además del pasto/tierra que ya existía. Alcance acordado
con el usuario: generar el arte y dejarlo listo en el formato correcto,
SIN tocar `world_zone.gd`/`floor_tileset.gd` todavía — el agua es para una
futura zona costera (Fase 3), no para pintar dentro de Pradera ahora mismo.

Herramienta: `create_topdown_tileset` (PixelLab) — no es la misma que la de
los edificios (`create_8_direction_object`); genera directamente un Wang
tileset de 16 tiles (`transition_size=0.5`, `tile_size=32`, `shape_style=
"round"`) con la MISMA convención de índice que `floor_tileset.gd` ya usa
(`índice = NW*8+NE*4+SW*2+SE*1`, 1=terreno "upper"/superior) — confirmado
contra el recurso `pixellab://docs/godot/wang-tilesets` del propio server
antes de generar nada, no asumido.

Encadenados por continuidad visual (`lower_base_tile_id`/`upper_base_tile_id`,
feature nativa de la herramienta): agua→arena, después arena→pasto usando
el tile de arena de la primera hoja como base de la segunda — así el tono
de arena es idéntico en las dos. Piedra→pasto y barro→pasto van sueltos
(no forman parte de la misma cadena costa→interior).

Paso NO trivial: la hoja que devuelve la herramienta (128×128, sin gutter)
NO está en el orden secuencial 4x4 que asume `floor_tileset.gd` — cada
tile trae su propio `bounding_box` en los metadatos JSON, y hay que
recortarlo de ahí (nunca de `original_position`, que es la grilla de
generación y puede tener filas fuera de esta hoja — el propio recurso
avisa que usar eso produce bandas horizontales). Se escribió un conversor
de una vez (`build_wang_sheet.ps1`, no vive en el repo): lee el JSON,
recorta cada tile por su `bounding_box`, y lo recompone en un canvas de
131×131 con gutter de 1px en el índice Wang correcto — el MISMO formato
exacto que `grass_dirt_wang.png` (documentado en `docs/ART.md`), para que
integrarlo después sea directo. Validado con un script headless propio que
repite la lógica real de `FloorTileset._add_wang_source()` contra las 4
hojas antes de darlas por buenas (los 4 registran sus 16 tiles sin
warnings) — sin tocar ningún archivo del juego para probarlo.

Archivos nuevos en `game/assets/tiles/`: `water_sand_wang.png`,
`sand_grass_wang.png`, `stone_grass_wang.png`, `mud_grass_wang.png`.
Pendiente (día que se necesiten): un `WaterTileset.gd`/generalización de
`FloorTileset.gd` para registrar más de un terrain set por zona, y decidir
en qué zona/momento se pintan (¿`GroundMarker` nuevo tipo "biome", pintado
a mano en build mode? ¿procedural como el pasto/tierra actual?) — ninguna
de las dos cosas se resolvió todavía, a propósito, porque el pedido de
esta vez era solo el arte.

**Implementado (prototipo) — los 4 biomas quedan pintables a mano, pincel
de colisión independiente, y el editor pasa a crear zonas nuevas (no solo
decorar Pradera):** pedido de seguimiento explícito, con dos decisiones ya
tomadas por el usuario: colisión SIEMPRE manual (nunca automática por
bioma — reusable después para paredes, que hoy no colisionan) y alcance
"multi-zona de verdad", no solo pintar la zona que ya existe. Planificado
con `EnterPlanMode` antes de tocar código por el tamaño (toca
`world_zone.gd`, `plugin.gd`, `build_dock.gd`, `build_catalog.gd`,
`zone_builder.gd`, y suma 3 scripts nuevos) — plan en
`replicated-crafting-owl.md`, aprobado antes de empezar.

1) `BiomeTileset` (`game/scripts/world/biome_tileset.gd`) — construye UN
`TileSet` con 4 `terrain_set` (uno por par: agua↔arena, arena↔pasto,
piedra↔pasto, barro↔pasto), cada uno con su propio `TileSetAtlasSource`
sobre uno de los 4 PNG generados en el pedido anterior. `TerrainMarker`
(mismo esqueleto que `GroundMarker`) es la pieza que se coloca; categoría
nueva "TERRENO (pintar)" en el catálogo, 8 entries — una por cada lado de
cada par (agua, arena-costa, arena-interior, pasto-borde-arena, piedra,
pasto-borde-piedra, barro, pasto-borde-barro), NO un genérico "pasto"
único, porque Godot no hace blending entre `terrain_set` distintos (ver la
nota ya escrita en `BiomeTileset`'s class doc) — el jugador elige
explícitamente qué lado de qué par pintar, mismo espíritu que
`StructureMarker` no infiere vecinos. `world_zone.gd`'s
`_rebuild_terrain()` borra todas las celdas propias primero (una celda
pintada con un par y después con otro necesita partir de cero) y repinta
agrupando por `(terrain_set, terrain)` vía `set_cells_terrain_connect()`.
Capa "Terrain" nueva, entre Floor y Ground.

2) `CollisionMarker` (`game/scripts/world/collision_marker.gd`) — pincel
independiente de textura, categoría "COLISIÓN" (1 entry: "Bloquear celda").
No pinta ningún TileMapLayer ni tiene visual en juego (solo un cuadrado
rojo en el editor, vía `_draw()` tool-only) — `_rebuild_collision()` en
`world_zone.gd` mantiene un `StaticBody2D` de 32×32 por marker (crear/
liberar por diff, mismo patrón que `_marker_spawns` para mobs/recursos).
Deliberadamente Play-only: un body físico mientras se edita no hace nada,
y saturaría el árbol de la escena sin motivo.

3) Multi-zona — `build_dock.gd` suma una sección "Zona": un dropdown con
toda escena bajo `res://scenes/world/*.tscn` cuyo root tenga un hijo
directo "Markers" (mismo heurístico que `plugin.gd`'s `_current_zone()`,
pero inspeccionando `PackedScene.get_state()` en vez de instanciar), botón
"Abrir", y un campo + botón "Crear zona nueva" que arma el esqueleto
mínimo en código (`Node2D` + `world_zone.gd`, hijo "Floor"
`TileMapLayer` vacío, hijo "Markers" `Node2D` vacío), lo guarda en
`res://scenes/world/<slug>.tscn` y lo abre. La detección "es esto una
zona" tuvo un bug real al escribirla: `SceneState.get_node_path()` incluye
el "." del root como su propio segmento, así que un hijo DIRECTO del root
tiene `get_name_count() == 2`, no 1 como parecía obvio — encontrado
corriendo un script headless de diagnóstico contra `pradera.tscn`, no
asumido; quedó un comentario en el código citando el valor real. Verificado
también con un script headless separado que arma el esqueleto completo,
lo guarda, lo recarga, y confirma que `_build_floor()` realmente pinta
sobre él sin crashear (la escena minimal no cae en el mismo bug del nodo
"Floor" mal nombrado que apareció antes en esta sesión).

Selección de zona jugable desde `main_menu.gd` (hoy hardcodea una única
`ZONE_SCENE`) queda explícitamente fuera de esto — el pedido era la
herramienta de creación en el editor, no el flujo de juego.

**Implementado — "auto road": caminos curvos y en diagonal que se resuelven
solos por vecinos:** pedido explícito. Hasta ahora los caminos eran 207
entries sueltas en la paleta "SUELO" (`floor_road_adoquin_01` … 49, ×5
estilos): el arte para doblar YA estaba, pero encontrar a mano la pieza que
encaja en cada celda de una curva no es algo que nadie haga dos veces.

Lo primero fue medir el arte en vez de asumirlo. Las 207 piezas salieron de
hojas compuestas de CraftPix, y su forma está escrita en su propio canal
alfa: la pieza que va en el borde oeste de un camino es opaca en N/E/S y
transparente en W. Así que el mapeo máscara→tile NO se escribió a mano —
`game/tools/bake_road_autotile.py` lee el alfa de cada PNG (borde exterior
de cada lado, bloque 2×2 de cada esquina, umbral 128), arma la máscara blob
de 8 bits estándar, y genera `scripts/world/road_autotile_table.gd`. Esa
decisión es directamente la lección que ya está escrita en
`PaintedFloorTileset`: una tabla posicional hecha a mano se pudre apenas se
renombra un tile.

Dentro de cada máscara, la FRACCIÓN OPACA separa las variantes: la pieza más
llena de un bucket de esquina es la esquina redondeada (un mordisco chico),
la más vacía es el chaflán de 45°. De ahí sale lo que el pedido pedía:
`RoadAutotiler` elige redondeada para un codo suelto (= curva) y chaflán
para un escalón que forma parte de una tirada diagonal (= diagonal limpia).
La detección de "tirada diagonal" compara por FAMILIA de esquina (solo las
cardinales), no por la máscara cruda — se encontró rompiéndose justo en el
caso que más importa: la diagonal más fina que da una grilla cuadrada es una
escalera de 2 celdas, y sus escalones no tienen NINGÚN bit de esquina
prendido, así que comparar la máscara entera nunca biselaba. Hay un check
dedicado a eso en `validate_road_autotile.gd`.

**Corrección tras probarlo en el editor** (reporte: "no se están acoplando
realmente bien", con captura de un camino en `madera`). Dos causas distintas,
encontradas midiendo el arte:

- *Bug propio:* el bucket de máscara 255 NO son variantes de una misma
  textura — son los interiores de las distintas figuras decoradas que compone
  el pack (`losa` tiene 40: campo liso, panel con borde, losa con incrustación).
  Elegir una al azar por celda convertía cualquier camino ancho en un mosaico
  de patrones que no pegan. Ahora es UN relleno por estilo, elegido midiendo
  la costura contra sí mismo (`self_tiling_score()`: el salto ATRAVESANDO la
  costura comparado con la variación normal DENTRO del tile — no igualdad de
  píxeles, que un patrón repetido no tiene por qué cumplir).
- *Límite del arte, no del código:* `madera` y `losa` no son caminos en este
  pack, son plataformas con marco. Su borde oeste trae reborde arriba y abajo,
  así que un camino vertical largo sale como cajas apiladas. Verificado que no
  era una asignación invertida (las máscaras miden bien: `madera_17` es
  transparente en W, `madera_18` en E) y que la hoja original solo tiene UNA
  pieza de borde por lado. El pack sí dibuja un tramo largo continuo, pero
  fuera de la grilla de 16px, así que re-recortarlo parte el ornamento —
  trabajo de assets, no de código. Decisión del usuario: sacarlos del pincel.
  `run_seam()` en el baker lo mide (adoquin 50, ladrillo 73, piedra 23 vs
  madera 121, losa 183; presupuesto 100) y emite solo los que pasan, así que
  si algún día se re-recortan vuelven solos. `BuildCatalog` sigue siendo una
  lista const, pero `validate_road_autotile.gd` falla si se desincroniza de la
  tabla, y re-mide la costura sobre la textura real en vez de confiar en la
  nota del baker.

Dos límites reales del arte, medidos y documentados en vez de disimulados:

1. **Ancho mínimo 2 celdas.** El pack no trae ninguna pieza de camino de una
   sola celda de ancho — verificado escaneando las hojas ORIGINALES de 16px,
   no solo el set ya recortado. Así que el pincel de camino pinta siempre al
   menos 2×2 (`RoadAutotiler.brush_size_for()`). Se descartó a propósito la
   primera versión, que "empujaba" `Game.build_brush_size` a 2 al elegir el
   pincel: mutaba una preferencia del usuario a escondidas, y además rompió
   tests de placement ajenos apenas la paleta tocó ese botón. El mínimo se
   aplica a la salida y nunca se escribe de vuelta.
2. **Piezas que un estilo no trae** se cubren espejando una que sí tiene
   (los bits de transform de `TileSetAtlasSource`): "piedra" no tiene borde
   sur, y usa su borde norte volteado. Lo que no existe en ningún estilo
   (una calle de 1 celda) cae al relleno interior — visible como una tira de
   32px con bordes duros, que es el resultado honesto, no una celda vacía.

Sin tipo de marker nuevo ni cambio de formato de guardado: la celda sigue
siendo un `FloorTileMarker`, y su `tile_id` guarda `autoroad_<estilo>` — un
id que nombra un PINCEL en vez de una pieza. `_rebuild_floor_tiles()` ya
repintaba la capa entera desde cero, así que la dependencia con los vecinos
(colocar una celda cambia hasta ocho) salió gratis.

Esto NO contradice el "sin autotiling" de `PaintedFloorTileset`: lo que se
probó y se sacó ahí es el sistema de TERRAIN por esquinas de Godot sobre los
tiles de Plains, que no sabe expresar un camino de una celda y zigzaguea.
Esto es otro mecanismo (máscara blob plana), sobre otro arte, y es opt-in
por pincel — las 207 piezas sueltas siguen intactas en "SUELO".

Verificación en dos niveles, porque la headless sola no alcanzaba:
`validate_road_autotile.tscn` (57 checks, sumado a `run_tests.ps1`) prueba
la matemática de máscaras, que las 256 máscaras resuelvan a algo, y el
camino completo placement→"Suelo"→repintado→undo. Pero un espejo aplicado al
revés pasaría todo eso sin despeinarse, así que `tools/road_screenshot.tscn`
renderiza las cinco figuras que importan (recta, codo, escalera hacia abajo,
escalera hacia arriba, plaza) por estilo, para mirarlas. Ahí se ve que las
escaleras salen como bandas de 45° con bordes rectos y paralelos — y ahí se
vieron también las dos fallas de la corrección de arriba, que la headless
había pasado sin despeinarse.

Tecla nueva en build mode: `[` / `]` cambian el ancho del pincel de suelo
(1–6), la convención que ya usa cualquier editor de tiles. El ghost previsualiza
la huella completa que va a pintar el click.

**Implementado — "PINCEL (libre)": pincel redondo con textura, sin grilla ni
autotile:** pedido explícito tras el auto-road ("¿no hay una forma de pincel
redondeado? tipo pincelado libre de photoshop con textura, para caminos de
tierra"). Es la primera capa de suelo del proyecto que NO es un
`TileMapLayer`, y esa es toda la idea.

Lo demás (Floor, Suelo, Structures, Roof) snapea a las celdas de 32px de
`BuildGrid`, y para cosas CONSTRUIDAS está bien. Un sendero no es una cosa
construida: forzarlo a la grilla da una escalera de bloques, y autotilearlo da
la forma que el tileset sabe expresar en vez de la que dibujaste. Así que
`PaintLayer` guarda una MÁSCARA DE COBERTURA y un shader
(`assets/shaders/painted_ground.gdshader`, el primero del proyecto) recorta una
textura repetida con ella.

Decisiones que importan:

- **Qué textura.** La máscara repite una textura por toda la zona, así que
  tiene que tesear consigo misma. De las 13 `tierra_*` del set Plains, 12 son
  BORDES de tierra-sobre-pasto; la única sin costura es `tierra_05` (medida: 1,
  contra ~85-94 de las demás). `validate_paint_layer.gd` lo re-mide con el
  mismo criterio que el baker de caminos, en vez de confiar en la lista — que
  es exactamente el error que el arte de caminos ya había hecho caer.
- **Resolución.** La máscara vive a la mitad de la resolución del mundo (~1MB
  por zona en vez de ~17MB) y NO cuesta nitidez, porque el shader umbraliza por
  PÍXEL DE MUNDO, no por texel de máscara.
- **El borde.** Un alpha suave sobre pixel art de 32px se ve como un blob
  vectorial pegado encima. El shader corre el umbral con ruido por bloques de
  3px (`jitter`, `jitter_px`), así que el contorno queda dentado y dibujado a
  mano, como los bordes tierra/pasto del propio set Plains.
- **Guardado.** La máscara se guarda DENTRO de la escena de la zona como un
  blob PNG (`mask_png`), igual que los markers ya se hornean ahí: ni un archivo
  extra que mantener sincronizado, ni paso de import, y el "guardar escena" del
  editor ya lo cubre. Se codifica en `NOTIFICATION_EDITOR_PRE_SAVE` — hacerlo
  en cada pincelada sería absurdo, y no hacerlo perdería el trazo.
- **Undo.** El stack existente es por markers; un trazo no tiene marker. Se
  agregó un paso `{"op": "paint"}` que guarda SOLO el rect sucio del trazo (no
  la máscara entera), capturado abriendo el trazo en el press y cerrándolo en
  el release — que es el momento en que ese rect se conoce. En el editor va por
  `EditorUndoRedoManager`, mismo contrato que el resto del addon.

**Un bug real que solo apareció renderizando:** la primera versión componía los
dabs con `Image.blend_rect()` (el camino rápido en C++), que es alpha-OVER. Un
arrastre deja cientos de dabs solapados, así que hasta un píxel de borde con
0.1 de cobertura saturaba a ~1: la caída del pincel colapsaba en un círculo
duro y el borde dentado desaparecía por completo. La captura lo mostró al
instante y ningún check headless lo habría visto. Ahora los dabs componen con
`max()` (lectura-modificación-escritura acotada al dab, barato), y hay un check
dedicado: tras 60 dabs solapados tiene que SEGUIR habiendo cobertura parcial en
el borde.

**Corrección tras probarlo en el editor** (reporte: "no pinta y además no es
circular, es cuadrado"). Dos fallas, las dos por asumir que el editor y el
juego comparten más de lo que comparten:

- `paint_at()` leía `Game.build_brush_size`. El doc de `plugin.gd` ya avisaba
  que el autoload `Game` es un concepto de Play y no está disponible editando
  una escena — es la razón explícita por la que el addon NO llama a
  `_place_marker()`. El radio ahora entra por parámetro y cada front-end pasa
  el suyo: el HUD el de `Game`, el addon uno nuevo del dock (slider "Pincel
  (radio)", 4-160px).
- El preview cuadrado: el editor no usa `build_ghost.gd` (es un nodo de
  runtime), dibuja su propio overlay con `BuildIcons.get_icon()` — o sea un
  cuadrito de textura. El círculo hubo que hacerlo también en
  `_forward_canvas_draw_over_viewport()`.

Y un tercer hueco que esto destapó: **ninguna suite cargaba el addon**, así que
un parse error en `plugin.gd` solo aparecía como "import reported N error
line(s)" mientras los tests seguían todos en verde — y el primer síntoma era la
herramienta entera muerta dentro de Godot. `validate_build_mode.gd` ahora hace
`load()` de los scripts del addon (devuelve null si no parsean).

**Ocho pinceles, y una lección sobre medir** (pedido: "¿se podrían hacer
varios pinceles texturados con ladrillos, piedras y demás?"). Sí — agregar una
entrada a `PaintLayer.TEXTURES` ES agregar un pincel. Quedaron: tierra, pasto,
agua, adoquín, ladrillo, piedra, losa y madera. Detalle que vale la pena:
`madera` y `losa` habían quedado FUERA del auto-road porque sus piezas de
BORDE no repiten — pero el pincel libre no usa bordes (el borde lo hace el
shader), así que como pinceles sirven perfectamente.

La lección: la métrica de costura **se equivoca justo en el ladrillo**. Compara
la costura contra la variación PROMEDIO del tile, y un ladrillo tiene casi
todas sus columnas planas salvo las juntas, así que cualquier costura que caiga
en una junta se penaliza sola (83, cuando tesela impecable). Se probó una
segunda medida (costura vs. la PEOR transición interna, no la promedio) que
arregla el ladrillo pero tampoco separa limpio: deja pasar `orilla` y rechaza
`acantilado`, las dos al revés de lo que se ve. Conclusión asumida en el
código: **la lista se cura mirando un render 3x3**, y el check automático
quedó documentado como humo — atrapa una textura que no repite en absoluto, y
nada más. `tools/paint_screenshot.tscn -- sampler` es el render que lo decide.

Con ocho pinceles apareció un costo que con dos no se veía: la zona crea una
capa por textura, y cada una reservaba su máscara al nacer — ~34MB por zona
aunque nadie pintara. Ahora la máscara se reserva **perezosamente**, en la
primera pincelada; una capa sin usar cuesta un nodo y nada más (`Sprite2D` sin
textura no dibuja).

El pincel monta sobre `[` y `]` como los otros (radio 16-96px en vez de celdas;
el toast dice cuál de las dos cosas), nunca snapea ni con T, y el ghost
previsualiza el círculo real en vez de un cuadrito de textura. Verificación:
`validate_paint_layer.tscn` (44 checks, sumado a `run_tests.ps1`) para la
máscara, el trazo/undo, el round-trip de guardado y el cableado de la zona; y
`tools/paint_screenshot.tscn` para lo único que no se puede medir, cómo queda
el borde.


**Implementado — buscador y filtro por categoría en el dock:** pedido al usar
la herramienta con el catálogo ya grande. La paleta pasó de una docena de ids
a varios cientos (los ~200 tiles de camino, 45 edificios, 8 pinceles) y
encontrar algo era scrollear. Ahora hay un campo de búsqueda —que matchea
contra la etiqueta **y** contra el id, porque se lo piensa de las dos formas
("herrería" es lo que dice el botón, "blacksmith" es como se llama el
archivo), e ignora tildes y mayúsculas— y un desplegable de categoría. Los dos
son de la vista y no del catálogo: filtran qué botones se dibujan, nunca qué
existe, y la selección activa sobrevive aunque el filtro la esconda. Un
contador ("42 de 340") evita la duda de si el filtro escondió algo. Redibuja
solo la lista de botones y no el dock entero, porque reconstruir todo perdía
el foco del campo en la primera letra.

**Implementado — un edificio es una escena, y entra al mundo con colisión:**
reportado como "que no sean solo sprites vacíos". Hasta acá un
`BuildingMarker` dibujaba un PNG plano y nada más: la casa no era un
obstáculo, se le caminaba por encima. El primer intento fue medir la huella
de los píxeles del sprite y hornear una tabla, y la corrección del usuario fue
mejor: **armar cada edificio como escena a mano**, con sus colliders puestos.
Es exacto donde la medición es aproximada, y deja lugar para lo que viene
(trigger de puerta, link al interior de la casa del sistema de lotes,
oclusión).

Entonces: si existe `scenes/world/buildings/<id>.tscn`, el marker la
instancia y esa escena *es* el edificio; si no existe, sigue el modo viejo.
Los dos conviven a propósito — convertir los 45 edificios es trabajo de a uno
y mientras tanto el catálogo entero sigue colocable. El nombre del archivo es
el id, así que una escena nueva aparece sola en la paleta y en el dock
(`BuildCatalog.scanned_building_ids()`) sin agregar una línea de código.

La decisión que importa: **la instancia se agrega sin `owner`**, y Godot solo
serializa lo que tiene owner, así que el `.tscn` de la zona guarda el marker
(id + posición) y nada más. Gracias a eso arreglarle el collider a una casa
arregla todas las ya colocadas; si se guardara la instancia, cada casa
quedaría congelada con la versión que había el día que se puso.

La otra: **el collider es la planta, no el sprite**. El arte es una fachada
casi de frente y el techo se dibuja hacia arriba sin ocupar suelo — un
collider del tamaño del sprite bloquearía cuatro tiles de pasto por los que se
tiene que poder caminar por detrás. `house_small_a` queda de referencia:
126x56 de collider contra 176x224 de sprite.

**Implementado — `tools/collider_editor.tscn`, para armarlos:** pedido
explícito ("agregame una escena para agregar colliders a los diferentes
models"). Se elige el edificio de la lista, se dibujan los rectángulos de la
planta sobre el sprite (arrastrar para uno nuevo, esquinas para
redimensionar, click derecho para borrar, rueda para zoom, Ctrl+Z) y "Guardar"
escribe la escena con el `StaticBody2D`, el `Sprite2D` anclado y un
`CollisionShape2D` por rectángulo. La grilla es de un tile del mundo, así la
planta se piensa en tiles. El ✓ en la lista marca qué edificios ya tienen
escena, que en una lista de 45 es la mitad del trabajo.

La medición por píxeles que se había descartado como fuente de verdad
sobrevive acá como **botón** ("Sugerir planta"): mide la caja opaca debajo del
alero —el ancho de cada fila crece mientras baja el techo, toca un máximo en
el borde del alero y cae cuando empieza la pared— y deja un punto de partida
razonable para corregir a ojo. Como automatismo mentía; como sugerencia
ahorra el 80% del trabajo.

Verificación: `validate_build_mode.tscn` suma 23 checks (2566 en total) — que
el marker instancie la escena y no dibuje además el PNG, que el cuerpo esté en
la capa 1 con área real, que el collider se apoye en el suelo y no flote a la
altura del techo, que cambiar a un edificio sin escena libere la instancia y
vuelva al sprite, que el catálogo no duplique un id al armarle la escena, y el
buscador/filtro del dock (tildes, búsqueda por id, filtro por categoría,
limpiar el filtro devuelve el catálogo completo). Lo que no se puede medir
—cómo se ve la herramienta— se miró con una captura real antes de darla por
buena.
---

## Economía y monetización

- Gold sinks: repair, AH tax, teleports y sobre todo el **impuesto de lote** — el sink que escala con el tier de la casa y rota el suelo de las ciudades (ver Housing)
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
- Casa simple (instanciada): lote comprable, un tier, interior decorable sobre grilla, cofres. Impuesto y tiers superiores quedan para Alpha/Beta

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
