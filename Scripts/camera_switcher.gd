extends Node3D
class_name CameraSwitcher

var external_cam: Camera3D
var cab_cam: Camera3D
var in_cab: bool = false

func _ready():
    external_cam = get_node("ExternalCamera")
    cab_cam = get_node("CabCamera")
    external_cam.current = true
    cab_cam.current = false

func _input(event):
    if event.is_action_pressed("switch_view"):
        in_cab = not in_cab
        external_cam.current = not in_cab
        cab_cam.current = in_cab