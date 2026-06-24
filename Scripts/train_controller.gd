extends CharacterBody3D
class_name TrainController

# -------------------- Parametri esportati --------------------
@export_group("Fisica")
@export var max_power: float = 500000.0          # Watt
@export var mass: float = 100000.0               # kg
@export var max_brake_force: float = 200000.0    # N
@export var max_speed: float = 80.0              # m/s
@export var max_acceleration: float = 2.0        # m/s²
@export var max_deceleration: float = 3.0        # m/s²

@export_group("Percorso")
@export var height_above_rail: float = 0.25
@export var loop: bool = false
@export var start_progress: float = 0.1

@export_group("Controlli")
@export var debug: bool = true

# -------------------- Variabili interne --------------------
var path_follow: PathFollow3D
var path3d: Path3D
var current_speed: float = 0.0
var progress: float = 0.0
var ready_to_move: bool = false
var has_checked_curve: bool = false

# -------------------- _ready() --------------------
func _ready():
	path_follow = get_parent() as PathFollow3D
	if not path_follow:
		printerr("TrainController deve essere figlio di un PathFollow3D.")
		return

	path3d = path_follow.get_parent() as Path3D
	if not path3d:
		printerr("PathFollow3D deve essere figlio di un Path3D.")
		return

	_load_train_data("res://Data/train.json")

	path_follow.v_offset = height_above_rail

	# Disabilita rotazione automatica per evitare il bug della tangente zero
	path_follow.rotation_mode = PathFollow3D.ROTATION_NONE

	progress = start_progress

	if debug:
		print("TrainController in attesa del percorso...")

# -------------------- _physics_process() --------------------
func _physics_process(delta):
	if not ready_to_move:
		_try_initialize_path()
		return

	if not path_follow or not path3d:
		return

	var curve_length = _get_curve_length()
	if curve_length <= 0.5:
		return

	# Input
	var throttle = Input.get_action_strength("accelerate")
	var brake = Input.get_action_strength("brake")

	# Forze
	var tractive_force = 0.0
	if current_speed < max_speed and throttle > 0:
		var effective_speed = max(current_speed, 0.5)
		tractive_force = max_power / effective_speed
		tractive_force = min(tractive_force, max_power * 2.0)

	var brake_force = brake * max_brake_force
	var net_force = tractive_force * throttle - brake_force

	# Accelerazione
	var acceleration = net_force / mass
	acceleration = clamp(acceleration, -max_deceleration, max_acceleration)

	current_speed += acceleration * delta
	current_speed = clamp(current_speed, 0.0, max_speed)

	# Avanzamento
	progress += current_speed * delta

	if loop:
		if progress >= curve_length:
			progress = 0.1
	else:
		if progress >= curve_length - 0.1:
			progress = curve_length - 0.1
			current_speed = 0.0

	progress = clamp(progress, 0.05, curve_length - 0.05)

	# Applica posizione al PathFollow (senza rotazione)
	path_follow.progress = progress

	# ---- ROTAZIONE MANUALE ----
	# Usa il Curve3D per calcolare direzione di marcia
	var current_pos = path3d.curve.sample_baked(progress)
	var lookahead = min(progress + 0.5, curve_length - 0.05)
	var next_pos = path3d.curve.sample_baked(lookahead)
	var direction = (next_pos - current_pos).normalized()

	if direction.length() > 0.001:
		var up = Vector3.UP
		var new_basis = Basis.looking_at(direction, up)
		transform.basis = new_basis

# -------------------- Inizializzazione ritardata --------------------
func _try_initialize_path():
	if not path3d or not path3d.curve:
		return

	var length = _get_curve_length()
	if length > 0.5:
		ready_to_move = true
		progress = clamp(progress, 0.05, length - 0.05)
		path_follow.progress = progress
		if debug:
			print("Percorso caricato! Lunghezza: ", length, " m")
	else:
		if debug and not has_checked_curve:
			has_checked_curve = true
			print("Attesa costruzione percorso... (lunghezza attuale: ", length, ")")

# -------------------- Utility --------------------
func _get_curve_length() -> float:
	if path3d and path3d.curve:
		return path3d.curve.get_baked_length()
	return 0.0

# -------------------- Caricamento JSON --------------------
func _load_train_data(file_path: String):
	if not FileAccess.file_exists(file_path):
		if debug: print("File ", file_path, " non trovato. Uso parametri di default.")
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("Errore parsing JSON: ", json.get_error_message())
		return

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		printerr("JSON non è un dizionario valido.")
		return

	if "maxPower" in data: max_power = data["maxPower"]
	if "mass" in data: mass = data["mass"]
	if "maxBrakeForce" in data: max_brake_force = data["maxBrakeForce"]
	if "maxSpeed" in data: max_speed = data["maxSpeed"]
	if "maxAcceleration" in data: max_acceleration = data["maxAcceleration"]
	if "maxDeceleration" in data: max_deceleration = data["maxDeceleration"]
	if "heightAboveRail" in data: height_above_rail = data["heightAboveRail"]

	if debug: print("Parametri caricati da ", file_path)

# -------------------- Metodi pubblici --------------------
func get_current_speed() -> float:
	return current_speed

func get_progress() -> float:
	return progress

func get_curve_length() -> float:
	return _get_curve_length()

func set_speed(speed: float):
	current_speed = clamp(speed, 0.0, max_speed)

func teleport_to_progress(new_progress: float):
	var length = _get_curve_length()
	if length > 0.0:
		progress = clamp(new_progress, 0.05, length - 0.05)
		if ready_to_move:
			path_follow.progress = progress
		current_speed = 0.0