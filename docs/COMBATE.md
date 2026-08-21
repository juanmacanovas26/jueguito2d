# Combate — Action Fighter × Imperium AO

## Principio

Peleas se deciden por **posicion, aim, dodge, lectura de animaciones y recursos** (stamina/maná/poise).  
El techo de DPS lo pone el **arma y la animación**, no cuántas veces cliqueás.

---

## Input

| Input | Acción |
|-------|--------|
| WASD | Movimiento libre 8 dirs |
| Mouse | Aim |
| **LMB tap** | Basic (warrior melee / mage free bolt) |
| **LMB hold** | Charge → Heavy (warrior: stamina) / Charged bolt (mage: **mana**) |
| **RMB** | Guard (block / parry / energy según estilo) |
| Space | Dodge roll |
| Shift | Sprint (stamina) |
| **Q / E** | Kit Warrior / Mage (prototipo) |
| 1 / 2 / 3 | Estilo defensa: Shield / Parry / Energy |

### Ataque por kit

| Kit | Basic (tap) | Charged (hold) | Recurso charged |
|-----|-------------|----------------|-----------------|
| **Warrior** | Melee light combo | Melee heavy | Stamina |
| **Mage** | Skillshot bolt (gratis, animation-lock) | Bolt grande / más dmg | **Maná (energía)** |
| **Archer** | Flecha (gratis, más rápida que el mago) | **Flecha perforante** (atraviesa enemigos, -10% dmg por cada uno) | **Stamina** |

**Ventaja del Mago:** el bolt **nunca falla** por accuracy/movimiento (es la ventaja de la clase; el skillshot ya es el "aim"). Melee sí tiene penalidad de miss si corrés/sprinteás.

**Ventaja del Arquero:** dispara **más rápido** que el mago (GCD menor) y su ataque cargado **atraviesa** enemigos, con **-10% de daño** por cada enemigo perforado.

### Defensa por arquetipo

| Estilo | Quién | Comportamiento |
|--------|-------|----------------|
| **Shield** | Tank / con escudo | Hold = block (mitiga daño, cuesta stamina). Primeros ~0.18s = parry perfecto |
| **Parry** | Asesino / melee liviano | Solo ventana timeada; fallar = full hit |
| **Energy** | Magos | Hold = barrera (mitiga, cuesta maná + drain) + parry early window |

Pocas teclas a propósito (legible en MMO).


---

## Movimiento

- Velocidad base + aceleración corta + fricción
- Sin tile-lock en combate
- Colisión continua contra world y entidades
- Sprint consume stamina
- Soft-grid solo housing (opcional)

### Dodge

- Duración total ~0.35–0.45s
- I-frames ~0.15–0.25s (centro del roll)
- Costo stamina alto
- CD mínimo o penalidad si se spamea
- Invulnerable a damage hitbox, no necesariamente a grabs/ults de boss (definir por skill)

---

## Ataques y animation-lock

Cada ataque tiene:

1. **Startup** — no hitbox aún; se puede cancel a dodge solo si la skill lo permite  
2. **Active** — hitbox ON  
3. **Recovery** — vulnerable; input buffer guarda 1 acción  

```
TiempoEntreHitsEfectivos = max(DuracionAnimacionArma, GCD_Global)
GCD_Global ≈ 0.30–0.40s
```

### Combos

- Máximo cadena corta: L → L → Finisher
- Finisher: más daño / stagger / knockback leve
- Whiff (fallar) deja recovery completo = skill de spacing

### Heavy

- Startup largo, active fuerte, recovery largo
- Más poise damage / armor break
- Castigable si se lee

---

## Anti click-spam (checklist de diseño)

- [x] Ataque atado a animación
- [x] Attack Speed del item escala duración de anim (no fire-rate de mouse)
- [x] Buffer de 1 input, no cola infinita
- [x] Stamina en dodge/sprint/heavy
- [x] GCD global corto
- [x] Poise: spam light no tumba un tank — y **no lo tumba nunca**: por decisión
  de diseño el ataque básico no interrumpe (ver "Interrupción" abajo).
- [x] Ranged con draw/reload o cast, no hitscan machinegun
- [ ] Server valida hit (range, arc, facing, timeline) — no hay servidor todavía;
  el hit se resuelve entero en el cliente.

**Test de aceptación:** en dummy con techo de AS, spamear M1 = mismo DPS que rhythm correcto de animación. En duel, gana quien dodgea y castiga recovery.

---

## Magia estilo híbrido

- Skills con **telegraph** (cast bar o glow)
- Proyectiles con velocidad (lead shots en PvP)
- AoE al suelo con delay de impacto
- Interrupts: hit con tag `interrupt` o stagger alto
- Maná + cooldowns
- Move-cast: 0% o 30–50% speed según escuela (balance)

No es “meditar 10s” como core; el recurso es maná + ventana de cast + posicion.

---

## Recursos del jugador

| Recurso | Uso |
|---------|-----|
| HP | Supervivencia |
| Maná | Spells |
| Stamina | Dodge, sprint, heavy, algunas skills físicas |
| Poise | Resistencia a stagger; se regenera fuera de hit |

---

## Clases — kits MVP (borrador)

### Guerrero

- M1 cadena 3 hits
- M2 heavy slash
- Skill: Shoulder bash (gap closer corto, stagger)
- Skill: Guard (reduce damage, stamina)
- Skill: Whirlwind corto (AoE melee)
- Ult: Berserk (AS/damage, glass)

### Mago

- M1 bolt skillshot
- M2 charged orb (más daño, más startup)
- Skill: Frost root zone
- Skill: Blink corto (CD largo)
- Skill: Nova AoE
- Ult: Meteor telegraph

### Arquero

- M1 shoot (draw time corto)
- M2 charged shot
- Skill: Caltrops / trap
- Skill: Dash atrás
- Skill: Multishot con spread
- Ult: Rain of arrows zone

### Clérigo (post-3 clases o 4ª)

- M1 sacred bolt
- M2 smite melee-range
- Skill: HoT zone
- Skill: timed shield (i-frames aliado o absorb)
- Skill: cleanse
- Ult: big heal burst channel

---

## Fórmulas base (punto de partida)

```
Damage = (Atk * SkillMul * HitMul - Def * DefFactor) * CritMul
Hit = hitbox overlap + server time valid (no solo % dice)
Crit = crit chance vs crit resist (menor peso que en AO pure RNG)
PoiseDmg = por arma/skill; baja el Poise del objetivo
Poise <= 0 → NO produce stagger por sí solo (ver "Interrupción")
```

## Skills — cómo están implementadas

Las skills son **datos**, no código: una fila en `SkillDB.SKILLS`
(`game/scripts/data/skill_db.gd`). `SkillCaster` las ejecuta y no conoce
ninguna en particular.

### Los tres modos de targeting

| Modo | Cómo se apunta | Cómo se contrarresta |
|---|---|---|
| `self` | sin objetivo (stances, dashes, AoE alrededor tuyo) | alejarse |
| `target` | **click sobre el sprite del rival** | **moverse: si el click no cae encima, fallás igual** |
| `ground_aoe` | círculo en el cursor, con telegraph y demora | **salirte del círculo antes de que caiga** |
| `skillshot` | proyectil dirigido al mouse | esquivar mientras viaja |

**`target` NO es tab-target.** Nada queda lockeado: el click se resuelve contra
lo que haya debajo en ese instante, y si el rival se corrió, perdés el recurso y
el cooldown igual. Eso es lo que hace que la **velocidad de movimiento sea el
counter** del point-and-click, y `click_slack` es la perilla de cuán perdonador
es el click.

Los tres se ganan moviéndose, sólo que en momentos distintos: `target` en el
click, `ground_aoe` durante el telegraph, `skillshot` durante el viaje.

### Cómo se lanza: apuntar y confirmar

Apretar la tecla **no lanza la skill: la arma**. Mientras está armada se dibuja:

- el **alcance** (círculo alrededor tuyo) — para ver si el objetivo está adentro
- el **área que afecta**, siguiendo al cursor y **clampeada al alcance**
- en skillshots, la **línea de tiro** y el cono de dispersión si tira varios

**Click izquierdo confirma. Click derecho o la misma tecla cancela.** Cancelar no
cuesta nada. Recibir un golpe también baja la mira.

El preview está clampeado al alcance real de la skill, así que **nunca te
promete un tiro que después el caster va a rechazar**. Y como el `SkillCaster`
vuelve a clampear por su cuenta, un cliente adulterado no puede lanzar más lejos
mintiendo en el preview.

Las skills `self` **también se apuntan**. No tienen objetivo, pero sí tienen algo
que mostrar: el whirlwind dibuja el círculo que va a barrer alrededor tuyo, y el
shoulder bash dibuja **hasta dónde te lleva la embestida** y qué golpea al
llegar. Como el dash viaja *al punto apuntado* (no es un impulso que frena donde
caiga), el preview no puede mentirte sobre dónde terminás.

### Timing

`startup` / `active` / `recovery` en **segundos**, nunca en frames. La animación
se estira para calzar en la ventana, no al revés. Por eso una skill se puede
re-resolver en un servidor sin depender del cliente.

El costo se cobra **al lanzar, no al pegar**: fallar cuesta igual.

### Interrupción

Una skill puede llevar `"interrupt": true` — es la única forma de interrumpir,
y hoy sólo la tiene `shoulder_bash`. El ataque básico nunca interrumpe (ver
abajo).

### Agregar una skill

Una fila en `SkillDB.SKILLS` y, si querés que sea casteable, el id en
`LOADOUTS` del kit. Nada más. El validador exige que tenga targeting válido,
duración, cooldown, algún costo, y que su animación exista.

### Skillshot perforante + detonación (arcane_bolt)

`arcane_bolt` no muere en el primer enemigo: `"pierce": 1` le deja atravesar
uno y seguir de largo. Cuando su vuelo por fin termina —**por el motivo que
sea**— suelta un estallido chico (`end_radius`/`end_damage_mul`/`end_vfx`, un
`Projectile.end_burst` armado en `SkillCaster._fire_projectiles`). Hay dos
motivos posibles y ambos disparan el mismo estallido:

- **Se le acaba el rango** (`projectile_life * projectile_speed`) sin pegarle
  a nada más — estalla en el aire, en la punta de su alcance.
- **Le pega a un segundo enemigo** y ahí se le acaba el pierce — estalla
  encima de ese segundo enemigo, mucho antes de llegar al final del rango.

Por eso el rango de `arcane_bolt` es corto (255px, contra los 510px que tenía
antes de agregarle esto): un perforante que además detona no puede tener el
alcance de un skillshot normal, o se vuelve el pick obvio por sobre todo el
resto del kit. Cualquier skillshot nuevo puede sumar esto con las mismas
cuatro claves (`pierce`, `end_radius`, `end_damage_mul`, `end_vfx`); sin
`end_radius` no pasa nada especial al terminar el vuelo.

### El efecto visual de impacto

Un `ground_aoe` puede declarar `"impact_vfx": "<effect_id>"`: un sprite que se
suelta en el punto donde de verdad pegó, escalado al `radius` real de la skill.
Se dispara **después** de resolver el hit (`SkillCaster._resolve_ground`), así
que un efecto feo o faltante nunca cambia quién recibió daño — es presentación
pura, igual que el resto del visual (`docs/ARQUITECTURA.md`).

El arte sale de la carpeta `Effects/` (planchas: una fila por color, una
columna por frame). Agregar uno nuevo:

```bash
python art_pipeline/vfx/slice_effect.py "Effects/Free/Part 1/03.png" 2 frost_vortex
```

Corta la fila `2` (0-indexed) de esa plancha en `game/assets/vfx/frost_vortex/frame_NN.png`,
sin reescalar ni recortar frames — el hueco al principio/final es parte del
timing del efecto (nace de una chispa, se disuelve). `VfxLibrary.frames_for()`
los lee de ahí; `SkillImpactFx.spawn()` los reproduce una vez a 24fps y se
destruye solo. El validador exige que todo `impact_vfx` declarado resuelva
frames reales — un id mal tipeado hoy falla en silencio (`VfxLibrary` devuelve
un array vacío en vez de error), así que el chequeo es lo único que lo
atrapa.

### El sprite del proyectil en vuelo

Un `skillshot` (o cualquier caller de `Projectile.setup()`) puede pasar
`visual_effect: "<effect_id>"` como último argumento: reemplaza el polígono
celeste liso por un sprite de `game/assets/vfx/<effect_id>/`, escalado al
mismo `radius` que ya definía el hitbox y **teñido con el `color` de siempre**
(`modulate`), así que el gradiente de carga o el color por kit se siguen
aplicando arriba del arte — por eso el arte se corta de la fila **blanca/gris**
de la plancha (desaturada), no de una fila de color. Sin `visual_effect` el
proyectil se ve exactamente igual que antes (mobs y el arquero no pasan uno).

Hoy hay tres bolas usadas por el mago, cortadas cada una de una plancha
distinta de `Effects/` para que se note la diferencia a simple vista:

| Uso | `effect_id` | Plancha | Frames |
|---|---|---|---|
| M1 básico (gratis) | `bolt_plain` | `Effects/Free/Part 8/388.png` | 1 (estático) |
| M2 cargado (maná) | `bolt_charged` | `Effects/2/Part 21/1032.png` | 1 (estático, más grande/denso) |
| `arcane_bolt` (skillshot) | `bolt_arcane` | `Effects/2/Part 36/1783.png` | 14 (loop girando) |

Un efecto con más de un frame gira en loop mientras viaja
(`Projectile.VFX_FPS`); con uno solo queda estático, sólo rotado hacia la
dirección de tiro. Cortar uno nuevo es la misma herramienta que la de arriba,
con `--start-col`/`--end-col` para quedarte sólo con el frame (o el tramo) que
sirve:

```bash
python art_pipeline/vfx/slice_effect.py "Effects/2/Part 21/1032.png" 5 mi_bola --start-col 7 --end-col 7
```

## Guard y escudo — regla de diseño

**El estilo SHIELD requiere un escudo equipado.** Antes podías levantar la
guardia con la off-hand vacía y mitigar igual, que era mitigación gratis.

- `has_shield()` mira el slot `secondary` y su `defense_bonus`.
- Cuánto frena el bloqueo lo decide **el escudo**: `shield_block_mul()` interpola
  entre dejar pasar 45% (escudo malo) y 15% (el mejor), según su `defense_bonus`.
  Así la off-hand es una decisión real.
- Sin escudo, el estilo SHIELD **cae a PARRY** en vez de no hacer nada: perder el
  escudo en pelea te deja defendiendo mal, no indefenso.
- `effective_defend_style()` es lo que usan el gameplay, el HUD y los FX — nunca
  el estilo elegido a secas.

## Arco y flechas — regla de diseño

**El arquero necesita arco y flechas equipados para disparar.** Antes el kit
ARCHER tiraba flechas gratis sin tener nada puesto — el kit era sólo un modo
de ataque, no dependía del equipo real.

- `has_bow()` mira el slot `weapon`: cualquier arma con `attack_anim ==
  "attack_shoot"` cuenta (hoy sólo el Slingshot), no un id hardcodeado.
- `has_arrows()` mira el slot `secondary` — **el mismo que usa el escudo**
  (ver arriba). El item `quiver` lo marca con `is_ammo: true`. Un arquero no
  sostiene escudo y carcaj a la vez: es la misma decisión de off-hand que ya
  fuerza al guerrero.
- Sin las dos cosas, `_start_charge()` rehúsa **antes** de entrar en CHARGE —
  ni siquiera se ve el windup de un disparo que no iba a salir.
- `multishot` pide lo mismo vía `"requires_bow": true` en su fila de
  `SkillDB`, chequeado en el `spend` callable de `_try_cast` antes de gastar
  stamina — fallar no cuesta nada, mismo principio que el resto de las skills.
- `caltrops` queda afuera a propósito: es una trampa que se tira con la mano,
  no una flecha.

## Interrupción — regla de diseño

**El ataque básico nunca interrumpe.** Ni a mobs ni a otros personajes, por más
poise damage que haya acumulado. Si un M1 pudiera trabar al rival, el combate se
vuelve el intercambio de stunlocks que todo el resto del diseño intenta evitar.

La interrupción llega **solo desde efectos que la piden explícitamente**: una
skill, un shoulder bash, un hit con tag `interrupt`. Nada de eso está
implementado todavía.

Eso convierte al **poise en una resistencia, no en un estado**:

| | |
|---|---|
| El poise baja con cada golpe | sí, ya funciona |
| Se regenera fuera de combate | sí, en `_physics_process` |
| Llegar a poise 0 aturde solo | **no, nunca** |
| Un efecto que interrumpe consulta el poise para ver si atraviesa | así se implementará |

`Health.is_staggered()` existe para que esos efectos futuros lo consulten. **No
lo conectes al camino normal de daño**: hay un test de regresión en
`tools/validate_systems.gd` que falla si un ataque básico llega a interrumpir.

El combat feel manda; los números se tunean en slice.

---

## PvE vs PvP

| | PvE | PvP |
|--|-----|-----|
| I-frames dodge | Más generosos | Más tight |
| Telegraph mobs | Muy legibles | Players = animaciones de kit |
| Tracking enemigos | Suave | Sin aimbot; proyectiles lead |
| Pack clear | Satisfying, 2–5s | — |

---

## Netcode (requisitos)

- Servidor authoritative
- Client-side prediction de movimiento y dodge
- Reconciliación
- Hits: server rewind corto o timestamp validado
- Tick 20–30 Hz mínimo jugable; ideal 30
- No confiar en “llegó el click” del client para daño

Detalle de implementación: `docs/ARQUITECTURA.md`.

---

## Vertical slice de combate (orden de build)

1. Move libre + colisión  
2. Dodge + stamina + i-frames locales  
3. Espada L-L-Finisher animation-lock  
4. Hitbox debug draw  
5. 1 skillshot magia  
6. Dummy DPS test (spam vs rhythm)  
7. 1v1 local 2 pads  
8. Portar authority al server  
