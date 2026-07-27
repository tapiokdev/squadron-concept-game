class_name Shapes
extends RefCounted

## Geometry helpers for the vector art pass.
##
## Nothing in this game is a sprite — every ship and station is a handful
## of polygons — so the silhouettes are defined here once instead of being
## re-derived inside each `_draw()`. Shapes that represent something with
## a heading point along +X, matching `Vector2.from_angle(0)`, so callers
## can rotate by a movement angle without correcting for it.

## Regular polygon centred on the origin.
static func ngon(radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(sides)
	for i in sides:
		points[i] = Vector2.from_angle(rotation + TAU * float(i) / float(sides)) * radius
	return points

## The same ring of points with the first repeated at the end, because
## `draw_polyline` draws an open path and will not close the loop itself.
static func closed(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return points
	var loop := points.duplicate()
	loop.append(points[0])
	return loop

## Narrow triangle pointing along +X — the base hull for anything that
## travels nose-first.
static func dart(length: float, half_width: float, rotation: float = 0.0) -> PackedVector2Array:
	return _rotated(PackedVector2Array([
		Vector2(length, 0.0),
		Vector2(-length * 0.6, half_width),
		Vector2(-length * 0.6, -half_width),
	]), rotation)

## Arrowhead with swept-back wings and a notched tail, pointing along +X.
## Reads as "fast" at small sizes where a plain triangle reads as "blob".
static func chevron(length: float, half_width: float, rotation: float = 0.0) -> PackedVector2Array:
	return _rotated(PackedVector2Array([
		Vector2(length, 0.0),
		Vector2(-length * 0.7, half_width),
		Vector2(-length * 0.25, 0.0),
		Vector2(-length * 0.7, -half_width),
	]), rotation)

## Star polygon alternating between the two radii.
static func star(outer: float, inner: float, spikes: int, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(spikes * 2)
	for i in spikes * 2:
		var radius := outer if i % 2 == 0 else inner
		points[i] = Vector2.from_angle(rotation + TAU * float(i) / float(spikes * 2)) * radius
	return points

static func _rotated(points: PackedVector2Array, rotation: float) -> PackedVector2Array:
	if is_zero_approx(rotation):
		return points
	for i in points.size():
		points[i] = points[i].rotated(rotation)
	return points
