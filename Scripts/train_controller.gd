extends CharacterBody3D
class_name TrainController

@export var max_power: float = 500000.0   # Watt
@export var mass: float = 100000.0        # kg
@export var max_brake_force: float = 200000.0
@export var max_speed: float = 80.0       # m/s

var path_follow: PathFollow3D
var current_speed: float = 0.0
var progress: float = 0.0

func _ready():
    path_follow = get_parent() as PathFollow3D
    if not path_follow:
        printerr("PlayerTrain deve essere figlio di un PathFollow3D.")
        return
    _load_train_data("res://Data/train.json")

func _physics_process(delta):
    if not path_follow:
        return

    var throttle = Input.get_action_strength("accelerate")
    var brake = Input.get_action_strength("brake")

    var tractive_force = 0.0
    if current_speed < max_speed and throttle > 0:
        var force = max_power / max(current_speed, 0.1)
        tractive_force = min(force, 500000.0)

    var brake_force = brake * max_brake_force
    var net_force = tractive_force * throttle - brake_force

    var acceleration = net_force / mass
    current_speed += acceleration * delta
    if current_speed < 0:
        current_speed = 0

    progress += current_speed * delta
    path_follow.progress = progress

func _load_train_data(path: String):
    if not FileAccess.file_exists(path):
        print("File ", path, " non trovato, uso parametri di default.")
        return

    var file = FileAccess.open(path, FileAccess.READ)
    var json_text = file.get_as_text()
    var json = JSON.new()
    var error = json.parse(json_text)
    if error != OK:
        printerr("Errore parsing train.json")
        return

    var data = json.get_data()
    if "maxPower" in data: max_power = data["maxPower"]
    if "mass" in data: mass = data["mass"]
    if "maxBrakeForce" in data: max_brake_force = data["maxBrakeForce"]
    if "maxSpeed" in data: max_speed = data["maxSpeed"]