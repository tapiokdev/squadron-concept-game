class_name Palette
extends RefCounted

## Shared colour system for the neon sci-fi art pass. There are no sprites
## in this project — everything is drawn from primitives — so the palette
## is the art direction, and every `_draw()` in the game pulls from here.
##
## Glow is real HDR bloom (WorldEnvironment in main.tscn), so brightness
## and glow are the same decision: colours pushed past 1.0 bleed, colours
## under it stay matte. Use `hot()` for the emissive parts of a shape and
## leave hulls and outlines below 1.0 so the silhouette survives the bloom.

# --- Space ---------------------------------------------------------------
const VOID := Color(0.020, 0.024, 0.047)
## Nebula tints carry their peak alpha; the backdrop divides it per layer.
const NEBULA_COOL := Color(0.12, 0.26, 0.62, 0.30)
const NEBULA_WARM := Color(0.38, 0.10, 0.44, 0.26)
const GRID_MINOR := Color(0.22, 0.52, 0.80, 0.055)
const GRID_MAJOR := Color(0.28, 0.68, 1.00, 0.10)
const STAR_FAR := Color(0.42, 0.52, 0.78)
const STAR_MID := Color(0.72, 0.84, 1.00)
const STAR_NEAR := Color(1.00, 1.00, 1.00)

# --- Factions ------------------------------------------------------------
## Cool blues are yours, warm/magenta is hostile — the one colour rule the
## whole screen obeys, so threat reads at a glance during a swarm.
const TOWER := Color(0.30, 0.78, 1.00)
const TOWER_CORE := Color(0.82, 0.97, 1.00)
const ALLY := Color(0.25, 0.90, 1.00)
const HOSTILE := Color(1.00, 0.25, 0.50)

# --- Systems -------------------------------------------------------------
const RAIL := Color(0.55, 0.90, 1.00)
const PULSE := Color(0.35, 0.80, 1.00)
const BARRAGE := Color(1.00, 0.55, 0.15)
const HEAL := Color(0.40, 1.00, 0.70)
## Player orders — the rally point. Green so it never reads as a unit.
const COMMAND := Color(0.35, 1.00, 0.72)
const DANGER := Color(1.00, 0.28, 0.32)
const XP := Color(0.65, 0.95, 1.00)

## Hull fill for geometric bodies: dark and slightly transparent so the
## neon edge carries the shape instead of a flat blob of colour.
const HULL := Color(0.055, 0.075, 0.125, 0.90)

## Push a colour into HDR so the glow pass picks it up. Roughly: 1.0 sits
## at the bloom threshold, 2 is a bright filament, 4+ blows out to white.
## Use where blowing out is the point — reactor cores, impact flashes,
## sparks that should read as white-hot before they cool.
static func hot(color: Color, gain: float = 2.0) -> Color:
	return Color(color.r * gain, color.g * gain, color.b * gain, color.a)

## Brightest channel lands exactly on `gain`, so the hue survives.
##
## A flat multiply clips channels one at a time and shifts the hue on the
## way: amber (1.0, 0.62, 0.12) at gain 1.8 clips red first and arrives as
## yellow, which costs the player the ability to tell an interceptor from a
## carrier at a glance. Scaling to a known peak keeps the ratios, so
## a gain just over 1.0 still blooms while staying the right colour. Use
## this for anything whose colour carries meaning.
static func neon(color: Color, gain: float = 1.2) -> Color:
	var peak := maxf(color.r, maxf(color.g, color.b))
	if peak <= 0.0:
		return color
	var scale := gain / peak
	return Color(color.r * scale, color.g * scale, color.b * scale, color.a)

## Same colour at a different opacity — scales the existing alpha rather
## than replacing it, so a colour's designed transparency is preserved.
static func fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
