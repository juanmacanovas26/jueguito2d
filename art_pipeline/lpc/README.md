# Pipeline de personajes — Universal LPC Spritesheet

El personaje es un **paperdoll de LPC**: se compone en runtime apilando capas
(cuerpo, cabeza, pelo, y 10 slots de equipamiento), todas dibujadas para
encajar entre sí.

> Reemplazó al pipeline anterior de PixelLab (96×96, un PNG por frame, EAST
> espejado), que fue borrado por completo.

---

## 1. Regla de oro: seguimos LPC, no inventamos formato

Los archivos se copian a `game/assets/lpc/` **en sus rutas originales de LPC,
byte a byte**. Nada se renombra, se recarpetea, se reescala ni se re-encodea.
También se copian los `sheet_definitions` de cada pieza.

Por qué: agregar arte después es "copiá la carpeta de LPC manteniendo su ruta",
y cualquier pack de LPC entra sin tocar nada. El juego lee el formato de
metadata de LPC en lugar de una traducción propia.

---

## 2. El estándar

```text
Frame:              64×64 px  (128 o 192 en armas cuyo arco se sale del cuadro)
Filas = direcciones: north, west, south, east   (en ese orden)
Direcciones:        LAS 4 CON ARTE REAL — no se espeja nada
Escala:             1:1, nunca se reescala
```

Las capas de distinto tamaño alinean solas porque **todos los frames se centran
en el mismo origen**: un arma de 192 centrada sobre un cuerpo de 64 calza sin
offsets.

### Animaciones

| Juego | LPC | Frames | Quién la usa |
|---|---|---|---|
| `idle` | `idle` | 2 | todos |
| `walk` | `walk` | 9 | todos |
| `dash` | `run` | 8 | todos |
| `death` | `hurt` | 6 | todos |
| `attack_slash` | `slash` | 6 | espadas, hachas, mazas |
| `attack_thrust` | `thrust` | 8 | lanzas, alabardas |
| `attack_cast` | `spellcast` | 7 | bastones |
| `attack_shoot` | `shoot` | 13 | armas a distancia |

**El arma decide cómo ataca el personaje.** Cada item declara su `attack_anim`
en `ItemDB`; `player.gd` lo lee y se lo pasa al visual. Un arma sólo tiene arte
para su propio tipo de ataque, así que el validador les exige el set compartido
más **al menos un** ataque, no los cuatro.

`hurt` es la única de **una sola fila** en LPC: la muerte se ve siempre desde el
sur. Es una limitación del arte original, no del código.

---

## 3. Cómo agrego más assets

1. Abrí `art_pipeline/lpc/selection.json`.
2. Sumá el **nombre** del asset a la lista del slot que corresponda. El nombre es
   el campo `name` dentro de `lpc/sheet_definitions/**.json`.
3. Corré:

   ```bash
   python art_pipeline/lpc/import_lpc.py
   ```

4. Corré la validación: `powershell -File run_tests.ps1`

### Las tres formas de ruta de LPC

Un arma organiza sus hojas de tres maneras distintas y **la carpeta te dice
cuál**: un golpe cuerpo a cuerpo vive en su propia carpeta `attack_*`, un arco
guarda su walk en una carpeta `walk/`, y el resto anida la animación dentro de
una capa universal. El importador detecta si algún **segmento de la ruta** nombra
una animación; si lo hace, esa capa le pertenece y el archivo es sólo la
variante.

El importador **no adivina nada**: mide cada hoja y falla ruidosamente si algo no
cierra. Los problemas que reporta son reales y valen la pena leerlos:

- *"no definition with a 'male' layer"* → ese asset no existe para este cuerpo
  (Tunic y Robe, por ejemplo, son female-only en LPC).
- *"N frames for 'attack' but the body has M"* → el asset no es compatible con esa
  animación. Le pasa a las armas mágicas: su ataque tiene 13 frames porque están
  hechas para `spellcast`/`shoot`, no para `slash`.
- *"13 frames for 'walk' but the body has 9"* → le pasa a **todos los arcos de
  LPC**: traen un walk de 128 px y 13 frames, dibujado para otro rig. Por eso el
  arma a distancia del MVP es el slingshot, que sí calza.
- *"resolved no sheets"* → la variante elegida no existe para ese asset. Cada arma
  trae su propia lista de `variants` (la espada arming tiene metales, la longsword
  tiene una sola llamada `longsword`).

### Fallbacks declarados

Ningún arma de LPC tiene animación `run`, y casi ninguna tiene `idle` propio. Sin
resolverlo, la espada desaparecería en pleno dash. `selection.json` declara:

```json
"fallbacks": { "idle": "walk", "dash": "walk" }
```

Cuando una **capa** no tiene arte para una animación, toma prestada la que se
indique. Cada uso queda anotado en `index.json` con `borrowed_from` — nunca es
silencioso.

---

## 3.bis Slots de equipamiento

El personaje compone **10 slots**, cada uno con su categoría de LPC:

| Slot del juego | Categoría LPC (`type_name`) | Piezas incluidas |
|---|---|---|
| `armor` | `armour` / `clothes` / `chainmail` | 5 |
| `legs` | `legs` | 5 |
| `feet` | `shoes` | 5 |
| `arms` | `arms` | 1 |
| `wrists` | `wrists` / `bracers` | 3 |
| `gloves` | `gloves` | 1 |
| `shoulders` | `shoulders` | 4 |
| `helmet` | `hat` | 5 |
| `weapon` | `weapon` | 10 |
| `secondary` | `shield` / `quiver` | 6 |

**Un nombre de asset sólo es único DENTRO de su categoría.** LPC tiene un
"Armour" de torso, otro de piernas, otro de brazos y otro de botas. El
importador desambigua con `SLOT_TYPES`; si no lo hiciera, las grebas terminan
apuntando a la hoja del peto (pasó, y por eso existe ese mapeo).

`secondary` es el ejemplo de que **un slot del juego puede mapear a más de una
categoría de LPC** (como ya hacía `armor` con clothes/armour/chainmail): un
escudo y un carcaj de flechas compiten por la misma mano libre, así que ambos
comparten el slot y el prefijo de pieza `shield/` en `index.json`, aunque uno
sea `type_name: shield` y el otro `type_name: quiver`.

Agregar un slot nuevo: sumarlo a `SLOT_TYPES` en el importador, a `SLOTS` en
`CharacterVisual`, a `EQUIPPABLE_TYPES` en `DataIntegrity`, a `_SLOT_FIELDS` en
`player.gd`, y un botón con ese nombre en la grilla del HUD. El botón se cablea
solo por su nombre.

## 3.ter El pelo bajo el casco

`CharacterVisual` **saltea la capa de pelo mientras haya un casco puesto**. El
pelo de LPC está dibujado para una cabeza pelada, así que debajo de un yelmo
atraviesa el metal. Hay test de regresión.

## 4. Receta: agregar un item de cero

Ejemplo real — la Glowsword, agregada así:

**1.** El nombre a `art_pipeline/lpc/selection.json`, en el slot que va:

```json
"weapon": [..., "Glowsword"]
```

**2.** Correr el importador:

```bash
python art_pipeline/lpc/import_lpc.py
```

**3.** El item en `ItemDB.ITEMS` (`game/scripts/data/item_db.gd`):

```gdscript
"glowsword": {
    "name": "Glowsword",
    "color": Color(0.55, 0.85, 1.0),
    "stack": 1,                    # equipo: siempre 1
    "rarity": "legendary",
    "type": "weapon",              # el slot
    "value": 400,
    "dmg_bonus": 22.0,
    "visual_state": "glowsword",   # la clave que enlaza con el arte
},
```

**4.** El mapeo en `LpcEquipment.PIECES`:

```gdscript
"glowsword": "weapon/Glowsword",
```

**5.** Validar: `powershell -File run_tests.ps1`

Y listo. Aparece en el inventario al arrancar (el loadout de debug recorre
`ItemDB`), con su icono sacado del arte real, su color de rareza, su tooltip y
su tirada de stats. **No se toca ni el Player, ni el HUD, ni el visual.**

Si la pieza **ya estaba incluida** (por ejemplo otra variante de una que ya
tenés), saltá los pasos 1 y 2: son sólo las dos ediciones de datos.

### Qué puede salir mal

- El importador dice *"no definition with a 'male' layer"* → el asset no existe
  para este cuerpo.
- Dice *"N frames for 'attack' but the body has M"* → el asset no sirve para esa
  animación.
- El test *"every equippable item has LPC art"* falla → te olvidaste el paso 4.
- El test *"slot 'X' has 0 pieces"* falla → te olvidaste el paso 2.

## 5. Cómo le doy apariencia a un item

Una línea en `LpcEquipment.PIECES` (`game/scripts/visual/lpc_equipment.gd`):

```gdscript
"iron_helmet": "hat/Barbuta",
```

La clave izquierda es el `visual_state` del item en `ItemDB`; la derecha es una
pieza de `game/assets/lpc/index.json`. Si la pieza todavía no está incluida,
sumala primero a `selection.json`.

**Un item sin mapeo se equipa igual y no dibuja nada.** Es a propósito: el
equipamiento nunca queda bloqueado esperando arte, y una pieza equivocada es peor
que ninguna.

---

## 6. Arquitectura

| Archivo | Qué hace |
|---|---|
| `art_pipeline/lpc/selection.json` | Qué se incluye. **El único archivo que se edita para agregar arte.** |
| `art_pipeline/lpc/import_lpc.py` | Copia, mide y genera el índice. Re-ejecutable. |
| `game/assets/lpc/index.json` | Índice generado: piezas, capas, `zPos`, geometría medida. |
| `game/scripts/visual/lpc_library.gd` | Lee el índice y devuelve `AtlasTexture` por frame. Único lugar que conoce la convención de filas de LPC. |
| `game/scripts/visual/character_visual.gd` | Compone el paperdoll. Un solo reloj, capas ordenadas por `zPos`. |
| `game/scripts/visual/lpc_equipment.gd` | `visual_state` → pieza LPC. |
| `game/scripts/core/character_facing.gd` | Autoridad única de orientación, compartida por gameplay y visual. |

### Las capas son dinámicas

No hay un stack fijo de body/armor/weapon. Cada pieza declara su propio `zPos` y
**una pieza puede aportar varias capas a distintas profundidades** — una espada
se dibuja en parte detrás del cuerpo y en parte delante. El stack se rearma por
animación y se ordena por `zPos`; los `Sprite2D` son sólo un pool. Nada
hardcodea un orden de dibujo.

### Un solo reloj

Existe una única terna `(animación, dirección, frame)` y todas las capas se
escriben en la misma pasada, así un casco nunca puede quedar un frame atrás de la
cabeza que lleva puesta.

### El frame nunca manda sobre el gameplay

Daño, ventanas de hitbox e i-frames son por tiempo en `player.gd` y no saben nada
del visual (ver `docs/ARQUITECTURA.md`). El timing va de gameplay → visual con el
parámetro `duration` de `play()`, nunca al revés.

---

## 7. Validación

```bash
powershell -File run_tests.ps1
```

La suite `visuals` verifica, entre otras cosas, que el índice cargue, que **cada
capa de cada pieza resuelva una textura real**, que los frame counts del recurso
coincidan con el arte en disco, que las 4 direcciones lean **filas distintas**
(o sea que no haya espejado encubierto), que la colisión siga siendo 18×26 y no
dependa del frame, y que equipar algo repinte al instante incluso en un `idle` de
2 frames.
