# DipRail – Open Source Realistic Railway Simulator

**DipRail** is a realistic, moddable railway simulator built on **Godot 4.7 .Net**.
It aims to provide high-fidelity train physics, procedural track generation,
a complete signaling system, and an open ecosystem for modders.

> 🚧 **Current status**: Pre‑Alpha – core track generation, basic train physics, and
> camera system are working. See [Roadmap](#-roadmap) for upcoming features.

## ✨ Key Features

- **Realistic track generation** – Tracks are defined by JSON files (straight, curves, easements, grades, tunnels) and rendered with high‑detail 3D models.
- **Train physics** – Adhesion, tractive effort, braking, and speed limits.
- **3D cockpit & external cameras** – Switchable views with orbit and cab cameras.
- **Modding ready** – Custom trains, routes, and signals via JSON and `.glb` models.
- **Performance** – MultiMesh rendering for tracks, GDScript for logic, optional C++/Rust via GDExtension for heavy computations.
- **Cross-platform** – Windows first, Linux and Steam Deck planned.

## 🎮 Quick Start

1. Install [Godot 4.7](https://godotengine.org/) (.NET version not required).
2. Clone this repository.
3. Open `project.godot` in Godot.
4. Run the `Main.tscn` scene.
5. Press **W/S** to accelerate/brake, **Right Mouse** to rotate camera, **C** to switch to cab view.

## 🧱 Project Structure

here you can see the approximated structure of the project.
Please mind that all asset related content is not present here because of repository weight optimization and .gitignore. If you want them, you can email me

    DipRail/
    ├── Assets/            # 3D models, textures, sounds
    │   └── Models/Tracks/ # rail_segment.glb (Blender‑generated)
    ├── Data/
    │   └── Tracks/        # JSON track definition files
    ├── Materials/         # Godot material files (.tres)
    ├── Scenes/            # Godot scenes (Main.tscn, PlayerTrain.tscn)
    ├── Scripts/           # GDScripts (core logic)
    │   ├── track_builder.gd
    │   ├── train_controller.gd
    │   ├── orbit_camera.gd
    │   └── ...
    ├── Tools/             # Blender Python script, build tools
    └── README.md

## 📝 Code Comments

Most code comments are in **Italian**, as the project was started by an Italian
developer ([EuropaVerse Studios](https://github.com/EuropaVerse)).
We welcome translations and English contributions – see [Contributing](#-contributing).

## 🛤️ Track Format

Tracks are defined by JSON files with a list of segments. Example:

    {
      "start": { "x": 0, "y": 0.6, "z": 0 },
      "startDirection": 0,
      "segments": [
        { "type": "straight", "length": 200 },
        { "type": "easement", "length": 80, "radiusStart": 0, "radiusEnd": 1200 },
        { "type": "curve", "radius": 1200, "angle": 30 },
        { "type": "easement", "length": 80, "radiusStart": 1200, "radiusEnd": 0 },
        { "type": "straight", "length": 300, "grade": 0.5 }
      ]
    }

See Data/Tracks/test_line.json for a full example and RAILTRACK_FORMAT.md
for the complete specification.

## 🚂 Modding
- Trains: JSON files in Data/ define power, mass, braking, etc.

- Routes: JSON track files as described above.

- 3D Models: any .glb model can be used for tracks or trains.

- Scripts: GDScript files can be added to extend behaviour (signals, AI).

## 🗺️ Roadmap
- Procedural track generation (JSON‑based)

- Basic train physics and controls

- Orbit and cab cameras

- 3D track model generated via Blender

- Signaling system

- Multiplayer (via EOS)

- Weather and day/night cycle

- Steam Deck support

- Visual track editor

## 📜 License
DipRail is licensed under the GNU General Public License v3.0.
See LICENSE for the full text.

Game assets (models, textures, sounds) may be distributed under separate terms.

## 🤝 Contributing
Contributions are welcome! Please read CONTRIBUTING.md for
guidelines on code style, testing, and pull requests.

## 👤 Credits
EuropaVerse Studios – creator and main developer.

Special thanks to the Godot Engine, Open Rails and Libre TrainSim communities.

## 📧 Contact
GitHub Issues: https://github.com/EuropaVerse/DipRail/issues

Email: europaverse.studios@gmail.com