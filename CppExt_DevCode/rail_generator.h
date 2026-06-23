#ifndef RAIL_GENERATOR_H
#define RAIL_GENERATOR_H

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class RailGenerator : public Node3D {
    GDCLASS(RailGenerator, Node3D)

protected:
    static void _bind_methods();

public:
    RailGenerator();
    ~RailGenerator();

    void _ready() override;

    // Metodi esposti a GDScript
    Ref<ArrayMesh> generate_rail_mesh(PackedVector3Array points, float rail_height, float gauge_half_width);
    Ref<MultiMesh> generate_sleeper_multimesh(PackedVector3Array points, float spacing, float length, float width, float thickness);
    Ref<ArrayMesh> generate_ballast_mesh(PackedVector3Array points, float ballast_width, float ballast_depth);
};

} // namespace godot

#endif // RAIL_GENERATOR_H