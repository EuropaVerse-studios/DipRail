extends Camera3D
class_name CabCamera

@export var target: Node3D

func _process(_delta):
    if not target:
        return
    global_transform = target.global_transform