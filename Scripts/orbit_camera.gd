extends Camera3D
class_name OrbitCamera

@export var target: Node3D
@export var distance: float = 10.0
@export var sensitivity: float = 2.0
@export var min_pitch: float = -89.9
@export var max_pitch: float = 89.9

var yaw: float = 0.0
var pitch: float = 0.0

func _ready():
	if not target:
		printerr("OrbitCamera: nessun Target assegnato.")
		return

	var dir: Vector3 = global_position - target.global_position
	if dir.length_squared() < 0.001:
		distance = max(distance, 5.0)
		yaw = 0.0
		pitch = 0.0
	else:
		yaw = rad_to_deg(atan2(dir.x, dir.z))
		pitch = rad_to_deg(asin(dir.y / dir.length()))

	_update_position()

func _input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * sensitivity * 0.01
		pitch -= event.relative.y * sensitivity * 0.01
		pitch = clamp(pitch, min_pitch, max_pitch)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += 1.0
		distance = clamp(distance, 2.0, 100.0)

func _process(_delta):
	if not target:
		return
	_update_position()

func _update_position():
	var offset: Vector3 = Vector3(0, 0, distance)
	var rot: Quaternion = Quaternion.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	position = target.global_position + rot * offset

	var dir: Vector3 = (target.global_position - position).normalized()
	var up: Vector3 = Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3(1, 0, 0)
	look_at(target.global_position, up)
