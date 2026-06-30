# Godot Mouse Passthrough Demo (Godot 4.7) by Kalgator

A single **transparent, borderless, always-on-top** window that covers the whole screen, with
**real `Window` nodes embedded as floating boxes**. Clicking a **gap** between boxes goes
**through to the desktop / other apps**; clicking a box interacts with it. Boxes are draggable and
can be moved across monitors.

This is the core trick for a "desktop overlay" / "desktop pet" app where each panel is part of
**one** application window (so e.g. the Steam overlay shows once, not per window).

## Run

Important: The “Embed game in editor” option must be disabled in the Debug settings. If enabled, the passthrough window will not function as intended.

Open the project in Godot 4.7 and press **F5** (main scene is `embed_test.tscn`).

- **Drag** a window by its title bar (across monitors too).
- **Click a gap** between windows → it reaches the desktop / the app behind.
- Control panel: buttons **show/hide** each window. Each window's **X** closes it.
- Click on Information windows and: **F8** = toggle the passthrough system. **ESC** = quit.

## How it works

1. **Transparent full-screen window.** Project setting
   `display/window/per_pixel_transparency/allowed = true`, plus at runtime: `transparent_bg`,
   `borderless`, `always_on_top`, content scaling disabled (1 unit = 1 pixel), and the window
   sized to the monitor (or the bounding box of all monitors for multi-monitor).

2. **Embedded windows.** `get_viewport().gui_embed_subwindows = true` draws `Window` nodes
   *inside* the main window as movable boxes instead of separate OS windows.

3. **Mouse passthrough region.** Each frame we build a polygon = the union of the visible boxes'
   rects and call `DisplayServer.window_set_mouse_passthrough(region)`. Inside the region the
   window is visible & clickable; outside, the click passes through to the desktop.

### The gotchas (Windows)

`window_set_mouse_passthrough` uses `SetWindowRgn`, which:

- **Clips both input AND rendering** to the region. So anything outside the region isn't just
  click-through, it's **not drawn**. That's why the region must contain the boxes (and not be
  a tiny degenerate shape).
- Accepts **only ONE polygon** and fills it with the **even-odd** rule. So in `region_util.gd`:
  - overlapping rects are **unioned** (`Geometry2D.merge_polygons`) to avoid even-odd holes,
  - disjoint groups are joined with **zero-width bridges** into a single polygon.

### Multi-monitor

`SPAN_ALL_MONITORS = true` makes the window cover the bounding box of all monitors. On setups
with **mismatched resolutions/DPI**, that rectangle has **dead zones** (areas with no real
monitor). A **per-monitor clamp** keeps each box inside the monitor under its center, so boxes
don't get lost in the dead zones. The box being dragged is left free (and snaps to its monitor
on release). Set `SPAN_ALL_MONITORS = false` for a single (primary) monitor, which is simplest.

## Files

- `embed_test.gd` / `embed_test.tscn` — the demo.
- `region_util.gd` — reusable `PassthroughRegion` helper (`build` / `apply` / `apply_full` /
  `apply_none`). Drop it into any project.

## License
This project is licensed under CC BY 4.0.

If you use this project, you must include the following credit:
**Window Passthrough System by Kalgator — https://kalgator.com**
