class_name FenceAutotiler
extends RefCounted
## El vallado tipo Age of Empires: se marcan celdas y cada una elige su pieza
## según qué vecinas también son valla del mismo estilo. Esquinas, cruces y
## remates salen solos; nadie elige la pieza a mano.
##
## TRES BITS, NO CUATRO. El arte es un poste con barandas que salen hacia los
## bordes de la celda, y el poste está anclado abajo con el tronco llegando al
## borde inferior. Eso quiere decir que **conectar hacia el SUR no tiene
## dibujo propio**: la celda de abajo pone su baranda norte y las dos se
## encuentran justo en la costura. Quedan N, E y O = 8 combinaciones, que es
## el atlas que hornea tools/bake_fence_tiles.py.
##
## Verificado componiendo un corral cerrado, una L y tiradas sueltas antes de
## escribir una línea de esto — no es una deducción sobre el arte, es lo que
## el arte hace.
##
## DIAGONALES NO. A diferencia de RoadAutotiler (blob de 8 bits, con
## diagonales y biseles), una valla es una línea de postes: solo conecta en
## cruz. Dos vallas que se tocan en diagonal son dos vallas, no una curva, y
## el arte no tiene pieza para eso. Es más simple a propósito.
##
## ESTILOS: un estilo es un atlas horneado en assets/world/fences/<estilo>.png
## y una línea en BuildCatalog. La lista sale del catálogo y no de escanear el
## disco, por la misma razón que PaintedFloorTileset.ids_sorted(): el catálogo
## ya es la fuente de verdad de qué ofrece la paleta, y escanear res:// no
## funciona en un build exportado (los .png dejan de llamarse .png adentro
## del pack).

const N := 1
const E := 2
const W := 4

## Prefijo del id de paleta: "fence_wood" -> estilo "wood".
const ID_PREFIX := "fence_"
const DIR := "res://assets/world/fences/"
## Cuántos tiles tiene el atlas de cada estilo, en fila. Es 2^3 por lo que
## explica el encabezado; bake_fence_tiles.py escribe exactamente esto y
## validate_fence.gd falla si alguno de los dos se mueve sin el otro.
const TILES_PER_STYLE := 8

## Qué combinación muestra el botón de la paleta y el ghost de colocación: la
## tirada horizontal, que es la que se reconoce de un vistazo como "valla".
const ICON_MASK := E | W


static func palette_id(style: String) -> String:
	return ID_PREFIX + style


static func is_fence_id(id: String) -> bool:
	return id.begins_with(ID_PREFIX)


static func style_of(id: String) -> String:
	return id.trim_prefix(ID_PREFIX)


static func atlas_path(style: String) -> String:
	return DIR + style + ".png"


## Los estilos que la paleta ofrece, en orden de catálogo.
static func styles() -> Array[String]:
	var out: Array[String] = []
	for id in BuildCatalog.ids_in_category("fence"):
		if is_fence_id(id):
			out.append(style_of(id))
	return out


## El bitmask de `cell` dado el conjunto de celdas ocupadas por valla DEL
## MISMO ESTILO. `occupied` es un Dictionary usado como set (Vector2i -> true),
## que es como lo arma world_zone en su primera pasada.
##
## Dos estilos distintos que se tocan no se conectan: cada uno remata contra
## el otro. Es deliberado — una valla de madera y una de piedra que se funden
## en una sola no es lo que nadie quiso dibujar.
static func mask_at(occupied: Dictionary, cell: Vector2i) -> int:
	var mask := 0
	if occupied.has(cell + Vector2i(0, -1)):
		mask |= N
	if occupied.has(cell + Vector2i(1, 0)):
		mask |= E
	if occupied.has(cell + Vector2i(-1, 0)):
		mask |= W
	return mask


## Dónde cae esa combinación dentro del atlas (8 tiles en una fila).
static func atlas_coords(mask: int) -> Vector2i:
	return Vector2i(clampi(mask, 0, TILES_PER_STYLE - 1), 0)


## Las celdas de una tirada recta entre dos puntos — el gesto de AoE: se
## hace click en A, se arrastra hasta B y se coloca el tramo entero.
##
## Se queda con UN eje, el del movimiento más largo, en vez de trazar una
## diagonal escalonada: arrastrar en diagonal queriendo una línea recta es lo
## que pasa el 90% de las veces, y una escalera de postes es casi nunca lo
## que se quiso. Para una L se hacen dos tiradas, que además es como se hace
## en AoE.
static func line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var delta := to_cell - from_cell
	if absi(delta.x) >= absi(delta.y):
		var step := signi(delta.x)
		if step == 0:
			out.append(from_cell)
			return out
		var x := from_cell.x
		while true:
			out.append(Vector2i(x, from_cell.y))
			if x == to_cell.x:
				break
			x += step
	else:
		var step := signi(delta.y)
		var y := from_cell.y
		while true:
			out.append(Vector2i(from_cell.x, y))
			if y == to_cell.y:
				break
			y += step
	return out
