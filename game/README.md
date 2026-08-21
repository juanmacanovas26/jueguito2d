# Jueguito2D — Combat Slice

## Controles

| Input | Acción |
|-------|--------|
| **Q / E / F** | Warrior / Mage / Archer |
| WASD | Mover |
| Shift | Sprint |
| Space | Dodge |
| LMB tap / hold | Basic / Charged |
| RMB | Guard |
| 1 / 2 / 3 | Shield / Parry / Energy |
| **I** | Inventario |
| R | Reset HP dummies |
| F1 | Debug hitboxes |

## Loop actual

Matar mobs verdes → **+XP** + **loot en el piso** (auto-pickup cerca) → **I** para ver inventario / gold.

Mobs **rojos** = atacantes a distancia (te tiran proyectiles).

Level up: +HP máx, curación parcial.

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
