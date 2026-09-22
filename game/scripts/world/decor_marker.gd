@tool
class_name DecorMarker
extends Marker2D
## Author-time placement for one loose decoration prop — barrels, crates, a
## cart, a fence, a garden bed, etc., cropped from "Medieval Village
## Exterior" by Hypnobius (see assets/world/decor/LICENSE.txt), the same
## pack StructureTileset's wall/door/floor/roof tiles come from. Free-placed
## like a POI (not grid-snapped like "wall"), one prop per click — the
## "decoración" category the build-mode mapping tool was always missing
## alongside walls/doors/houses (see docs/GDD.md).
##
## Windows and the wall-mounted torch used to live here too, but they're
## wall-mounted BY NATURE — free-placing one in open air never made sense.
## They moved to StructureTileset.WALL_DECOR instead: painted onto an
## existing wall cell (world_zone.gd's _paint_wall_decor()), the same
## generalized mechanic the door now uses. This class stays for props that
## really are freestanding (nothing here is anchored to a wall cell).
##
## Anchored bottom-center, same convention as every other world sprite
## (resource_node.gd's trees/rocks, StructureTileset's pieces) — the prop
## "stands" on the spot it was clicked.
##
## Draws itself both in the editor AND at runtime, same reason as POIMarker.

const PATHS := {
	"barrel": "res://assets/world/decor/barrel.png",
	"crate": "res://assets/world/decor/crate.png",
	"crate_stack": "res://assets/world/decor/crate_stack.png",
	"banner": "res://assets/world/decor/banner.png",
	"cart": "res://assets/world/decor/cart.png",
	"cart_wheel": "res://assets/world/decor/cart_wheel.png",
	"bush": "res://assets/world/decor/bush.png",
	"spigot": "res://assets/world/decor/spigot.png",
	"fence": "res://assets/world/decor/fence.png",
	"garden_bed": "res://assets/world/decor/garden_bed.png",
	"plank": "res://assets/world/decor/plank.png",
	"door_wood": "res://assets/world/decor/door_wood.png",
	# Roof dormers. Free-placed rather than a wall_decor kind on purpose:
	# they belong on a ROOF, and the wall_decor mechanism only paints onto
	# wall cells. Dropped by hand onto a finished roof.
	"dormer_red": "res://assets/world/decor/dormer_red.png",
	"dormer_blue": "res://assets/world/decor/dormer_blue.png",
	# The pack's third "ground texture" is really a fixed 2x3 paved platform
	# with curbs baked into its outer ring — verified it has no repeating
	# vertical period at all, so it can't work as a paintable ground fill
	# the way grass/cobblestone do. Placed whole, as a plaza/base piece.
	"stone_platform": "res://assets/world/decor/stone_platform.png",
	"chimney_red": "res://assets/world/decor/chimney_red.png",
	"chimney_blue": "res://assets/world/decor/chimney_blue.png",
	"roof_gable_red": "res://assets/world/decor/roof_gable_red.png",
	"roof_gable_blue": "res://assets/world/decor/roof_gable_blue.png",
	# "RPG Pixel Realms - The Plains" by pixel-banner (itch.io), sliced out
	# of the pack's Props.png — see assets/world/decor/plains/SOURCE.txt.
	# Prefixed "plains_" because several names (barrel/crate/bush/plank)
	# already exist above in the Hypnobius set and are different art.
	"plains_tree_oak": "res://assets/world/decor/plains/tree_oak.png",
	"plains_tree_round": "res://assets/world/decor/plains/tree_round.png",
	"plains_tree_pine": "res://assets/world/decor/plains/tree_pine.png",
	"plains_stump": "res://assets/world/decor/plains/stump.png",
	"plains_stump_axe": "res://assets/world/decor/plains/stump_axe.png",
	"plains_log_fallen": "res://assets/world/decor/plains/log_fallen.png",
	"plains_log_post": "res://assets/world/decor/plains/log_post.png",
	"plains_plank": "res://assets/world/decor/plains/plank.png",
	"plains_bush": "res://assets/world/decor/plains/bush.png",
	"plains_bush_berry": "res://assets/world/decor/plains/bush_berry.png",
	"plains_bush_fern": "res://assets/world/decor/plains/bush_fern.png",
	"plains_grass_tall": "res://assets/world/decor/plains/grass_tall.png",
	"plains_grass_tuft": "res://assets/world/decor/plains/grass_tuft.png",
	"plains_grass_tuft_b": "res://assets/world/decor/plains/grass_tuft_b.png",
	"plains_wheat": "res://assets/world/decor/plains/wheat.png",
	"plains_rock": "res://assets/world/decor/plains/rock.png",
	"plains_rock_mossy": "res://assets/world/decor/plains/rock_mossy.png",
	"plains_mushrooms_red": "res://assets/world/decor/plains/mushrooms_red.png",
	"plains_mushrooms_yellow": "res://assets/world/decor/plains/mushrooms_yellow.png",
	"plains_mushrooms_brown": "res://assets/world/decor/plains/mushrooms_brown.png",
	"plains_lilypad": "res://assets/world/decor/plains/lilypad.png",
	"plains_barrel": "res://assets/world/decor/plains/barrel.png",
	"plains_barrel_water": "res://assets/world/decor/plains/barrel_water.png",
	"plains_crate": "res://assets/world/decor/plains/crate.png",
	"plains_sack": "res://assets/world/decor/plains/sack.png",
	"plains_sack_grain": "res://assets/world/decor/plains/sack_grain.png",
	"plains_sack_open": "res://assets/world/decor/plains/sack_open.png",
	"plains_hay_bale": "res://assets/world/decor/plains/hay_bale.png",
	"plains_cauldron": "res://assets/world/decor/plains/cauldron.png",
	"plains_beehive": "res://assets/world/decor/plains/beehive.png",
	"plains_well": "res://assets/world/decor/plains/well.png",
	"plains_campfire": "res://assets/world/decor/plains/campfire.png",
	"plains_sign_wood": "res://assets/world/decor/plains/sign_wood.png",
	"plains_sign_skull": "res://assets/world/decor/plains/sign_skull.png",
	"plains_stall_apples": "res://assets/world/decor/plains/stall_apples.png",
	"plains_bench": "res://assets/world/decor/plains/bench.png",
	"plains_tent": "res://assets/world/decor/plains/tent.png",
	"plains_wagon": "res://assets/world/decor/plains/wagon.png",
	# "Medieval Town & Fantasy 2D Mega Props Pack" by nacl1234 — painted
	# illustration, not pixel art, and shipped at ~4.7x this project's
	# scale; cropped to content and downscaled 1/4 on import (see
	# assets/world/decor/megapack/SOURCE.txt).
	"mega_beehive_skep_straw": "res://assets/world/decor/megapack/beehive_skep_straw.png",
	"mega_chicken_coop_wooden": "res://assets/world/decor/megapack/chicken_coop_wooden.png",
	"mega_clothesline_posts": "res://assets/world/decor/megapack/clothesline_posts.png",
	"mega_dovecote_post_mounted": "res://assets/world/decor/megapack/dovecote_post_mounted.png",
	"mega_fence_wattle_segment": "res://assets/world/decor/megapack/fence_wattle_segment.png",
	"mega_firewood_pile_stacked": "res://assets/world/decor/megapack/firewood_pile_stacked.png",
	"mega_garden_plot_vegetables": "res://assets/world/decor/megapack/garden_plot_vegetables.png",
	"mega_grindstone_wheel_pedal": "res://assets/world/decor/megapack/grindstone_wheel_pedal.png",
	"mega_handcart_single_axle": "res://assets/world/decor/megapack/handcart_single_axle.png",
	"mega_hay_bale_round": "res://assets/world/decor/megapack/hay_bale_round.png",
	"mega_hay_cart_two_wheel": "res://assets/world/decor/megapack/hay_cart_two_wheel.png",
	"mega_outdoor_oven_clay": "res://assets/world/decor/megapack/outdoor_oven_clay.png",
	"mega_rain_barrel_wooden": "res://assets/world/decor/megapack/rain_barrel_wooden.png",
	"mega_shrine_roadside_stone": "res://assets/world/decor/megapack/shrine_roadside_stone.png",
	"mega_signpost_wooden_blank": "res://assets/world/decor/megapack/signpost_wooden_blank.png",
	"mega_water_well_roof": "res://assets/world/decor/megapack/water_well_roof.png",
	"mega_barrel_water_open": "res://assets/world/decor/megapack/barrel_water_open.png",
	"mega_basket_woven_apples": "res://assets/world/decor/megapack/basket_woven_apples.png",
	"mega_basket_woven_empty": "res://assets/world/decor/megapack/basket_woven_empty.png",
	"mega_bench_rough_plank": "res://assets/world/decor/megapack/bench_rough_plank.png",
	"mega_broom_twig_standing": "res://assets/world/decor/megapack/broom_twig_standing.png",
	"mega_chicken_feed_trough": "res://assets/world/decor/megapack/chicken_feed_trough.png",
	"mega_chopping_block_axe": "res://assets/world/decor/megapack/chopping_block_axe.png",
	"mega_clay_pot_group": "res://assets/world/decor/megapack/clay_pot_group.png",
	"mega_hay_pile_loose": "res://assets/world/decor/megapack/hay_pile_loose.png",
	"mega_log_pile_short": "res://assets/world/decor/megapack/log_pile_short.png",
	"mega_milk_churn_lidded": "res://assets/world/decor/megapack/milk_churn_lidded.png",
	"mega_pitchfork_leaning_stand": "res://assets/world/decor/megapack/pitchfork_leaning_stand.png",
	"mega_sack_grain_tied": "res://assets/world/decor/megapack/sack_grain_tied.png",
	"mega_sack_pile_leaning": "res://assets/world/decor/megapack/sack_pile_leaning.png",
	"mega_scarecrow_cross_frame": "res://assets/world/decor/megapack/scarecrow_cross_frame.png",
	"mega_stone_pile_field": "res://assets/world/decor/megapack/stone_pile_field.png",
	"mega_wash_tub_board": "res://assets/world/decor/megapack/wash_tub_board.png",
	"mega_wheelbarrow_wooden": "res://assets/world/decor/megapack/wheelbarrow_wooden.png",
	"mega_wooden_bucket_rope": "res://assets/world/decor/megapack/wooden_bucket_rope.png",
	"mega_wooden_stool_three_leg": "res://assets/world/decor/megapack/wooden_stool_three_leg.png",
	"mega_door_double_barn": "res://assets/world/decor/megapack/door_double_barn.png",
	"mega_door_wooden_iron_hinges": "res://assets/world/decor/megapack/door_wooden_iron_hinges.png",
	"mega_fence_picket_segment": "res://assets/world/decor/megapack/fence_picket_segment.png",
	"mega_floor_cobblestone_road": "res://assets/world/decor/megapack/floor_cobblestone_road.png",
	"mega_floor_dirt_path": "res://assets/world/decor/megapack/floor_dirt_path.png",
	"mega_floor_stone_slab_interior": "res://assets/world/decor/megapack/floor_stone_slab_interior.png",
	"mega_floor_wood_plank_interior": "res://assets/world/decor/megapack/floor_wood_plank_interior.png",
	"mega_gate_town_arch_wooden": "res://assets/world/decor/megapack/gate_town_arch_wooden.png",
	"mega_roof_thatch_edge_strip": "res://assets/world/decor/megapack/roof_thatch_edge_strip.png",
	"mega_wall_brick_medieval": "res://assets/world/decor/megapack/wall_brick_medieval.png",
	"mega_wall_ivy_overgrown": "res://assets/world/decor/megapack/wall_ivy_overgrown.png",
	"mega_wall_log_horizontal": "res://assets/world/decor/megapack/wall_log_horizontal.png",
	"mega_wall_low_stone_field": "res://assets/world/decor/megapack/wall_low_stone_field.png",
	"mega_wall_stone_rough": "res://assets/world/decor/megapack/wall_stone_rough.png",
	"mega_wall_timber_frame_plaster": "res://assets/world/decor/megapack/wall_timber_frame_plaster.png",
	"mega_window_shuttered_wall": "res://assets/world/decor/megapack/window_shuttered_wall.png",
	"mega_amphora_group_leaning": "res://assets/world/decor/megapack/amphora_group_leaning.png",
	"mega_banner_pole_pennant": "res://assets/world/decor/megapack/banner_pole_pennant.png",
	"mega_barrel_pickles_open": "res://assets/world/decor/megapack/barrel_pickles_open.png",
	"mega_cage_chickens_wooden": "res://assets/world/decor/megapack/cage_chickens_wooden.png",
	"mega_cheese_wheel_stack": "res://assets/world/decor/megapack/cheese_wheel_stack.png",
	"mega_coin_chest_small_open": "res://assets/world/decor/megapack/coin_chest_small_open.png",
	"mega_counter_butcher_hanging": "res://assets/world/decor/megapack/counter_butcher_hanging.png",
	"mega_crate_produce_stack": "res://assets/world/decor/megapack/crate_produce_stack.png",
	"mega_hanging_scale_brass": "res://assets/world/decor/megapack/hanging_scale_brass.png",
	"mega_notice_board_standing": "res://assets/world/decor/megapack/notice_board_standing.png",
	"mega_rug_market_woven": "res://assets/world/decor/megapack/rug_market_woven.png",
	"mega_spice_sacks_open_row": "res://assets/world/decor/megapack/spice_sacks_open_row.png",
	"mega_stall_bread_baskets": "res://assets/world/decor/megapack/stall_bread_baskets.png",
	"mega_stall_canopy_fabric_rolls": "res://assets/world/decor/megapack/stall_canopy_fabric_rolls.png",
	"mega_stall_canopy_pottery": "res://assets/world/decor/megapack/stall_canopy_pottery.png",
	"mega_stall_canopy_vegetables": "res://assets/world/decor/megapack/stall_canopy_vegetables.png",
	"mega_stall_fish_table_ice": "res://assets/world/decor/megapack/stall_fish_table_ice.png",
	"mega_table_goods_cloth": "res://assets/world/decor/megapack/table_goods_cloth.png",
	"mega_torch_post_market": "res://assets/world/decor/megapack/torch_post_market.png",
	"mega_weighing_table_balance": "res://assets/world/decor/megapack/weighing_table_balance.png",
	"mega_bar_counter_corner": "res://assets/world/decor/megapack/bar_counter_corner.png",
	"mega_bar_counter_straight": "res://assets/world/decor/megapack/bar_counter_straight.png",
	"mega_bard_stool_lute": "res://assets/world/decor/megapack/bard_stool_lute.png",
	"mega_barrel_ale_tapped": "res://assets/world/decor/megapack/barrel_ale_tapped.png",
	"mega_bench_long_matching": "res://assets/world/decor/megapack/bench_long_matching.png",
	"mega_candelabra_standing": "res://assets/world/decor/megapack/candelabra_standing.png",
	"mega_chair_ladder_back": "res://assets/world/decor/megapack/chair_ladder_back.png",
	"mega_chandelier_wheel_candles": "res://assets/world/decor/megapack/chandelier_wheel_candles.png",
	"mega_fireplace_stone_hearth": "res://assets/world/decor/megapack/fireplace_stone_hearth.png",
	"mega_food_platter_bread_cheese": "res://assets/world/decor/megapack/food_platter_bread_cheese.png",
	"mega_innkeeper_ledger_stand": "res://assets/world/decor/megapack/innkeeper_ledger_stand.png",
	"mega_keg_rack_triple": "res://assets/world/decor/megapack/keg_rack_triple.png",
	"mega_long_table_plank": "res://assets/world/decor/megapack/long_table_plank.png",
	"mega_mug_group_wooden": "res://assets/world/decor/megapack/mug_group_wooden.png",
	"mega_round_table_small": "res://assets/world/decor/megapack/round_table_small.png",
	"mega_rug_tavern_worn": "res://assets/world/decor/megapack/rug_tavern_worn.png",
	"mega_serving_tray_mugs": "res://assets/world/decor/megapack/serving_tray_mugs.png",
	"mega_stew_pot_hanging": "res://assets/world/decor/megapack/stew_pot_hanging.png",
	"mega_trophy_stag_head_plaque": "res://assets/world/decor/megapack/trophy_stag_head_plaque.png",
	"mega_wine_shelf_bottles": "res://assets/world/decor/megapack/wine_shelf_bottles.png",
	"mega_anvil_horn_block": "res://assets/world/decor/megapack/anvil_horn_block.png",
	"mega_armor_stand_breastplate": "res://assets/world/decor/megapack/armor_stand_breastplate.png",
	"mega_bellows_large_lever": "res://assets/world/decor/megapack/bellows_large_lever.png",
	"mega_cart_wheel_repair_leaning": "res://assets/world/decor/megapack/cart_wheel_repair_leaning.png",
	"mega_chain_bundle_hook": "res://assets/world/decor/megapack/chain_bundle_hook.png",
	"mega_coal_pile_shovel": "res://assets/world/decor/megapack/coal_pile_shovel.png",
	"mega_forge_stone_coal_glow": "res://assets/world/decor/megapack/forge_stone_coal_glow.png",
	"mega_grinding_wheel_water": "res://assets/world/decor/megapack/grinding_wheel_water.png",
	"mega_hammer_set_bench": "res://assets/world/decor/megapack/hammer_set_bench.png",
	"mega_helmet_row_shelf": "res://assets/world/decor/megapack/helmet_row_shelf.png",
	"mega_horseshoe_crate_full": "res://assets/world/decor/megapack/horseshoe_crate_full.png",
	"mega_ingot_stack_iron": "res://assets/world/decor/megapack/ingot_stack_iron.png",
	"mega_quench_barrel_steam": "res://assets/world/decor/megapack/quench_barrel_steam.png",
	"mega_scrap_metal_bin": "res://assets/world/decor/megapack/scrap_metal_bin.png",
	"mega_shield_stack_leaning": "res://assets/world/decor/megapack/shield_stack_leaning.png",
	"mega_sword_finished_table": "res://assets/world/decor/megapack/sword_finished_table.png",
	"mega_tool_wall_board_tongs": "res://assets/world/decor/megapack/tool_wall_board_tongs.png",
	"mega_weapon_rack_polearms": "res://assets/world/decor/megapack/weapon_rack_polearms.png",
	"mega_weapon_rack_swords": "res://assets/world/decor/megapack/weapon_rack_swords.png",
	"mega_workbench_smith_vise": "res://assets/world/decor/megapack/workbench_smith_vise.png",
	"mega_boulder_moss_large": "res://assets/world/decor/megapack/boulder_moss_large.png",
	"mega_bridge_wooden_arch": "res://assets/world/decor/megapack/bridge_wooden_arch.png",
	"mega_bush_berry_red": "res://assets/world/decor/megapack/bush_berry_red.png",
	"mega_bush_round_green": "res://assets/world/decor/megapack/bush_round_green.png",
	"mega_fallen_log_moss": "res://assets/world/decor/megapack/fallen_log_moss.png",
	"mega_flower_patch_wild": "res://assets/world/decor/megapack/flower_patch_wild.png",
	"mega_grass_tuft_tall": "res://assets/world/decor/megapack/grass_tuft_tall.png",
	"mega_ivy_patch_ground": "res://assets/world/decor/megapack/ivy_patch_ground.png",
	"mega_lantern_post_iron": "res://assets/world/decor/megapack/lantern_post_iron.png",
	"mega_mushroom_ring_brown": "res://assets/world/decor/megapack/mushroom_ring_brown.png",
	"mega_oak_tree_round_crown": "res://assets/world/decor/megapack/oak_tree_round_crown.png",
	"mega_pine_tree_tall": "res://assets/world/decor/megapack/pine_tree_tall.png",
	"mega_pond_small_lily": "res://assets/world/decor/megapack/pond_small_lily.png",
	"mega_rock_group_small": "res://assets/world/decor/megapack/rock_group_small.png",
	"mega_stream_stepping_stones": "res://assets/world/decor/megapack/stream_stepping_stones.png",
	"mega_tree_stump_axe_rings": "res://assets/world/decor/megapack/tree_stump_axe_rings.png",
	"mega_banner_hanging_blank": "res://assets/world/decor/megapack/banner_hanging_blank.png",
	"mega_barrel_gunpowder_marked": "res://assets/world/decor/megapack/barrel_gunpowder_marked.png",
	"mega_brazier_iron_standing": "res://assets/world/decor/megapack/brazier_iron_standing.png",
	"mega_cage_iron_hanging": "res://assets/world/decor/megapack/cage_iron_hanging.png",
	"mega_campfire_ring_pot": "res://assets/world/decor/megapack/campfire_ring_pot.png",
	"mega_cart_covered_wagon": "res://assets/world/decor/megapack/cart_covered_wagon.png",
	"mega_crate_weapons_open": "res://assets/world/decor/megapack/crate_weapons_open.png",
	"mega_gallows_post_rope": "res://assets/world/decor/megapack/gallows_post_rope.png",
	"mega_pillory_stocks_wooden": "res://assets/world/decor/megapack/pillory_stocks_wooden.png",
	"mega_potion_shelf_bottles": "res://assets/world/decor/megapack/potion_shelf_bottles.png",
	"mega_quest_board_parchment_blank": "res://assets/world/decor/megapack/quest_board_parchment_blank.png",
	"mega_scroll_pile_desk": "res://assets/world/decor/megapack/scroll_pile_desk.png",
	"mega_tent_canvas_small": "res://assets/world/decor/megapack/tent_canvas_small.png",
	"mega_torch_wall_bracket": "res://assets/world/decor/megapack/torch_wall_bracket.png",
	"mega_treasure_chest_closed": "res://assets/world/decor/megapack/treasure_chest_closed.png",
	"mega_treasure_chest_open_gold": "res://assets/world/decor/megapack/treasure_chest_open_gold.png",
	# Composed terrain pieces from the same pack's GrassTiles.png —
	# dropped whole like "stone_platform" above, not autotiled (this
	# project has no terrain painter; see plains/SOURCE.txt).
	"plains_ground_flowers": "res://assets/world/decor/plains/ground_flowers.png",
	"plains_ground_dirt": "res://assets/world/decor/plains/ground_dirt.png",
	"plains_pond": "res://assets/world/decor/plains/pond.png",
	"plains_water": "res://assets/world/decor/plains/water.png",
	"plains_bridge_v": "res://assets/world/decor/plains/bridge_v.png",
	"plains_bridge_h": "res://assets/world/decor/plains/bridge_h.png",
	"plains_plateau_dirt": "res://assets/world/decor/plains/plateau_dirt.png",
	"plains_plateau_stone": "res://assets/world/decor/plains/plateau_stone.png",
	"plains_shore": "res://assets/world/decor/plains/shore.png",
}

## Palette id is "decor_<kind>" (see world_zone.gd's _instantiate_marker());
## this is just "<kind>" — the key into PATHS (which BuildIcons reads
## through texture_path() for the palette icon, rather than keeping its own
## copy of the same table).
@export var decor_id: String = "barrel":
	set(value):
		decor_id = value
		_load_texture()
		queue_redraw()

var _tex: Texture2D


func _ready() -> void:
	# Decor draws over the painted floor AND over prefab buildings: a barrel
	# against a wall, a bush overlapping a house's base, a lamp on a road.
	# Without this it landed wherever tree order put it — a prop placed
	# before the house it leans on vanished behind it (see world_zone.gd's
	# Z_* block for the whole stack).
	z_index = WorldZone.Z_DECOR
	_load_texture()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	draw_texture(_tex, Vector2(-_tex.get_width() / 2.0, -_tex.get_height()))


func _load_texture() -> void:
	var path := str(PATHS.get(decor_id, ""))
	_tex = load(path) if path != "" and ResourceLoader.exists(path) else null


## Art path for a decor id, or "" when there's none — BuildIcons reads the
## palette icon through this instead of keeping its own duplicate of PATHS
## (same shape BuildingMarker.texture_path() already provides).
static func texture_path(id: String) -> String:
	return str(PATHS.get(id, ""))
