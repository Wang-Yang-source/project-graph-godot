# Overview content invalidation

Native group previews now react to local content events and changed member poses. A world translation updates the existing sprite's placement without rebuilding every group's content arrays. The existing full content comparison remains the fallback for relative member movement, shape/content edits, theme/size changes, resolution changes and topology changes.

`StageObject.persistent_content_changed` distinguishes actual property setters from transform persistence. Existing setters emit it through `notify_persistent_change()`; transform notifications pass `false`. Overview watchers also observe native text controls' theme and resize signals. Hidden edge setters therefore invalidate their preview even when the edge's own process is stopped.

Geometry notifications are checked at overview process priority 50, after the mover publishes follower poses at priority -10. Root placement changes require matching notifications from every entity member. Ownership alone never proves rigid translation. Compared poses retain their original snapshot anchor; translation tolerance is limited to 0.004 world units and 0.01 cached texture pixels, and is available only for the root or members sharing its translation driver. Independent member movement is compared exactly.

Regression entry: `res://tests/overview_content_events_smoke.gd`. It asserts that root-first and member-first fractional translation cause zero additional full content walks/member reads, retain the original cache anchor, and preserve an unrelated preview. Relative movement, text edits, stopped hidden-edge properties and endpoint changes, direct text-theme changes, root-only movement and reparenting must refresh affected previews. Existing translation and physics-gate regression entries remain relevant.

Manual validation:

1. Open `tutorial-shortcut-keys-3.1.prg`, zoom until a group's overview title appears, and drag the group. Its existing preview should follow the group without flicker or temporary stale placement.
2. Edit a member's text/font, an internal edge's arrow/endpoint, or move a member after expansion, then return to overview. The preview must reflect the change; unrelated groups should retain their previews.
3. Repeat with a nested group, undo/redo and reopening the document. Check for stale pixels, missing content changes, incorrect ownership after reparenting, or gradual relative drift.

The diagnostic counters count full content walks and member reads. Geometry notifications still require lightweight checks for changed members. This change does not establish a stable 60 FPS frame budget.

Logical parent changes also call the existing topology notification: changing `TextNode.topic_parent` increments stage topology/layout revisions and rebuilds preview ownership. The regression changes an existing member's logical parent and checks both the new preview parent and refreshed image. Manually change a node's logical parent, then check the collapsed group's membership and title/content composition; stale ownership after undo/redo indicates a topology invalidation failure.
