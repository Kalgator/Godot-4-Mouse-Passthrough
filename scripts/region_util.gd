class_name PassthroughRegion
extends RefCounted
# Reusable helper: builds and applies the mouse-passthrough region from a list of rectangles
# (the visible boxes/windows). The region is what is VISIBLE and CLICKABLE; everything else lets
# the click go through to the desktop.
#
# NOTE (Windows): window_set_mouse_passthrough uses SetWindowRgn → it clips BOTH the input AND
# what is painted, and fills with the EVEN-ODD rule. Therefore:
#   - the rects are geometrically UNIONED (Geometry2D.merge_polygons) so overlaps don't leave
#     holes,
#   - disjoint groups are joined with zero-width BRIDGES into a single polygon (only one polygon
#     is allowed by window_set_mouse_passthrough).


# Apply the region to the window (id 0 by default). Empty rects → degenerate region (all passes through).
static func apply(rects: Array, window_id: int = 0) -> void:
	DisplayServer.window_set_mouse_passthrough(build(rects), window_id)


# Interactive region = whole window (no clipping, no passthrough). For dragging / Steam overlay.
static func apply_full(size: Vector2i, window_id: int = 0) -> void:
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]), window_id)


# Disable passthrough: the window captures EVERYTHING (no clipping).
static func apply_none(window_id: int = 0) -> void:
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), window_id)


static func build(rects: Array) -> PackedVector2Array:
	var polys: Array = []
	for r in rects:
		if r is Rect2 and r.size.x > 0.0 and r.size.y > 0.0:
			polys.append(PackedVector2Array([
				r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	if polys.is_empty():
		return PackedVector2Array([Vector2.ZERO, Vector2(2, 0), Vector2(0, 2)])

	# Union overlapping rects (merge_polygons does the real boolean union).
	var groups: Array = []
	for p in polys:
		var cur: PackedVector2Array = p
		var i := 0
		while i < groups.size():
			var merged := Geometry2D.merge_polygons(groups[i], cur)
			var outers: Array = []
			for q in merged:
				if not Geometry2D.is_polygon_clockwise(q):  # drop holes (clockwise)
					outers.append(q)
			if outers.size() <= 1:
				# They overlapped/touched → one outline left: merge and restart.
				if outers.size() == 1:
					cur = outers[0]
				groups.remove_at(i)
				i = 0
			else:
				i += 1   # disjoint: keep the group and move on
		groups.append(cur)

	# Connect disjoint groups into one polygon with zero-width bridges to the anchor.
	var anchor: Vector2 = groups[0][0]
	var out := PackedVector2Array()
	for g in groups:
		out.append(anchor)
		for v in g:
			out.append(v)
		out.append(g[0])
		out.append(anchor)
	return out
