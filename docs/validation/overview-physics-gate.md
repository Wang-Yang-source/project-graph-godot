# Overview collision membership

The displayed overview root remains in the current Godot physics space. Entity descendants hidden by the overview leave that space, including nested containers and members arriving during progressive loading. Expanding a group or removing the overview restores their native bodies at their current world transforms. Rendering membership uses the existing `Entity.set_overview_physics_hidden` adapter and Godot's native body-space support; no duplicate collision world is introduced.

Regression entry: `res://tests/overview_physics_gate_smoke.gd`. The fixture disables camera interpolation and navigation limits so the requested low/high zoom is applied deterministically. It checks root membership, nested suppression, progressive loading, expansion, repeated collapse, and teardown. The separately tested physics session owns rigid whole-group dragging and contact response.

Manual validation:

1. Open `tutorial-shortcut-keys-3.1.prg`, zoom out until a group's overview name appears, and drag that group against a separate visible entity. The enclosing group should act as one collision body; its hidden descendants should not push each other or surrounding objects independently.
2. Zoom in until native members return. Drag a member into an unrelated entity and check that its normal collision behavior is restored at the displayed position.
3. Repeat collapse/expand, including a nested group, and reopen the document. Check for bodies that remain non-colliding after expansion, stale collision positions, or independently moving hidden children. Those indicate a membership or restoration failure.

This membership integration makes no claim that the frame budget has reached 16.7 ms.
