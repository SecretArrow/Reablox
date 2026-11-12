class_name BrickColors
extends RefCounted
## Palet warna bata untuk avatar — 35 warna bernama, pencarian case-insensitive.
## Nama yang tidak dikenal akan fallback ke "Medium stone grey".

const FALLBACK_NAME := "Medium stone grey"

const PALETTE: Dictionary = {
	"White": Color("f2f3f3"),
	"Light stone grey": Color("e5e4df"),
	"Medium stone grey": Color("a3a2a5"),
	"Dark stone grey": Color("635f62"),
	"Black": Color("1b2a35"),
	"Reddish brown": Color("694028"),
	"Brown": Color("7c5c46"),
	"Dark orange": Color("a05f35"),
	"Bright orange": Color("da8541"),
	"Br. yellowish orange": Color("eab892"),
	"Earth green": Color("27462d"),
	"Dark green": Color("287f47"),
	"Bright green": Color("4b974b"),
	"Lime green": Color("00ff00"),
	"Sand green": Color("789082"),
	"Sand blue": Color("74869d"),
	"Navy blue": Color("002060"),
	"Bright blue": Color("0d69ac"),
	"Pastel Blue": Color("80bbdb"),
	"Cyan": Color("04afec"),
	"Toothpaste": Color("00ffff"),
	"Bright violet": Color("6b327c"),
	"Royal purple": Color("6225d1"),
	"Lavender": Color("a694b7"),
	"Magenta": Color("aa00aa"),
	"Hot pink": Color("ff00bf"),
	"Pink": Color("ff66cc"),
	"Bright red": Color("c4281c"),
	"New Yeller": Color("ffff00"),
	"Bright yellow": Color("f5cd30"),
	"Brick yellow": Color("d7c59a"),
	"Camo": Color("3a7d15"),
	"Grime": Color("7f8e64"),
	"Dark taupe": Color("594633"),
	"Br. yellowish green": Color("a4bd47"),
}


static func color_of(color_name: String) -> Color:
	# Cari nama secara case-insensitive; bila tidak ketemu pakai warna fallback.
	var wanted := color_name.strip_edges().to_lower()
	for key in PALETTE:
		if String(key).to_lower() == wanted:
			return PALETTE[key]
	return PALETTE[FALLBACK_NAME]


static func names() -> Array:
	# Daftar seluruh nama warna, terurut menaik.
	var list: Array = PALETTE.keys()
	list.sort()
	return list


static func is_valid(color_name: String) -> bool:
	# True bila nama warna ada di palet (case-insensitive).
	var wanted := color_name.strip_edges().to_lower()
	for key in PALETTE:
		if String(key).to_lower() == wanted:
			return true
	return false


static func default_noob() -> Dictionary:
	# Warna bawaan avatar "noob" klasik.
	return {
		"head": "Bright yellow",
		"torso": "Bright blue",
		"left_arm": "Bright yellow",
		"right_arm": "Bright yellow",
		"left_leg": "Br. yellowish green",
		"right_leg": "Br. yellowish green",
	}
