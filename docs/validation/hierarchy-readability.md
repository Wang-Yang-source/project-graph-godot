# Hierarchy readability

The 2 physical pixel glyph culling threshold is a rendering optimization, not a readability threshold. Groups now enter overview when an immediate child title falls below 12 physical screen pixels, independently of the whole group's footprint. Existing topology, suppression and cached zoom intervals are reused; native Label/Panel font metrics and transforms provide the measurements. No external library or dependency is needed for this project-specific rule.

Overview title font size is capped at 24 physical pixels and parent titles sit at the top of the frame, reserving its body for immediate child titles. Small leaf previews receive a minimum 48 × 24 pixel display rectangle; saved bounds remain untouched. Deeper raw objects remain suppressed.

Validation: `tests/hierarchy_readability_smoke.gd` covers the 13→11 pixel transition in a wide frame, next-layer title visibility, deeper-content suppression, maximum font size, document stability and zoom-in restoration. GPU screenshot: `/tmp/pg-hierarchy-readability.png`. Also run the existing text-detail and navigation-cache regressions. Compare unrelated existing preview-test failures against the original working tree.

Manual validation still required: restart the app, open the diagram from the reported screenshot, clear the selection and gradually zoom out. Once inner text becomes small, immediate next-layer titles should remain legible; giant parent digits and deeper raw nodes should not appear together. Zoom back in and confirm the original nodes and links return. If this fails, check which group is selected or being edited, whether inferred hierarchy matches the diagram, and whether sibling summaries overlap. Repeat at the user's display scaling and during continuous wheel/pinch zoom.

Godot files are handled through MCP script read/modify/create and editor-script execution; validation is launched through MCP under the user's existing authorization.
