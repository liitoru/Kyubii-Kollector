# KCDT - Kyubii Collector Development Tools
@tool
class_name DevPresets
extends RefCounted
## Visual presets for DevMessage / DevLabel: just a color + an SVG badge icon.
## They carry no behaviour, they only make notes easy to tell apart.

enum Preset {
	DEFAULT,
	BLUE_CUBE,
	GREEN_PIN,
	PURPLE_EYE,
	ORANGE_GEAR,
	RED_WARNING,
	CYAN_CROSSHAIR,
	TEAL_MAGNIFIER,
	LAVENDER_STOPWATCH,
	LIME_ARROWS,
	PINK_CAMERA,
	INDIGO_LIST,
	GREEN_SPEAKER,
	SKY_GRID,
	AMBER_SWAP,
	VIOLET_FLAG,
	GRAY_BLOCK,
}

const COLORS := {
	Preset.DEFAULT: "#2196F3",
	Preset.BLUE_CUBE: "#1E88E5",
	Preset.GREEN_PIN: "#6CC24A",
	Preset.PURPLE_EYE: "#8E4FD6",
	Preset.ORANGE_GEAR: "#F5A21B",
	Preset.RED_WARNING: "#F0505A",
	Preset.CYAN_CROSSHAIR: "#1FBAD6",
	Preset.TEAL_MAGNIFIER: "#1FBFA2",
	Preset.LAVENDER_STOPWATCH: "#9B7FD8",
	Preset.LIME_ARROWS: "#A6D321",
	Preset.PINK_CAMERA: "#E05A9C",
	Preset.INDIGO_LIST: "#5B63DC",
	Preset.GREEN_SPEAKER: "#3DBE4A",
	Preset.SKY_GRID: "#12B5E5",
	Preset.AMBER_SWAP: "#F07F22",
	Preset.VIOLET_FLAG: "#6A5AE0",
	Preset.GRAY_BLOCK: "#7A7A80",
}

const NAMES := {
	Preset.DEFAULT: "Default (envelope)",
	Preset.BLUE_CUBE: "Blue Cube",
	Preset.GREEN_PIN: "Green Pin",
	Preset.PURPLE_EYE: "Purple Eye",
	Preset.ORANGE_GEAR: "Orange Gear",
	Preset.RED_WARNING: "Red Warning",
	Preset.CYAN_CROSSHAIR: "Cyan Crosshair",
	Preset.TEAL_MAGNIFIER: "Teal Magnifier",
	Preset.LAVENDER_STOPWATCH: "Lavender Stopwatch",
	Preset.LIME_ARROWS: "Lime Arrows",
	Preset.PINK_CAMERA: "Pink Camera",
	Preset.INDIGO_LIST: "Indigo List",
	Preset.GREEN_SPEAKER: "Green Speaker",
	Preset.SKY_GRID: "Sky Grid",
	Preset.AMBER_SWAP: "Amber Swap",
	Preset.VIOLET_FLAG: "Violet Flag",
	Preset.GRAY_BLOCK: "Gray Block",
}

## "{bg}" is replaced by the badge color (so holes match the circle).
const GLYPHS := {
	Preset.DEFAULT: '<rect x="28" y="40" width="72" height="50" rx="6" fill="#fff"/><path d="M28 47 L64 74 L100 47" fill="none" stroke="{bg}" stroke-width="5" stroke-linejoin="round"/>',
	Preset.BLUE_CUBE: '<path d="M64 26 L96 44 L64 62 L32 44 Z" fill="#fff"/><path d="M30 52 L60 69 V102 L30 85 Z" fill="#fff"/><path d="M98 52 L68 69 V102 L98 85 Z" fill="#fff"/>',
	Preset.GREEN_PIN: '<path d="M64 22 C46 22 34 36 34 52 C34 76 64 106 64 106 C64 106 94 76 94 52 C94 36 82 22 64 22 Z" fill="#fff"/><circle cx="64" cy="52" r="12" fill="{bg}"/>',
	Preset.PURPLE_EYE: '<path d="M16 64 Q64 20 112 64 Q64 108 16 64 Z" fill="#fff"/><circle cx="64" cy="64" r="22" fill="{bg}"/><circle cx="64" cy="64" r="10" fill="#fff"/>',
	Preset.ORANGE_GEAR: '<rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(0 64 64)"/><rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(45 64 64)"/><rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(90 64 64)"/><rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(135 64 64)"/><rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(180 64 64)"/><rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(225 64 64)"/><rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(270 64 64)"/><rect x="57" y="18" width="14" height="24" rx="3" fill="#fff" transform="rotate(315 64 64)"/><circle cx="64" cy="64" r="32" fill="#fff"/><circle cx="64" cy="64" r="13" fill="{bg}"/>',
	Preset.RED_WARNING: '<path d="M64 24 L106 98 H22 Z" fill="#fff" stroke="#fff" stroke-width="8" stroke-linejoin="round"/><rect x="59" y="48" width="10" height="28" rx="5" fill="{bg}"/><circle cx="64" cy="87" r="6" fill="{bg}"/>',
	Preset.CYAN_CROSSHAIR: '<circle cx="64" cy="64" r="28" fill="none" stroke="#fff" stroke-width="8"/><path d="M64 18 V40 M64 88 V110 M18 64 H40 M88 64 H110" stroke="#fff" stroke-width="8" stroke-linecap="round"/><circle cx="64" cy="64" r="6" fill="#fff"/>',
	Preset.TEAL_MAGNIFIER: '<circle cx="54" cy="54" r="26" fill="none" stroke="#fff" stroke-width="10"/><path d="M74 74 L104 104" stroke="#fff" stroke-width="12" stroke-linecap="round"/>',
	Preset.LAVENDER_STOPWATCH: '<circle cx="64" cy="72" r="34" fill="none" stroke="#fff" stroke-width="9"/><rect x="52" y="16" width="24" height="10" rx="4" fill="#fff"/><rect x="60" y="24" width="8" height="12" fill="#fff"/><path d="M64 72 V48 A24 24 0 0 1 85 60 Z" fill="#fff"/>',
	Preset.LIME_ARROWS: '<path d="M64 14 L80 34 H48 Z M64 114 L80 94 H48 Z M14 64 L34 48 V80 Z M114 64 L94 48 V80 Z" fill="#fff"/><path d="M64 34 V94 M34 64 H94" stroke="#fff" stroke-width="7"/><circle cx="64" cy="64" r="9" fill="#fff"/>',
	Preset.PINK_CAMERA: '<path d="M44 38 L52 26 H76 L84 38 Z" fill="#fff"/><rect x="20" y="38" width="88" height="62" rx="12" fill="#fff"/><circle cx="64" cy="69" r="21" fill="{bg}"/><circle cx="64" cy="69" r="11" fill="#fff"/>',
	Preset.INDIGO_LIST: '<g fill="#fff"><circle cx="34" cy="42" r="7"/><circle cx="34" cy="64" r="7"/><circle cx="34" cy="86" r="7"/><rect x="50" y="35" width="48" height="14" rx="7"/><rect x="50" y="57" width="48" height="14" rx="7"/><rect x="50" y="79" width="48" height="14" rx="7"/></g>',
	Preset.GREEN_SPEAKER: '<path d="M22 52 H42 L68 30 V98 L42 76 H22 Z" fill="#fff" stroke="#fff" stroke-width="4" stroke-linejoin="round"/><path d="M80 48 Q92 64 80 80" fill="none" stroke="#fff" stroke-width="8" stroke-linecap="round"/><path d="M90 34 Q114 64 90 94" fill="none" stroke="#fff" stroke-width="8" stroke-linecap="round"/>',
	Preset.SKY_GRID: '<rect x="24" y="24" width="22" height="22" rx="5" fill="#fff"/><rect x="53" y="24" width="22" height="22" rx="5" fill="#fff"/><rect x="82" y="24" width="22" height="22" rx="5" fill="#fff"/><rect x="24" y="53" width="22" height="22" rx="5" fill="#fff"/><rect x="53" y="53" width="22" height="22" rx="5" fill="#fff"/><rect x="82" y="53" width="22" height="22" rx="5" fill="#fff"/><rect x="24" y="82" width="22" height="22" rx="5" fill="#fff"/><rect x="53" y="82" width="22" height="22" rx="5" fill="#fff"/><rect x="82" y="82" width="22" height="22" rx="5" fill="#fff"/>',
	Preset.AMBER_SWAP: '<path d="M28 58 V50 Q28 36 42 36 H86" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/><path d="M82 18 L106 36 L82 54 Z" fill="#fff" stroke="#fff" stroke-width="4" stroke-linejoin="round"/><path d="M100 70 V78 Q100 92 86 92 H42" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/><path d="M46 74 L22 92 L46 110 Z" fill="#fff" stroke="#fff" stroke-width="4" stroke-linejoin="round"/>',
	Preset.VIOLET_FLAG: '<rect x="32" y="20" width="9" height="90" rx="4" fill="#fff"/><path d="M41 26 Q62 16 78 28 T104 30 V70 Q90 78 78 68 T41 68 Z" fill="#fff"/>',
	Preset.GRAY_BLOCK: '<circle cx="64" cy="64" r="36" fill="none" stroke="#fff" stroke-width="10"/><path d="M38 90 L90 38" stroke="#fff" stroke-width="10" stroke-linecap="round"/>',
}

const BADGE_HEAD := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="64" r="60" fill="{bg}" stroke="#ffffff" stroke-width="5"/>'

static var _cache: Dictionary = {}


static func color_of(preset: int) -> Color:
	return Color(COLORS.get(preset, COLORS[Preset.DEFAULT]))


static func name_of(preset: int) -> String:
	return NAMES.get(preset, "Default")


static func svg_for(preset: int, bg: Color) -> String:
	var hex := "#" + bg.to_html(false)
	return (BADGE_HEAD + GLYPHS.get(preset, GLYPHS[Preset.DEFAULT]) + "</svg>").replace("{bg}", hex)


## Badge texture for a preset drawn on the given background color.
static func icon_of(preset: int, bg: Color) -> Texture2D:
	var key := "%d|%s" % [preset, bg.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var tex := DevGlyphs.svg_to_texture(svg_for(preset, bg))
	if tex:
		_cache[key] = tex
	return tex
