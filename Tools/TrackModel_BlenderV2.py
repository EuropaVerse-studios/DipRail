import bpy
import bmesh
import math
import os
from mathutils import Matrix

# ==========================================
# 1. CONFIGURAZIONE
# ==========================================
RAIL_TYPE = "UIC60"
SEGMENT_LENGTH = 1.0
SLEEPER_COUNT = 1       # Ora è 1 traversa al centro del metro!
SLEEPER_TYPE = "wood"
GAUGE = 1.435
EXPORT_PATH = "//RailSegment.glb"

# ==========================================
# 2. DIMENSIONI
# ==========================================
RAIL_DIMS = {
    "UIC60": {"h": 0.172, "w_foot": 0.150, "w_head": 0.072, "web_th": 0.0165, "h_head": 0.051, "h_foot": 0.022}
}
SLEEPER_DIMS = {
    "wood": {"L": 2.50, "W": 0.30, "H": 0.20, "dep": 0.015},
    "concrete": {"L": 2.60, "W": 0.30, "H": 0.234, "dep": 0.030}
}
BALLAST_DIMS = {"w_top": 2.30, "w_bot": 3.00, "h": 0.35}
ROADBED_DIMS = {"w_top": 3.00, "w_bot": 4.50, "h": 0.40}

# ==========================================
# 3. FUNZIONI AUSILIARIE
# ==========================================
def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

def create_material(name, base_color, metallic, roughness):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
    return mat

# ==========================================
# 4. GEOMETRIA ROTAIA CON DOPPIO MATERIALE
# ==========================================
def create_rail_profile_parts(rail_type):
    dims = RAIL_DIMS.get(rail_type, RAIL_DIMS["UIC60"])
    h, w_foot, w_head, web_th, h_head, h_foot = dims.values()
    z_neck = h - h_head
    z_head_base = z_neck
    
    # Profilo del corpo e base (anima + piede)
    body_profile = [
        (-w_foot/2, 0.0), (w_foot/2, 0.0), (w_foot/2, h_foot),
        (web_th/2, h_foot), (web_th/2, z_head_base), (w_head/2, z_head_base),
        (-w_head/2, z_head_base), (-web_th/2, z_head_base),
        (-web_th/2, h_foot), (-w_foot/2, h_foot)
    ]
    # Profilo della testa (parte alta argentata)
    head_profile = [
        (w_head/2, z_head_base), (w_head/2, h),
        (-w_head/2, h), (-w_head/2, z_head_base)
    ]
    return body_profile, head_profile

def create_rail_mesh(x_offset, z_offset, rail_type, inclination_angle, length, mat_body, mat_head):
    body_prof, head_prof = create_rail_profile_parts(rail_type)
    bm = bmesh.new()
    
    # Crea i vertici del corpo e della testa
    body_verts = [bm.verts.new((x, 0.0, z)) for x, z in body_prof]
    head_verts = [bm.verts.new((x, 0.0, z)) for x, z in head_prof]
    bm.verts.ensure_lookup_table()
    
    # Crea le due facce distinte e assegna i materiali
    face_body = bm.faces.new(body_verts)
    face_head = bm.faces.new(head_verts)
    face_body.material_index = 0 # Corpo scuro
    face_head.material_index = 1 # Testa argentata
    bm.faces.ensure_lookup_table()
    
    # Estudi entrambe le facce lungo Y
    ret_body = bmesh.ops.extrude_face_region(bm, geom=[face_body])
    ret_head = bmesh.ops.extrude_face_region(bm, geom=[face_head])
    
    new_verts = [v for v in ret_body["geom"] + ret_head["geom"] if isinstance(v, bmesh.types.BMVert)]
    for v in new_verts:
        v.co.y += length
        
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    
    # Crea la mesh
    mesh = bpy.data.meshes.new(f"Rail_{rail_type}")
    bm.to_mesh(mesh)
    bm.free()
    
    # Assegna i materiali alla mesh (in ordine: 0=Corpo, 1=Testa)
    mesh.materials.append(mat_body)
    mesh.materials.append(mat_head)
    
    obj = bpy.data.objects.new(f"Rail_{rail_type}", mesh)
    bpy.context.collection.objects.link(obj)
    
    rot = Matrix.Rotation(inclination_angle, 4, 'Y')
    trans = Matrix.Translation((x_offset, -length/2, z_offset))
    obj.matrix_world = trans @ rot
    return obj

# ==========================================
# 5. GEOMETRIA TRAVERSA, MASSICCIATA E TERRA
# ==========================================
def create_sleeper_mesh(sleeper_type, y_pos, z_pos):
    dims = SLEEPER_DIMS[sleeper_type]
    L, W, H, dep = dims.values()
    bm = bmesh.new()
    v0 = bm.verts.new((-L/2, -W/2, 0)); v1 = bm.verts.new((L/2, -W/2, 0))
    v2 = bm.verts.new((L/2, W/2, 0));    v3 = bm.verts.new((-L/2, W/2, 0))
    v4 = bm.verts.new((-L/2, -W/2, H)); v5 = bm.verts.new((L/2, -W/2, H))
    v6 = bm.verts.new((L/2, W/2, H));    v7 = bm.verts.new((-L/2, W/2, H))
    bm.faces.new((v0, v1, v2, v3)); bm.faces.new((v4, v5, v6, v7))
    bm.faces.new((v0, v1, v5, v4)); bm.faces.new((v2, v3, v7, v6))
    bm.faces.new((v0, v3, v7, v4)); bm.faces.new((v1, v2, v6, v5))
    for v in [v4, v5, v6, v7]:
        x = v.co.x
        z_offset = dep * (1 - (x / (L/2))**2)
        v.co.z = H - z_offset
    mesh = bpy.data.meshes.new(f"Sleeper_{sleeper_type}")
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(f"Sleeper_{sleeper_type}", mesh)
    bpy.context.collection.objects.link(obj)
    obj.location.y = y_pos; obj.location.z = z_pos
    return obj

def create_ballast_mesh(length, z_pos):
    w_top, w_bot, h = BALLAST_DIMS.values()
    bm = bmesh.new(); y0, y1 = -length/2, length/2
    v0 = bm.verts.new((-w_bot/2, y0, 0)); v1 = bm.verts.new((w_bot/2, y0, 0))
    v2 = bm.verts.new((w_top/2, y0, h));  v3 = bm.verts.new((-w_top/2, y0, h))
    v4 = bm.verts.new((-w_bot/2, y1, 0)); v5 = bm.verts.new((w_bot/2, y1, 0))
    v6 = bm.verts.new((w_top/2, y1, h));  v7 = bm.verts.new((-w_top/2, y1, h))
    bm.faces.new((v0, v1, v2, v3)); bm.faces.new((v4, v5, v6, v7))
    bm.faces.new((v0, v1, v5, v4)); bm.faces.new((v3, v2, v6, v7))
    bm.faces.new((v0, v3, v7, v4)); bm.faces.new((v1, v2, v6, v5))
    mesh = bpy.data.meshes.new("Ballast"); bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new("Ballast", mesh); bpy.context.collection.objects.link(obj)
    obj.location.z = z_pos; return obj

def create_roadbed_mesh(length):
    w_top, w_bot, h = ROADBED_DIMS.values()
    bm = bmesh.new(); y0, y1 = -length/2, length/2
    v0 = bm.verts.new((-w_bot/2, y0, 0)); v1 = bm.verts.new((w_bot/2, y0, 0))
    v2 = bm.verts.new((w_top/2, y0, h));  v3 = bm.verts.new((-w_top/2, y0, h))
    v4 = bm.verts.new((-w_bot/2, y1, 0)); v5 = bm.verts.new((w_bot/2, y1, 0))
    v6 = bm.verts.new((w_top/2, y1, h));  v7 = bm.verts.new((-w_top/2, y1, h))
    bm.faces.new((v0, v1, v2, v3)); bm.faces.new((v4, v5, v6, v7))
    bm.faces.new((v0, v1, v5, v4)); bm.faces.new((v3, v2, v6, v7))
    bm.faces.new((v0, v3, v7, v4)); bm.faces.new((v1, v2, v6, v5))
    mesh = bpy.data.meshes.new("Roadbed"); bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new("Roadbed", mesh); bpy.context.collection.objects.link(obj)
    return obj

def join_objects(objects):
    for obj in bpy.data.objects: obj.select_set(False)
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    return bpy.context.view_layer.objects.active

def export_glb(path, obj):
    for o in bpy.data.objects: o.select_set(False)
    obj.select_set(True); bpy.context.view_layer.objects.active = obj
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True)

# ==========================================
# 6. ESECUZIONE PRINCIPALE
# ==========================================
def main():
    clear_scene()
    
    # Nuovo materiale per il corpo della rotaia e per la testa argentata
    mat_rail_body = create_material("Rail_Body", (0.2, 0.2, 0.2, 1.0), 1.0, 0.55)
    mat_rail_head = create_material("Rail_Head", (0.7, 0.7, 0.75, 1.0), 1.0, 0.25) # Argentato lucido
    mat_sleeper = create_material("Sleeper_Wood", (0.3, 0.15, 0.05, 1.0), 0.0, 0.95) if SLEEPER_TYPE=="wood" else create_material("Sleeper_Concrete", (0.6, 0.6, 0.6, 1.0), 0.0, 0.85)
    mat_ballast = create_material("Ballast", (0.5, 0.45, 0.4, 1.0), 0.0, 1.0)
    mat_earth = create_material("Earth", (0.45, 0.3, 0.15, 1.0), 0.0, 1.0)

    inclination = math.atan(1/20)
    roadbed_h, ballast_h, sleeper_h = ROADBED_DIMS["h"], BALLAST_DIMS["h"], SLEEPER_DIMS[SLEEPER_TYPE]["H"]
    z_ballast, z_sleeper, z_rail = roadbed_h, roadbed_h + ballast_h, roadbed_h + ballast_h + sleeper_h

    roadbed = create_roadbed_mesh(SEGMENT_LENGTH); roadbed.data.materials.append(mat_earth)
    ballast = create_ballast_mesh(SEGMENT_LENGTH, z_ballast); ballast.data.materials.append(mat_ballast)

    sleepers = []
    spacing = SEGMENT_LENGTH / (SLEEPER_COUNT + 1)
    for i in range(SLEEPER_COUNT):
        y_pos = -SEGMENT_LENGTH/2 + spacing * (i + 1)
        sleeper = create_sleeper_mesh(SLEEPER_TYPE, y_pos, z_sleeper)
        sleeper.data.materials.append(mat_sleeper); sleepers.append(sleeper)

    # Crea le rotaie passando anche il materiale del corpo e della testa
    left_rail = create_rail_mesh(-GAUGE/2, z_rail, RAIL_TYPE, inclination, SEGMENT_LENGTH, mat_rail_body, mat_rail_head)
    right_rail = create_rail_mesh(GAUGE/2, z_rail, RAIL_TYPE, -inclination, SEGMENT_LENGTH, mat_rail_body, mat_rail_head)

    joined_obj = join_objects([roadbed, ballast] + sleepers + [left_rail, right_rail])
    joined_obj.name = "rail_segment"
    export_glb(bpy.path.abspath(EXPORT_PATH), joined_obj)
    print("✅ Modello V8 generato (1 traversa, rotaia a 2 strati)!")

if __name__ == "__main__":
    main()