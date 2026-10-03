# Overview geometry and appearance

The previous presentation capped group width and height independently, enlarged thin frames, and used graph-subtree bounds to draw ordinary branch text. This changed the thumbnail silhouette. Group previews now use the original world rectangle directly: camera zoom supplies uniform scaling, and the center, width, height and aspect ratio remain intact. Rounded corners scale from the original native style; group fill and border colors also come from the native appearance instead of an added half-opacity treatment. Colored ordinary text uses its own original rectangle and fill color, including alpha; it never receives a translucent group-sized replacement. Existing native Control transforms and StyleBox APIs suffice; no dependency is introduced.

Authorized GPU checks in Godot 4.8 dev6 / Vulkan Mobile / Intel Iris Xe:

- `overview_group_geometry_smoke.gd`: wide and tall nested groups retain world frames through three zoom levels; original layout survives.
- `plain_text_overview_smoke.gd`: plain root and child titles receive no added group border, existing colored backgrounds remain exact, and zoom-in restores ordinary objects.
- `overview_document_appearance_smoke.gd`: the existing tutorial document is loaded read-only at three zoom levels, verifying real group frames, colored text bounds and fill opacity, and unchanged saved objects. Takes `--fixture-hex=<UTF-8 path in hexadecimal>`.
- `navigation_cache_smoke.gd`: cached navigation behavior.

Whole-document GPU screenshots: `/tmp/pg-overview-document-0.0361.png`, `/tmp/pg-overview-document-0.0542.png`, `/tmp/pg-overview-document-0.1084.png`. These validate the current local renderer; they do not claim Windows release performance improvements.

Manual verification still required: restart the application, open the reported tutorial diagram, clear selection and zoom between detail and overview. Compare the yellow “鼠标滚轮缩放视野” node: its own yellow rectangle should retain the original aspect ratio and opacity, without expanding around its graph children. Compare wide/tall real groups: their frame outlines and relative positions should remain the same as the source. Ordinary unfilled text should have no extra miniature frame. Zoom in to restore full detail. If it fails, check whether the live application loaded the changed scripts, whether the object is a real spatial container, and whether a title is hidden by overlap or active editing/selection.

Godot files use MCP script read/modify/create and editor-script execution. No document or personal preference is saved during validation.
