@tool
extends EditorScript
## Builds one DecisionDefinition (.tres) per NPC from the table below, which mirrors
## OneMoreDay_Diseño.xlsx, tab "4 Decisiones".
## Run: open this file in the Script editor, then File > Run (Ctrl+Shift+X).
## The table is the source of truth: running it OVERWRITES the .tres files.
## WARNING: the .tres now carry fields this table does not have (minigame, queue, next_scene, risk_*,
## bonus_*). Running it would erase them: edit those decisions in the Inspector instead.
## To rebalance (P4-13): edit the numbers here and run it again.
## It warns when an option is dominated (better than another in no resource) or when the
## options of one NPC are too far apart (design rule of the Excel).

const OUTPUT_DIR: String = "res://data/decisions/"
## Value of 1 money unit in points (Excel, tab "Guía", cell B8).
const MONEY_POINTS: float = 3.0
## Largest acceptable difference between the weighted totals of one NPC's options.
const MAX_SPREAD: float = 10.0

const DECISIONS: Array[Dictionary] = [
	{
		file = "npc_01_coffee_vendor", id = "NPC-01", speaker = "Vendedora de tinto",
		prompt = "«Mijo, ¿un tintico para arrancar el día?»",
		options = [
			{ text = "Tinto y empanada", money = -2.0, energy = 10.0, time = -5.0 },
			{ text = "Pasar de largo", money = 0.0, energy = -5.0, time = 5.0 },
			{ text = "Charlar un momento con ella", money = 0.0, energy = 5.0, time = -5.0 },
		],
	},
	{
		file = "npc_02_bus_driver", id = "NPC-02", speaker = "Conductor de buseta",
		prompt = "«Va directo, sube que ya salimos.»",
		options = [
			{ text = "Pagar la buseta directa", money = -3.0, energy = 0.0, time = 10.0 },
			{ text = "Caminar el resto", money = 0.0, energy = -3.0, time = -2.0 },
			{ text = "Aceptar el aventón en moto de un vecino", money = -2.0, energy = 0.0, time = 5.0 },
		],
	},
	{
		file = "npc_03_coworker", id = "NPC-03", speaker = "Compañero de oficina",
		prompt = "«¿Me ayudas con esto? Yo te respondo luego.»",
		options = [
			{ text = "Ayudarle con su informe", money = 5.0, energy = -10.0, time = -5.0 },
			{ text = "Tomarse un tinto y conversar", money = -2.0, energy = 10.0, time = -5.0 },
			{ text = "Seguir de largo con lo tuyo", money = 0.0, energy = -5.0, time = 5.0 },
		],
	},
	{
		file = "npc_04_supervisor", id = "NPC-04", speaker = "Supervisora",
		prompt = "«Hoy necesitamos gente para cerrar el turno.»",
		options = [
			{ text = "Aceptar el turno extra", money = 10.0, energy = -15.0, time = -10.0 },
			{ text = "Pedir salir temprano", money = -5.0, energy = 5.0, time = 10.0 },
			{ text = "Hacer solo lo tuyo", money = 0.0, energy = -5.0, time = 5.0 },
		],
	},
	{
		file = "npc_05_empanada_vendor", id = "NPC-05", speaker = "Vendedor de empanadas",
		prompt = "«Calientes, calientes, a mil quinientos.»",
		options = [
			{ text = "Empanada y gaseosa", money = -3.0, energy = 15.0, time = -5.0 },
			{ text = "Aguantar el hambre", money = 0.0, energy = -5.0, time = 5.0 },
			{ text = "Comprar solo una fruta", money = -1.0, energy = 5.0, time = 0.0 },
		],
	},
	{
		file = "npc_06_neighbor", id = "NPC-06", speaker = "Vecina del barrio",
		prompt = "«Venga, lo veo cansado. Tome un platico.»",
		options = [
			{ text = "Aceptar el plato de comida", money = 0.0, energy = 10.0, time = -10.0 },
			{ text = "Saludar y seguir", money = 0.0, energy = 0.0, time = 5.0 },
			{ text = "Ayudarle con las bolsas", money = 4.0, energy = -10.0, time = -5.0 },
		],
	},
]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var saved: int = 0
	for spec: Dictionary in DECISIONS:
		if _save_decision(spec):
			saved += 1
	EditorInterface.get_resource_filesystem().scan()
	print("Decisions: %d of %d saved in %s" % [saved, DECISIONS.size(), OUTPUT_DIR])


## Returns true if the file was written.
func _save_decision(spec: Dictionary) -> bool:
	var decision: DecisionDefinition = DecisionDefinition.new()
	decision.id = str(spec.id)
	decision.speaker_name = str(spec.speaker)
	decision.prompt = str(spec.prompt)
	var options: Array[DecisionOption] = []
	for option_spec: Dictionary in spec.options:
		options.append(_make_option(option_spec))
	decision.options = options
	_check_balance(decision.id, options)

	var path: String = "%s%s.tres" % [OUTPUT_DIR, spec.file]
	var error: Error = ResourceSaver.save(decision, path)
	if error != OK:
		push_error("Could not save %s (error %d)." % [path, error])
		return false
	print("  [saved] %s" % path)
	return true


func _make_option(option_spec: Dictionary) -> DecisionOption:
	var option: DecisionOption = DecisionOption.new()
	option.text = str(option_spec.text)
	option.money = float(option_spec.money)
	option.energy = float(option_spec.energy)
	option.time = float(option_spec.time)
	return option


func _check_balance(decision_id: String, options: Array[DecisionOption]) -> void:
	var totals: Array[float] = []
	for option: DecisionOption in options:
		totals.append(option.money * MONEY_POINTS + option.energy + option.time)
	var spread: float = float(totals.max()) - float(totals.min())
	if spread > MAX_SPREAD:
		push_warning("%s: weighted totals %s differ by %.0f points (max %.0f)." % [
			decision_id, totals, spread, MAX_SPREAD])

	for worse: DecisionOption in options:
		for better: DecisionOption in options:
			if worse != better and _dominates(better, worse):
				push_warning("%s: '%s' is dominated by '%s'." % [decision_id, worse.text, better.text])


## True when [param better] is no worse in any resource and strictly better in at least one.
static func _dominates(better: DecisionOption, worse: DecisionOption) -> bool:
	var no_worse: bool = (better.money >= worse.money and better.energy >= worse.energy
		and better.time >= worse.time)
	var strictly_better: bool = (better.money > worse.money or better.energy > worse.energy
		or better.time > worse.time)
	return no_worse and strictly_better
