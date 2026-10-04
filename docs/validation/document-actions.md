# Complete-document actions

Copy, text export and outline connectivity now read GraphDocument records rather than the instantiated scene subset. Copy expands containment descendants and includes internal edges and complete Venn memberships; external references retain the existing paste behavior. Paste reuses the registry's record adapter, including lazy image blocks. Text export retains explicit-selection semantics and supports a deep traversal without recursive script calls. SVG and image export still use live geometry; automatic view virtualization is not enabled by this change.

Godot Dictionary, PackedStringArray and native scene/record adapters supply the needed traversal and serialization primitives. No general-purpose graph dependency is required for these existing application operations.

Authorized validation: graphical Godot 4.8 dev6 Compatibility run of `tests/document_actions_smoke.gd` passes. Coverage removes every scene view, compares complete text exports and components, copies a hidden child with its internal edge, verifies remapped paste endpoints and exact record counts after undo, and exports a 1,100-topic chain without constructing views. The test needs a graphical display because it exercises the system clipboard.

Manual validation: select a group with nested children, copy and paste, then undo. The copy should retain children and internal connections and undo should remove only the copy. Export the whole document as Markdown and Mermaid; distant nodes and links should appear. Open the outline and check its node/link counts. Investigate missing descendants, endpoint links referring to original nodes, changed export order, or lost content after undo. Manual application checks, image-copy failure paths and final release performance measurements have not yet been run for this change.

Godot edits and checks use `mcp__godot_mcp__` script read/write/create and editor-script execution tools. This change prepares data consumers for partial views; it does not claim faster initial loading or a new preview frame-rate measurement.
