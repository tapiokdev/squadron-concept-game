class_name GlowTexture
extends RefCounted

## Builds soft radial falloff textures.
##
## A big translucent `draw_circle` reads as a flat disc of grey paint with
## a hard rim — fine for a solid body, wrong for anything that should look
## like light. One small gradient texture drawn with `draw_texture_rect`
## fixes that, costs a single draw call, and needs no shader, which suits
## the web target. Used for explosion flashes and the nebula backdrop.

## `mid_offset` / `mid_alpha` bend the falloff curve: a low alpha at a low
## offset gives a tight hot core with a wide faint halo.
static func radial(size: int = 128, mid_offset: float = 0.35,
		mid_alpha: float = 0.5) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(mid_offset, Color(1, 1, 1, mid_alpha))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size
	texture.height = size
	return texture
