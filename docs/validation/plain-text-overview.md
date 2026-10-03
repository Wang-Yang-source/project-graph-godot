# Plain text overview

Ordinary text nodes now retain their title in overview without a thumbnail fill or border, including inferred graph branches and immediate child titles. Only real spatial containers (`_container_active`) receive a group frame. Text contrast follows the canvas when its original fill is omitted. The existing native Panel, Label and StyleBox APIs provide the behavior; this presentation rule needs no new library.

Authorized GPU regression: `tests/plain_text_overview_smoke.gd` checks plain root and leaf titles, actual group borders, saved document stability and zoom-in restoration. Camera animation is disabled in this test so the requested zoom is reproducible. Screenshot: `/tmp/pg-plain-text-overview.png`.

Manual verification remains: restart the app and zoom out around “文本节点”. Ordinary text titles must have no miniature rectangle or fill; actual group frames must remain. Zoom in and verify original text styling and connections return. On failure, check whether the node really owns a spatial group or is only a graph branch.

Godot project files and validation are handled through MCP script read/modify/create and editor-script execution, using the user's existing test authorization.
