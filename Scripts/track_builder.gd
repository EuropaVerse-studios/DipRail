extends Node3D
class_name TrackBuilder

@export var track_file: String = "res://Data/Tracks/test_line.json"
@export var sample_interval: float = 0.5

var curve: Curve3D

func _ready():
	var path_node = get_parent() as Path3D
	if not path_node:
		printerr("TrackBuilder deve essere figlio di un Path3D.")
		return

	var points = load_and_generate_points(track_file)
	if points.is_empty():
		printerr("Nessun punto generato.")
		return

	curve = Curve3D.new()
	for p in points:
		curve.add_point(p)
	curve.bake_interval = sample_interval
	path_node.curve = curve

	generate_all(points)

func generate_all(points: PackedVector3Array):
	var container = get_node("../TrackMesh") as Node3D
	if not container:
		printerr("Nodo TrackMesh non trovato.")
		return

	for child in container.get_children():
		child.queue_free()

	var segment_scene = load("res://Assets/Models/Tracks/rail_segment.glb") as PackedScene
	if not segment_scene:
		printerr("rail_segment.glb non trovato.")
		return

	var instance = segment_scene.instantiate()
	var mesh: Mesh = null
	for child in instance.get_children():
		if child is MeshInstance3D:
			mesh = child.mesh
			break
	instance.queue_free()
	if not mesh:
		printerr("Nessuna mesh trovata nel GLB.")
		return

	# Applica i materiali PBR (prima di usare il MultiMesh)
	var rail_mat = load("res://Materials/rail_material.tres") as Material
	var sleeper_mat = load("res://Materials/sleeper_material.tres") as Material
	var ballast_mat = load("res://Materials/ballast_material.tres") as Material
	if rail_mat:
		mesh.surface_set_material(0, rail_mat)
	if sleeper_mat:
		mesh.surface_set_material(1, sleeper_mat)
	if ballast_mat:
		mesh.surface_set_material(2, ballast_mat)

	# Crea il MultiMesh
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh

	var segment_length = 1.0
	var total_length = 0.0
	for i in range(1, points.size()):
		total_length += (points[i] - points[i-1]).length()
	var instance_count = ceili(total_length / segment_length)
	mm.instance_count = instance_count

	var dist = 0.0
	for i in range(instance_count):
		var pos = _point_at_distance(points, dist)
		var tangent = _tangent_at_distance(points, dist)
		var up = Vector3.UP
		var right = tangent.cross(up).normalized()
		up = right.cross(tangent).normalized()
		var basis = Basis(right, up, tangent)
		mm.set_instance_transform(i, Transform3D(basis, pos))
		dist += segment_length

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	container.add_child(mmi)

# ----------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------
func _point_at_distance(points: PackedVector3Array, dist: float) -> Vector3:
	var accum = 0.0
	for i in range(1, points.size()):
		var seg = (points[i] - points[i-1]).length()
		if accum + seg >= dist:
			var t = (dist - accum) / seg
			return points[i-1].lerp(points[i], t)
		accum += seg
	return points[-1] if points.size() > 0 else Vector3.ZERO

func _tangent_at_distance(points: PackedVector3Array, dist: float) -> Vector3:
	var accum = 0.0
	for i in range(1, points.size()):
		var seg = (points[i] - points[i-1]).length()
		if accum + seg >= dist:
			return (points[i] - points[i-1]).normalized()
		accum += seg
	return (points[-1] - points[-2]).normalized() if points.size() > 1 else Vector3.FORWARD

# ----------------------------------------------------------------------
# CARICAMENTO JSON (identico a prima)
# ----------------------------------------------------------------------
func load_and_generate_points(file_path: String) -> PackedVector3Array:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("File %s non trovato." % file_path)
		return PackedVector3Array()

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		printerr("Errore parsing JSON.")
		return PackedVector3Array()

	var data = json.get_data()
	var tracks = data.get("tracks", [])
	if tracks.is_empty():
		tracks = [data]

	var track_def = tracks[0]
	if track_def.has("offsetFrom"):
		var ref_name = track_def["offsetFrom"]
		for t in tracks:
			if t["name"] == ref_name:
				track_def = t
				break

	var start = track_def.get("start", {"x": 0, "y": 0, "z": 0})
	var pos = Vector3(start["x"], start["y"], start["z"])
	var dir = deg_to_rad(track_def.get("startDirection", 0))
	var segments = track_def.get("segments", [])

	var pts = PackedVector3Array()
	pts.append(pos)

	for seg in segments:
		var seg_type = seg.get("type", "")
		var length = seg.get("length", 0.0)
		var grade = seg.get("grade", 0.0)
		if length <= 0:
			continue

		var start_y = pos.y

		match seg_type:
			"straight":
				var forward = Vector3(sin(dir), 0, cos(dir))
				var steps = floor(length / sample_interval)
				for i in range(1, steps + 1):
					var d = i * sample_interval
					var p = pos + forward * d
					p.y = start_y + d * grade / 100.0
					pts.append(p)
				var final = pos + forward * length
				final.y = start_y + length * grade / 100.0
				pts.append(final)
				pos = final

			"curve":
				var radius = seg.get("radius", 100.0)
				var angle_deg = seg.get("angle", 0.0)
				var angle_rad = deg_to_rad(abs(angle_deg))
				var sign_val = sign(angle_deg)
				var arc_length = radius * angle_rad

				var perp = Vector3(cos(dir), 0, -sin(dir))
				var center = pos + perp * radius * sign_val
				var r = pos - center
				var start_angle = atan2(r.z, r.x)

				var steps = floor(arc_length / sample_interval)
				for i in range(1, steps + 1):
					var d = i * sample_interval
					var delta = d / radius * sign_val
					var angle = start_angle + delta
					var p = center + Vector3(cos(angle), 0, sin(angle)) * radius
					p.y = start_y + d * grade / 100.0
					pts.append(p)

				var total_delta = angle_rad * sign_val
				var final_angle = start_angle + total_delta
				var final = center + Vector3(cos(final_angle), 0, sin(final_angle)) * radius
				final.y = start_y + arc_length * grade / 100.0
				pts.append(final)
				pos = final
				dir += total_delta

			"easement":
				var r_start = seg.get("radiusStart", 0.0)
				var r_end = seg.get("radiusEnd", 0.0)
				var sign_val = 1.0
				if r_start == 0 and r_end != 0:
					sign_val = sign(r_end)
				elif r_end == 0 and r_start != 0:
					sign_val = sign(r_start)
				else:
					sign_val = sign(r_start)

				var curv_start = 1.0 / r_start if r_start != 0 else 0.0
				var curv_end = 1.0 / r_end if r_end != 0 else 0.0

				var steps = floor(length / sample_interval)
				for i in range(1, steps + 1):
					var d = i * sample_interval
					var t = d / length
					var curv = curv_start + (curv_end - curv_start) * t
					if curv == 0:
						var forward = Vector3(sin(dir), 0, cos(dir))
						var p = pos + forward * sample_interval
						p.y = start_y + d * grade / 100.0
						pts.append(p)
						pos = p
					else:
						var cur_radius = 1.0 / curv
						var delta = sample_interval / cur_radius * sign_val
						var perp = Vector3(cos(dir), 0, -sin(dir))
						var center = pos + perp * cur_radius * sign_val
						var rx = pos.x - center.x
						var rz = pos.z - center.z
						var cos_d = cos(delta)
						var sin_d = sin(delta)
						var new_rx: float
						var new_rz: float
						if sign_val > 0:
							new_rx = rx * cos_d + rz * sin_d
							new_rz = -rx * sin_d + rz * cos_d
						else:
							new_rx = rx * cos_d - rz * sin_d
							new_rz = rx * sin_d + rz * cos_d
						var p = center + Vector3(new_rx, 0, new_rz)
						p.y = start_y + d * grade / 100.0
						pts.append(p)
						pos = p
						dir += delta

				var remaining = length - steps * sample_interval
				if remaining > 0.0001:
					var curv = curv_end
					if curv == 0:
						var forward = Vector3(sin(dir), 0, cos(dir))
						var p = pos + forward * remaining
						p.y = start_y + length * grade / 100.0
						pts.append(p)
						pos = p
					else:
						var cur_radius = 1.0 / curv
						var delta = remaining / cur_radius * sign_val
						var perp = Vector3(cos(dir), 0, -sin(dir))
						var center = pos + perp * cur_radius * sign_val
						var rx = pos.x - center.x
						var rz = pos.z - center.z
						var cos_d = cos(delta)
						var sin_d = sin(delta)
						var new_rx: float
						var new_rz: float
						if sign_val > 0:
							new_rx = rx * cos_d + rz * sin_d
							new_rz = -rx * sin_d + rz * cos_d
						else:
							new_rx = rx * cos_d - rz * sin_d
							new_rz = rx * sin_d + rz * cos_d
						var p = center + Vector3(new_rx, 0, new_rz)
						p.y = start_y + length * grade / 100.0
						pts.append(p)
						pos = p
						dir += delta

	return pts
