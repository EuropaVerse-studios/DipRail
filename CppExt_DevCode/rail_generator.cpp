#include "rail_generator.h"

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/surface_tool.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

// --------------------------------------------------------------
// Utility: calcola un sistema di riferimento ortogonale a partire
// dalla tangente, gestendo il caso in cui sia parallela a (0,1,0)
// --------------------------------------------------------------
static Basis get_basis_from_tangent(const Vector3 &tangent) {
    Vector3 t = tangent.normalized();
    Vector3 up = Vector3(0, 1, 0);
    if (Math::abs(t.dot(up)) > 0.99f) {
        up = Vector3(1, 0, 0);
    }
    Vector3 right = t.cross(up).normalized();
    Vector3 local_up = right.cross(t).normalized();
    return Basis(right, local_up, t); 
}

static Vector3 get_tangent_at(const PackedVector3Array &points, int64_t i) {
    if (points.size() < 2) return Vector3(0, 0, 1);
    if (i == 0) return (points[1] - points[0]).normalized();
    if (i == points.size() - 1) return (points[i] - points[i - 1]).normalized();
    return (points[i + 1] - points[i - 1]).normalized();
}

// ==================== BINDING ====================
RailGenerator::RailGenerator() {}
RailGenerator::~RailGenerator() {}

void RailGenerator::_ready() {}

void RailGenerator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("generate_rail_mesh", "points", "rail_height", "gauge_half_width"), &RailGenerator::generate_rail_mesh);
    ClassDB::bind_method(D_METHOD("generate_sleeper_multimesh", "points", "spacing", "length", "width", "thickness"), &RailGenerator::generate_sleeper_multimesh);
    ClassDB::bind_method(D_METHOD("generate_ballast_mesh", "points", "ballast_width", "ballast_depth"), &RailGenerator::generate_ballast_mesh);
}

// ==================== ROTAIE ====================
Ref<ArrayMesh> RailGenerator::generate_rail_mesh(PackedVector3Array points, float rail_height, float gauge_half_width) {
    Ref<SurfaceTool> st = memnew(SurfaceTool);
    st->begin(Mesh::PRIMITIVE_TRIANGLES);

    if (points.size() < 2) {
        st->generate_normals();
        return st->commit();
    }

    struct Vec2 { float x, y; };
    Vec2 profile[] = {
        {-0.035f, 0.15f}, {-0.035f, 0.12f}, {-0.02f, 0.05f}, {-0.07f, 0.05f},
        {-0.07f, 0.0f},    {0.07f, 0.0f},    {0.07f, 0.05f},  {0.02f, 0.05f},
        {0.035f, 0.12f},   {0.035f, 0.15f}
    };
    const int profile_count = 10;

    Vector<Vector3> left_ring_prev, right_ring_prev;
    bool first_ring = true;

    for (int64_t i = 0; i < points.size(); ++i) {
        Vector3 p = points[i];
        Vector3 tangent = get_tangent_at(points, i);
        Basis basis = get_basis_from_tangent(tangent);
        Vector3 right = basis.get_column(0);
        Vector3 up = basis.get_column(1);

        Vector<Vector3> left_ring, right_ring;
        for (int j = 0; j < profile_count; ++j) {
            Vector3 offset = right * (profile[j].x - gauge_half_width) + up * profile[j].y;
            left_ring.push_back(p + offset);
            offset = right * (profile[j].x + gauge_half_width) + up * profile[j].y;
            right_ring.push_back(p + offset);
        }

        if (!first_ring) {
            for (int j = 0; j < profile_count; ++j) {
                int next = (j + 1) % profile_count;
                
                // CORREZIONE WINDING ORDER: Rotaia Sinistra
                // Se y=0, è la base inferiore (Normale deve puntare in basso -Y)
                // Altrimenti è la faccia laterale (Normale deve puntare a sinistra -X)
                if (profile[j].y == 0.0f && profile[next].y == 0.0f) {
                    // Base sinistra (Normale -Y)
                    st->add_vertex(left_ring_prev[j]);
                    st->add_vertex(left_ring_prev[next]);
                    st->add_vertex(left_ring[next]);
                    
                    st->add_vertex(left_ring_prev[j]);
                    st->add_vertex(left_ring[next]);
                    st->add_vertex(left_ring[j]);
                } else {
                    // Lato sinistro (Normale -X)
                    st->add_vertex(left_ring_prev[j]);
                    st->add_vertex(left_ring_prev[next]);
                    st->add_vertex(left_ring[next]);
                    
                    st->add_vertex(left_ring_prev[j]);
                    st->add_vertex(left_ring[next]);
                    st->add_vertex(left_ring[j]);
                }

                // CORREZIONE WINDING ORDER: Rotaia Destra
                if (profile[j].y == 0.0f && profile[next].y == 0.0f) {
                    // Base destra (Normale -Y) - Stesso ordine della sinistra
                    st->add_vertex(right_ring_prev[j]);
                    st->add_vertex(right_ring_prev[next]);
                    st->add_vertex(right_ring[next]);
                    
                    st->add_vertex(right_ring_prev[j]);
                    st->add_vertex(right_ring[next]);
                    st->add_vertex(right_ring[j]);
                } else {
                    // Lato destro (Normale +X)
                    st->add_vertex(right_ring_prev[j]);
                    st->add_vertex(right_ring[next]); 
                    st->add_vertex(right_ring_prev[next]); // A->D->B
                    
                    st->add_vertex(right_ring_prev[j]);
                    st->add_vertex(right_ring[next]);
                    st->add_vertex(right_ring[j]);         // A->D->C
                }
            }
        }

        left_ring_prev = left_ring;
        right_ring_prev = right_ring;
        first_ring = false;
    }

    st->generate_normals();
    return st->commit();
}

// ==================== TRAVERSINE ====================
Ref<MultiMesh> RailGenerator::generate_sleeper_multimesh(PackedVector3Array points, float spacing, float length, float width, float thickness) {
    if (points.size() < 2) return Ref<MultiMesh>();

    Ref<BoxMesh> box_mesh = memnew(BoxMesh);
    box_mesh->set_size(Vector3(length, thickness, width));

    Ref<MultiMesh> mm = memnew(MultiMesh);
    mm->set_mesh(box_mesh);
    mm->set_transform_format(MultiMesh::TRANSFORM_3D);

    float total_length = 0.0;
    for (int64_t i = 1; i < points.size(); ++i)
        total_length += (points[i] - points[i - 1]).length();

    if (total_length <= 0.0) return Ref<MultiMesh>();

    int count = Math::floor(total_length / spacing) + 1;
    if (count < 1) count = 1;
    mm->set_instance_count(count);

    for (int i = 0; i < count; ++i) {
        float dist = spacing * 0.5f + i * spacing;
        if (dist > total_length) dist = total_length;

        float accumulated = 0.0;
        Vector3 pos;
        Vector3 tangent;
        bool found = false;
        for (int64_t j = 1; j < points.size(); ++j) {
            float seg_len = (points[j] - points[j - 1]).length();
            if (accumulated + seg_len >= dist) {
                float t = (dist - accumulated) / seg_len;
                pos = points[j - 1].lerp(points[j], t);
                tangent = (points[j] - points[j - 1]).normalized();
                found = true;
                break;
            }
            accumulated += seg_len;
        }
        if (!found) {
            pos = points[points.size() - 1];
            tangent = (points[points.size()-1] - points[points.size()-2]).normalized();
        }

        Vector3 up_global = Vector3(0, 1, 0);
        Vector3 tangent_h = tangent;
        tangent_h.y = 0;
        if (tangent_h.length() < 0.001f) tangent_h = Vector3(0, 0, 1);
        tangent_h.normalize();

        Vector3 right = tangent_h.cross(up_global).normalized();
        if (right.length() < 0.001f) right = Vector3(1, 0, 0);
        Vector3 forward = right.cross(up_global).normalized();

        Basis local_basis(right, up_global, forward);

        // CORREZIONE: Offset di 0.01f verso il basso per eliminare lo Z-Fighting con la base della rotaia
        float z_fight_fix = 0.01f;
        Vector3 final_pos = pos - up_global * (thickness * 0.5f + z_fight_fix);

        Transform3D t(local_basis, final_pos);
        mm->set_instance_transform(i, t);
    }

    return mm;
}

// ==================== MASSICCIATA ====================
Ref<ArrayMesh> RailGenerator::generate_ballast_mesh(PackedVector3Array points, float ballast_width, float ballast_depth) {
    Ref<SurfaceTool> st = memnew(SurfaceTool);
    st->begin(Mesh::PRIMITIVE_TRIANGLES);

    if (points.size() < 2) {
        st->generate_normals();
        return st->commit();
    }

    float half_width = ballast_width * 0.5f;
    // Nota: Ora la traversina finisce a 0.15f (il suo spessore). 
    // Impostiamo la massicciata a -0.15f così tocca perfettamente il fondo della traversina.
    float y_offset = -0.15f; 

    Vector3 left_prev, right_prev, left_bottom_prev, right_bottom_prev;
    bool first = true;

    for (int64_t i = 0; i < points.size(); ++i) {
        Vector3 p = points[i];
        Vector3 tangent = get_tangent_at(points, i);
        Basis basis = get_basis_from_tangent(tangent);
        Vector3 right = basis.get_column(0);
        Vector3 up = basis.get_column(1);

        Vector3 left = p + right * half_width + up * y_offset;
        Vector3 right_pt = p - right * half_width + up * y_offset;
        
        Vector3 left_bottom = left - up * ballast_depth;
        Vector3 right_bottom = right_pt - up * ballast_depth;

        if (!first) {
            // Faccia superiore (Normale +Y): A->D->B e A->C->D
            st->add_vertex(left_prev);
            st->add_vertex(right_pt);
            st->add_vertex(right_prev);

            st->add_vertex(left_prev);
            st->add_vertex(left);
            st->add_vertex(right_pt);

            // Fianco sinistro (Normale -X)
            st->add_vertex(left_prev);
            st->add_vertex(left);
            st->add_vertex(left_bottom);

            st->add_vertex(left_prev);
            st->add_vertex(left_bottom_prev);
            st->add_vertex(left_bottom);

            // Fianco destro (Normale +X)
            st->add_vertex(right_prev);
            st->add_vertex(right_bottom);
            st->add_vertex(right_bottom_prev);

            st->add_vertex(right_prev);
            st->add_vertex(right_bottom_prev);
            st->add_vertex(right_bottom);

            // Faccia inferiore (Normale -Y)
            st->add_vertex(left_bottom_prev);
            st->add_vertex(right_bottom_prev);
            st->add_vertex(right_bottom);

            st->add_vertex(left_bottom_prev);
            st->add_vertex(right_bottom);
            st->add_vertex(left_bottom);
        }

        left_prev = left;
        right_prev = right_pt;
        left_bottom_prev = left_bottom;
        right_bottom_prev = right_bottom;
        first = false;
    }

    st->generate_normals();
    return st->commit();
}

} // namespace godot