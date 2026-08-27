# Jueguito2D — Combat Slice

## Arranque

El juego abre en un menú principal (`main_menu.tscn`): **Nuevo Juego**, **Continuar** (si hay partida guardada) y **Salir**. `pradera.tscn` ya no es la escena de arranque directa — se entra a través del menú.

## Controles

| Input | Acción |
|-------|--------|
| **Q / E / F** | Warrior / Mage / Archer (resetea skills/abilities, ver abajo) |
| WASD | Mover |
| Shift | Sprint |
| Space | Dodge |
| LMB tap / hold | Basic / Charged |
| RMB | Guard |
| 1 / 2 / 3 | Shield / Parry / Energy |
| **I** | Inventario |
| **C** | Crafteo |
| **ESC** | Pausa (Reanudar / Guardar / Guardar y salir al menú / Salir) |
| R | Reset HP dummies |
| F1 | Debug hitboxes |

## Guardado

Manual, desde el menú de pausa (ESC → Guardar). Persiste posición, zona, kit, skills, HP/maná/stamina, inventario, oro y equipo — ver `SaveSystem` (`scripts/core/save_system.gd`) y `Player.get_save_data()/apply_save_data()`.

## Loop actual

Matar mobs verdes → **skill del kit sube** (Espadas Pesadas / Hechicería / Puntería) + **loot en el piso** (auto-pickup cerca) → **I** para ver inventario / gold.

Mobs **rojos** = atacantes a distancia (te tiran proyectiles).

No hay nivel de personaje: el poder es la suma de tus skills (`Skills`, `scripts/player/skills.gd`). Cada skill sube al usarla (matar, recolectar, craftear), con rendimientos decrecientes cerca de su cap (100) y un cap total compartido entre todas (700). Toda ganancia también suma un poco a Vitalidad, que es de donde sale el HP máximo.

Las skills casteables (1-4) tampoco están fijas por kit: son las que tu personaje conoce (`known_abilities`), sembradas con el default del kit al spawnear. Q/E/F sigue siendo un toggle libre de testing, no la elección final de personaje: cambiar de kit en vivo resetea skills y abilities a los defaults del kit nuevo, para probar cada uno desde cero. Cargar una partida guardada no dispara ese reset.

Cada 25/50/75 puntos en una skill de combate (Espadas Pesadas/Hechicería/Puntería) aparece un panel de **descubrimiento: elegí 1 de 3** abilities nuevas (o descartá sin costo). Es la única forma de aprender algo fuera de tu kit por ahora.

## Gathering

- **Árboles** (madera) y **rocas** (piedra): golpealos, se agotan y respawnean ~6s.
- **Venas de hierro** (doradas): **inmortales**, dan 1 mineral por hit.
  - **G** = auto-farm (parado cerca, recolecta solo).
  - Golpear **manual** da **+20%** (chance de 2 minerales por golpe).

## Crafting

Abrí el panel con **C** y clickeá una receta (consume materiales del inventario).

Recetas: Iron Sword, Oak Staff, Health Potion, Mana Potion, Rusty Blade.

## Equip / consumibles

En el inventario (**I**) hacé **click** a un item:
- **Arma** → equipar (sube daño melee o spells)
- **Consumible** → usar (health herb cura, mana potion restaura maná)

Drops de armas: Rusty Blade, Iron Sword, Oak Staff.


## Mapas

- `pradera.tscn` (main): zona con obstáculos, walls y mobs con respawn.
- `test_arena.tscn`: arena de pruebas de combate/defensa.
