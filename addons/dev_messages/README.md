# KCDT Dev Messages (Godot 4)
By KCDT (Kyubii Collector Development Tools).


Install: copy `addons/dev_messages` into your project, then
Project > Project Settings > Plugins > enable "Dev Messages".

## Adding nodes
- Menu: Project > Tools > Dev Messages > Add Dev Message / Add Dev Label
  (placed 3 m in front of the editor camera; a node named DEVSETTINGS is
  created automatically if the scene has none).
- Or the normal Add Node dialog: DevMessage, DevLabel, DevSettings.

## Picking in the editor
Click a message's icon or panel in the 3D viewport to select it, then use the
Move tool (W) to drag it. A thin blue frame shows the clickable area.

## Input hints (sticks, buttons, keys, mouse)
On a DevMessage, fill the `Hints` array with DevHint resources. Each has a
glyph (Left/Right Stick, D-Pad, A/B/X/Y, bumpers, triggers, VR trigger/grip,
mouse buttons/wheel, Key with custom text, or Custom icon) and a description.

## Outline
DEVSETTINGS > Outline: border color/width around every panel. Per message,
turn off `use_settings_style` and use `custom_outline*`.

## Custom icons
Drop any .svg/.png into `custom_icon` on a message, or into DEVSETTINGS >
Icon > default_icon for the whole scene. `tint_custom_icon` recolors it.
For crisp SVGs, raise the import "Scale" in the Import dock.

## Scripting
`$DevMessage.toggle()` / `.set_open(true)` (e.g. from a VR pointer).

## Hints that follow the player's input device
On a DevHint set `action` to any InputMap action (pick from the dropdown or
type it). The glyph is looked up from that action's bindings and switches live
between keyboard/mouse and gamepad, depending on the last input the player used.
- Keyboard: key caps ("W", "Space", "Shift"...), mouse buttons.
- Gamepad: Xbox, PlayStation or Nintendo style (auto-detected from the
  controller name, or forced in DEVSETTINGS > Input Hints > gamepad_style).
- `extra_actions`: more actions shown beside the first on keyboard
  (move_left, move_back, move_right -> W A S D); on gamepad they merge into one stick.
- Preview in the editor with DEVSETTINGS > editor_preview_device.
- Force a device with DEVSETTINGS > input_device (AUTO / KEYBOARD / GAMEPAD).
Leave `action` empty to pick a glyph by hand (sticks, VR trigger/grip, etc).

## Per-note color, icon and presets
Every DevMessage owns its look (DEVSETTINGS is only the fallback):
- `preset`: 16 visual presets (Blue Cube, Green Pin, Purple Eye, Orange Gear,
  Red Warning, Cyan Crosshair, Teal Magnifier, Lavender Stopwatch, Lime Arrows,
  Pink Camera, Indigo List, Green Speaker, Sky Grid, Amber Swap, Violet Flag,
  Gray Block). Each is just a color + an SVG badge, no behaviour.
- `override_color` + `color`: your own color for that note (panel and badge).
- `custom_icon`: your own .svg/.png, beats the preset icon.
- Menu: Project > Tools > Dev Messages > Add Dev Message (preset) > ...
- DevLabel has `preset` / `override_color` / `color` too.
The preset SVGs are also in `icons/presets/` so you can edit them or reuse
them as a `custom_icon`.
