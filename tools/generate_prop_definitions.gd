@tool
extends EditorScript
## Builds one PropDefinition (.tres) per object PNG listed in PROPS.
## Run: open this file in the Script editor, then File > Run (Ctrl+Shift+X).
## Existing definitions are NOT overwritten, so manual tweaks in the Inspector survive.
## To regenerate one, delete its .tres first.
##
## The footprint comes from the sprite itself: as wide as its visible pixels and as tall as
## solid_rows tiles counted from the bottom of the visible pixels.
## To add an object: copy its PNG into assets/sprites/environment/, add a line below, run.

const TEXTURES_DIR: String = "res://assets/sprites/environment/"
const OUTPUT_DIR: String = "res://data/props/"
const DEFAULT_SOLID_ROWS: int = 1

## name: output file name. texture: PNG path inside TEXTURES_DIR.
## solid_rows: rows of 16 px (counted from the bottom) that block movement.
## First guess for the home; check it with Debug > Visible Collision Shapes and edit the .tres.
const PROPS: Array[Dictionary] = [
	{ name = "bed", texture = "home/decoration/obj_cama.png", solid_rows = 3 },
	{ name = "wardrobe", texture = "home/decoration/obj_armario.png", solid_rows = 1 },
	{ name = "desk", texture = "home/decoration/obj_escritorio.png", solid_rows = 2 },
	{ name = "chair", texture = "home/decoration/obj_silla.png", solid_rows = 1 },
	{ name = "sofa", texture = "home/decoration/obj_sofa.png", solid_rows = 2 },
	{ name = "tv", texture = "home/decoration/obj_tv.png", solid_rows = 1 },
	{ name = "stove", texture = "home/decoration/obj_cocina.png", solid_rows = 1 },
	{ name = "fridge", texture = "home/decoration/obj_nevera.png", solid_rows = 1 },
	{ name = "dining_table", texture = "home/decoration/obj_mesa_comedor.png", solid_rows = 2 },
	{ name = "toilet", texture = "home/decoration/obj_inodoro.png", solid_rows = 1 },
	{ name = "sink", texture = "home/decoration/obj_lavamanos.png", solid_rows = 1 },
	{ name = "shower", texture = "home/decoration/obj_ducha.png", solid_rows = 2 },
	{ name = "bookshelf", folder = "office", texture = "office/decoration/obj_bookshelf.png", solid_rows = 2 },
	{ name = "boxes", folder = "office", texture = "office/decoration/obj_boxes.png", solid_rows = 1 },
	{ name = "coffee_station", folder = "office", texture = "office/decoration/obj_coffee_station.png", solid_rows = 1 },
	{ name = "counter_a", folder = "office", texture = "office/decoration/obj_counter_a.png", solid_rows = 1 },
	{ name = "counter_b", folder = "office", texture = "office/decoration/obj_counter_b.png", solid_rows = 1 },
	{ name = "cubicle", folder = "office", texture = "office/decoration/obj_cubicle.png", solid_rows = 1 },
	{ name = "delivery_tray", folder = "office", texture = "office/decoration/obj_delivery_tray.png", solid_rows = 1 },
	{ name = "extinguisher", folder = "office", texture = "office/decoration/obj_extinguisher.png", solid_rows = 1 },
	{ name = "filing_cabinet", folder = "office", texture = "office/decoration/obj_filing_cabinet.png", solid_rows = 2 },
	{ name = "office_chair", folder = "office", texture = "office/decoration/obj_office_chair.png", solid_rows = 1 },
	{ name = "office_desk", folder = "office", texture = "office/decoration/obj_office_desk.png", solid_rows = 1 },
	{ name = "office_trash", folder = "office", texture = "office/decoration/obj_office_trash.png", solid_rows = 1 },
	{ name = "plant", folder = "office", texture = "office/decoration/obj_plant.png", solid_rows = 1 },
	{ name = "plant_big", folder = "office", texture = "office/decoration/obj_plant_big.png", solid_rows = 1 },
	{ name = "printer", folder = "office", texture = "office/decoration/obj_printer.png", solid_rows = 1 },
	{ name = "reception_desk", folder = "office", texture = "office/decoration/obj_reception_desk.png", solid_rows = 1 },
	{ name = "sofa", folder = "office", texture = "office/decoration/obj_sofa.png", solid_rows = 1 },
	{ name = "stanchion", folder = "office", texture = "office/decoration/obj_stanchion.png", solid_rows = 1 },
	{ name = "water_cooler", folder = "office", texture = "office/decoration/obj_water_cooler.png", solid_rows = 1 },
	{ name = "bench", folder = "street", texture = "street/decoration/obj_bench.png", solid_rows = 1 },
	{ name = "bench_dusk", folder = "street", texture = "street/decoration/obj_bench_dusk.png", solid_rows = 1 },
	{ name = "bench_night", folder = "street", texture = "street/decoration/obj_bench_night.png", solid_rows = 1 },
	{ name = "bollard", folder = "street", texture = "street/decoration/obj_bollard.png", solid_rows = 1 },
	{ name = "bollard_dusk", folder = "street", texture = "street/decoration/obj_bollard_dusk.png", solid_rows = 1 },
	{ name = "bollard_night", folder = "street", texture = "street/decoration/obj_bollard_night.png", solid_rows = 1 },
	{ name = "bus_stop", folder = "street", texture = "street/decoration/obj_bus_stop.png", solid_rows = 2 },
	{ name = "bus_stop_dusk", folder = "street", texture = "street/decoration/obj_bus_stop_dusk.png", solid_rows = 2 },
	{ name = "bus_stop_night", folder = "street", texture = "street/decoration/obj_bus_stop_night.png", solid_rows = 2 },
	{ name = "coffee_cart", folder = "street", texture = "street/decoration/obj_coffee_cart.png", solid_rows = 2 },
	{ name = "coffee_cart_dusk", folder = "street", texture = "street/decoration/obj_coffee_cart_dusk.png", solid_rows = 2 },
	{ name = "coffee_cart_night", folder = "street", texture = "street/decoration/obj_coffee_cart_night.png", solid_rows = 2 },
	{ name = "empanada_stand", folder = "street", texture = "street/decoration/obj_empanada_stand.png", solid_rows = 2 },
	{ name = "empanada_stand_dusk", folder = "street", texture = "street/decoration/obj_empanada_stand_dusk.png", solid_rows = 2 },
	{ name = "empanada_stand_night", folder = "street", texture = "street/decoration/obj_empanada_stand_night.png", solid_rows = 2 },
	{ name = "hydrant", folder = "street", texture = "street/decoration/obj_hydrant.png", solid_rows = 1 },
	{ name = "hydrant_dusk", folder = "street", texture = "street/decoration/obj_hydrant_dusk.png", solid_rows = 1 },
	{ name = "hydrant_night", folder = "street", texture = "street/decoration/obj_hydrant_night.png", solid_rows = 1 },
	{ name = "kiosk", folder = "street", texture = "street/decoration/obj_kiosk.png", solid_rows = 2 },
	{ name = "kiosk_dusk", folder = "street", texture = "street/decoration/obj_kiosk_dusk.png", solid_rows = 2 },
	{ name = "kiosk_night", folder = "street", texture = "street/decoration/obj_kiosk_night.png", solid_rows = 2 },
	{ name = "lamppost", folder = "street", texture = "street/decoration/obj_lamppost.png", solid_rows = 1 },
	{ name = "lamppost_dusk", folder = "street", texture = "street/decoration/obj_lamppost_dusk.png", solid_rows = 1 },
	{ name = "lamppost_night", folder = "street", texture = "street/decoration/obj_lamppost_night.png", solid_rows = 1 },
	{ name = "planter", folder = "street", texture = "street/decoration/obj_planter.png", solid_rows = 1 },
	{ name = "planter_dusk", folder = "street", texture = "street/decoration/obj_planter_dusk.png", solid_rows = 1 },
	{ name = "planter_night", folder = "street", texture = "street/decoration/obj_planter_night.png", solid_rows = 1 },
	{ name = "stop_sign", folder = "street", texture = "street/decoration/obj_stop_sign.png", solid_rows = 1 },
	{ name = "stop_sign_dusk", folder = "street", texture = "street/decoration/obj_stop_sign_dusk.png", solid_rows = 1 },
	{ name = "stop_sign_night", folder = "street", texture = "street/decoration/obj_stop_sign_night.png", solid_rows = 1 },
	{ name = "trash_can", folder = "street", texture = "street/decoration/obj_trash_can.png", solid_rows = 1 },
	{ name = "trash_can_dusk", folder = "street", texture = "street/decoration/obj_trash_can_dusk.png", solid_rows = 1 },
	{ name = "trash_can_night", folder = "street", texture = "street/decoration/obj_trash_can_night.png", solid_rows = 1 },
	{ name = "tree", folder = "street", texture = "street/decoration/obj_tree.png", solid_rows = 2 },
	{ name = "tree_dusk", folder = "street", texture = "street/decoration/obj_tree_dusk.png", solid_rows = 2 },
	{ name = "tree_night", folder = "street", texture = "street/decoration/obj_tree_night.png", solid_rows = 2 },
]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var created: int = 0
	for spec: Dictionary in PROPS:
		if _create_definition(spec):
			created += 1
	EditorInterface.get_resource_filesystem().scan()
	print("Prop definitions: %d new, %d in the table." % [created, PROPS.size()])


## Returns true if a new file was written.
func _create_definition(spec: Dictionary) -> bool:
	var output_dir: String = OUTPUT_DIR
	var folder: String = str(spec.get("folder", ""))
	if not folder.is_empty():
		output_dir += folder + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var output_path: String = "%s%s.tres" % [output_dir, spec.name]
	if ResourceLoader.exists(output_path):
		print("  [skip] %s already exists" % output_path)
		return false

	var texture: Texture2D = load(TEXTURES_DIR + str(spec.texture))
	if texture == null:
		push_error("Missing texture: %s" % spec.texture)
		return false

	var definition: PropDefinition = PropDefinition.new()
	definition.texture = texture
	definition.footprint = _measure_footprint(texture, spec.get("solid_rows", DEFAULT_SOLID_ROWS))
	var error: Error = ResourceSaver.save(definition, output_path)
	if error != OK:
		push_error("Could not save %s (error %d)." % [output_path, error])
		return false

	print("  [new] %s | png %s | footprint %s" % [spec.name, Vector2i(texture.get_size()), definition.footprint])
	return true


## Footprint relative to the bottom center of the texture (the Prop's origin).
func _measure_footprint(texture: Texture2D, solid_rows: int) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	var image: Image = texture.get_image()
	var used_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(texture_size))
	if image != null:
		used_rect = image.get_used_rect()  # Bounding box of the non-transparent pixels.

	var height: int = mini(solid_rows * PropDefinition.ART_TILE, used_rect.size.y)
	var bottom: float = used_rect.end.y - texture_size.y  # Distance from the origin up to the visible bottom.
	return Rect2(
		used_rect.position.x - texture_size.x / 2.0,
		bottom - height,
		used_rect.size.x,
		height
	)
