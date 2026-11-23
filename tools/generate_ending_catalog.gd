@tool
extends EditorScript
## Builds data/endings/ending_catalog.tres from the table below, which mirrors
## OneMoreDay_Diseño.xlsx, tab "7 Finales".
## Run: open this file in the Script editor, then File > Run (Ctrl+Shift+X).
## The table is the source of truth: running it OVERWRITES the catalog.
## To rename an image or rebalance a threshold (P4-13), edit it here and run it again.

const OUTPUT_PATH: String = "res://data/endings/ending_catalog.tres"
const IMAGES_DIR: String = "res://assets/sprites/endings/"

# Thresholds of the conditions (tab "7 Finales").
const CHALLENGE_SPARE_SECONDS: float = 15.0
const RICH_MONEY: float = 25.0
const COMFORT_MONEY: float = 10.0
const COMFORT_ENERGY: float = 20.0
const COMFORT_TIME: float = 10.0

const ENDINGS: Array[Dictionary] = [
	{
		id = "V-01", victory = true, image = "ending_v01.png",
		text = "Llegas a casa con las piernas cansadas y el bolsillo justo, pero con algo para compartir. En la mesa, el olor del almuerzo y la voz de mamá: «Qué bueno que ya llegó». Hoy fue un día más, y valió la pena.",
	},
	{
		id = "V-02", victory = true, image = "ending_v02.png",
		text = "Llegas arrastrando los pasos, sin plata y sin ganas, pero llegas. La puerta se abre y alguien dejó la luz prendida. Mañana será otro día más.",
	},
	{
		id = "V-03", victory = true, image = "ending_v03.png",
		text = "Esa noche le cuentas a alguien cómo te fue y alguien más te escucha. Entre un favor devuelto y un plato compartido, el cansancio pesa menos. Nadie sale adelante solo.",
	},
	{
		id = "V-04", victory = true, image = "ending_v04.png",
		text = "Entregaste justo a tiempo y por un momento el reloj fue tu aliado. Ya en casa recuerdas la cara de tu jefe al ver todo listo. Hoy te sentiste capaz.",
	},
	{
		id = "V-05", victory = true, image = "ending_v05.png",
		text = "Con lo que lograste ahorrar hoy, pasas por la panadería y compras pan para todos. La casa huele a chocolate caliente y alguien ya puso la mesa. Un detalle pequeño, un día mejor.",
	},
	{
		id = "D-01", victory = false, image = "ending_d01.png",
		text = "Hoy la plata no alcanzó. Entre pasajes, gastos e imprevistos, el bolsillo quedó vacío antes de terminar el camino. Tocó pedir fiado y volver a intentarlo mañana.",
	},
	{
		id = "D-02", victory = false, image = "ending_d02.png",
		text = "El cuerpo dijo basta. Después de tantas filas, escaleras y esperas, las piernas ya no respondieron. Te sentaste un momento y el día siguió sin ti.",
	},
	{
		id = "D-03", victory = false, image = "ending_d03.png",
		text = "El reloj ganó. Entre el trancón y los retrasos, el día se acabó antes de que llegaras. Mañana habrá que salir más temprano.",
	},
	{
		id = "D-04", victory = false, image = "ending_d04.png",
		text = "Un descuido en la calle te dejó sin lo que traías. No fue culpa tuya: a veces el día se tuerce. Llegas con las manos vacías y el ánimo por el piso.",
	},
	{
		id = "D-05", victory = false, image = "ending_d05.png",
		text = "La alarma sonó y el reloj no perdonó. No alcanzaste a entregar a tiempo. Pero ya sabes cuánto cuesta cada minuto.",
	},
]


func _run() -> void:
	var catalog: EndingCatalog = EndingCatalog.new()
	var endings: Array[EndingDefinition] = []
	for spec: Dictionary in ENDINGS:
		endings.append(_make_ending(spec))
	catalog.endings = endings
	catalog.challenge_spare_seconds = CHALLENGE_SPARE_SECONDS
	catalog.rich_money = RICH_MONEY
	catalog.comfort_money = COMFORT_MONEY
	catalog.comfort_energy = COMFORT_ENERGY
	catalog.comfort_time = COMFORT_TIME

	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var error: Error = ResourceSaver.save(catalog, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save %s (error %d)." % [OUTPUT_PATH, error])
		return
	EditorInterface.get_resource_filesystem().scan()
	print("Ending catalog saved: %d endings in %s" % [endings.size(), OUTPUT_PATH])


func _make_ending(spec: Dictionary) -> EndingDefinition:
	var ending: EndingDefinition = EndingDefinition.new()
	ending.id = str(spec.id)
	ending.is_victory = bool(spec.victory)
	ending.text = str(spec.text)
	var image_path: String = IMAGES_DIR + str(spec.image)
	if ResourceLoader.exists(image_path):
		ending.image = load(image_path) as Texture2D
	else:
		push_warning("%s: image not found: %s" % [ending.id, image_path])
	return ending
