import bpy
import os
import math

# ------------------------------------------------------------
# PARAMETRI
# ------------------------------------------------------------
SEGMENT_LENGTH = 1.0
GAUGE_HALF = 0.75
RAIL_HEIGHT = 0.172
RAIL_BASE_WIDTH = 0.150
RAIL_HEAD_WIDTH = 0.072
RAIL_WEB_THICKNESS = 0.0165
SLEEPER_LENGTH = 2.5
SLEEPER_WIDTH = 0.18
SLEEPER_THICKNESS = 0.15
BALLAST_WIDTH = 3.0
BALLAST_DEPTH = 0.3

# ------------------------------------------------------------
# PULIZIA SCENA
# ------------------------------------------------------------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# ------------------------------------------------------------
# MATERIALI PBR REALISTICI
# ------------------------------------------------------------
def create_material(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (400, 0)
    mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

# Rotaia: acciaio arrugginito (scuro, metallico, moderatamente ruvido)
mat_rail = create_material("Rail", (0.15, 0.10, 0.07, 1.0), metallic=1.0, roughness=0.6)

# Traversina: legno vecchio (marrone caldo, non metallico, molto ruvido)
mat_sleeper = create_material("Sleeper", (0.30, 0.18, 0.10, 1.0), metallic=0.0, roughness=0.9)

# Massicciata: pietrisco grigio-marrone (non metallico, ruvidissimo)
mat_ballast = create_material("Ballast", (0.40, 0.38, 0.35, 1.0), metallic=0.0, roughness=1.0)

# ------------------------------------------------------------
# PROFILO ROTAIA UIC60
# ------------------------------------------------------------
def create_rail_profile():
    h = RAIL_HEIGHT
    bw2 = RAIL_BASE_WIDTH / 2
    hw2 = RAIL_HEAD_WIDTH / 2
    wt2 = RAIL_WEB_THICKNESS / 2
    return [
        (0, 0),
        (bw2, 0),
        (bw2, 0.02),
        (wt2, 0.04),
        (wt2, h - 0.04),
        (hw2, h - 0.02),
        (hw2, h),
        (0, h)
    ]

def create_rail_mesh(location_x, name):
    profile = create_rail_profile()
    verts = []
    for (px, pz) in profile:
        verts.append((px, -SEGMENT_LENGTH, pz))
    for (px, pz) in reversed(profile[:-1]):
        verts.append((-px, -SEGMENT_LENGTH, pz))

    mesh = bpy.data.meshes.new(name + "_mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    faces = [tuple(range(len(verts)))]
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.extrude_region_move(TRANSFORM_OT_translate={"value": (0, SEGMENT_LENGTH, 0)})
    bpy.ops.object.mode_set(mode='OBJECT')

    obj.location.x = location_x
    obj.data.materials.append(mat_rail)
    return obj

# ------------------------------------------------------------
# COSTRUZIONE GEOMETRIA
# ------------------------------------------------------------
rail_left = create_rail_mesh(-GAUGE_HALF, "Rail_Left")
rail_right = create_rail_mesh(GAUGE_HALF, "Rail_Right")

# Traversina
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -SEGMENT_LENGTH/2, -SLEEPER_THICKNESS/2))
sleeper = bpy.context.active_object
sleeper.name = "Sleeper"
sleeper.scale = (SLEEPER_LENGTH, SLEEPER_WIDTH, SLEEPER_THICKNESS)
sleeper.data.materials.append(mat_sleeper)

# Massicciata
ballast_z = -SLEEPER_THICKNESS - BALLAST_DEPTH/2
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -SEGMENT_LENGTH/2, ballast_z))
ballast = bpy.context.active_object
ballast.name = "Ballast"
ballast.scale = (BALLAST_WIDTH, SEGMENT_LENGTH, BALLAST_DEPTH)
ballast.data.materials.append(mat_ballast)

# ------------------------------------------------------------
# UNISCI TUTTO
# ------------------------------------------------------------
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = ballast
bpy.ops.object.join()
final_obj = bpy.context.active_object
final_obj.name = "RailSegment"

# Sposta l'origine all'inizio del segmento
final_obj.location.y += SEGMENT_LENGTH

# Applica tutte le trasformazioni
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ------------------------------------------------------------
# ESPORTAZIONE
# ------------------------------------------------------------
output_dir = "C:/Users/gabry/Documents/Godot Projects/DipRail/Assets/Models/Tracks/"
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "rail_segment.glb")

bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format='GLB',
    use_selection=True,
    export_materials='EXPORT',
    export_apply=True
)
print(f"Segmento esportato con successo in: {output_path}")