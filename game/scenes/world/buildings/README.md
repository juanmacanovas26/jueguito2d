# Edificios como escena

Un edificio puede ser dos cosas:

- **Un PNG suelto** (`assets/world/buildings/<id>.png`). El `BuildingMarker`
  lo dibuja y listo: no tiene colisión, es decorado visual. Era lo único que
  había.
- **Una escena acá** (`<id>.tscn`). El marker la instancia y *eso* es el
  edificio: su sprite, sus colliders, y lo que se le agregue después —
  trigger de puerta, marcador del interior, oclusión.

El nombre del archivo **es** el id. `house_small_a.tscn` ↔ el
`building_house_small_a` de la paleta. Una escena para un edificio que el
catálogo todavía no declara aparece sola en la paleta y en el dock del editor
(`BuildCatalog.scanned_building_ids()`), sin tocar código.

Los dos modos conviven a propósito: armar los 45 edificios es trabajo de a
uno, y mientras tanto el catálogo entero sigue colocable.

## Armarlos

Con la herramienta: abrir `tools/collider_editor.tscn` y F6. Elegís el
edificio, dibujás los rectángulos de su planta sobre el sprite y "Guardar"
escribe la escena acá. "Sugerir planta" mide el sprite y te deja un punto de
partida (la caja opaca debajo del alero) para corregir a ojo. El ✓ en la
lista marca lo que ya tiene escena.

A mano en Godot también vale — la herramienta no es más que un atajo.

## Las tres reglas

1. **Raíz `StaticBody2D`**, con `collision_layer = 1` y `collision_mask = 0`.
   La capa 1 es lo sólido del mundo (`WorldBounds`, `CollisionMarker`); mask 0
   porque una casa no necesita detectar nada, solo ser detectada.
2. **Anclada abajo-al-centro**: el `Sprite2D` va con `offset.y = -alto/2`, así
   el origen de la escena queda al pie del edificio. Misma convención que
   árboles, props y piezas de estructura — el edificio "se para" donde se hizo
   el click.
3. **El collider es la planta, no el sprite.** El techo se dibuja hacia
   arriba y no ocupa suelo: si el collider cubriera el sprite entero, la casa
   bloquearía varios tiles de pasto por los que se tiene que poder caminar por
   detrás. `house_small_a` es el ejemplo: 126x56 de collider contra 176x224 de
   sprite.

Un edificio puede tener varios `CollisionShape2D` (una L, un porche que
sobresale). La herramienta edita rectángulos; un polígono dibujado a mano en
Godot funciona igual en el juego, solo que ella no lo sabe editar y avisa
antes de reemplazarlo.

## Por qué la instancia no se guarda en la zona

El marker agrega la instancia **sin `owner`**, y Godot solo serializa lo que
tiene owner. El `.tscn` de la zona guarda el marker (id + posición) y nada
más. Gracias a eso, arreglarle el collider a una casa arregla **todas** las ya
colocadas en el mundo; si se guardara la instancia, cada casa quedaría
congelada con la versión que había el día que se puso.

## Direccionales

Un edificio con cuatro vistas (`blacksmith_n/_e/_s/_w`) lleva una escena por
vista, con el mismo nombre que su PNG. Son cuatro plantas distintas, así que
no hay forma de compartir un collider entre ellas.
