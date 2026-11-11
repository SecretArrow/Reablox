extends RefCounted
## ThumbnailArt — cover art prosedural untuk kartu game ala platform modern.
## Menggambar ilustrasi 16:9 per mode (langit gradien, matahari/bulan, awan,
## siluet blok, aksen khas mode) langsung ke Image — tanpa aset eksternal.
## Hasil dibuat sekali per mode lalu di-cache (Dictionary statis).

const W := 360
const H := 202
const RADIUS := 20

## Palet per mode: [sky_top, sky_bottom, ground, accent, accent2]
const PALETTES := {
	"obby": ["#2b3a67", "#e8845e", "#3d4a6b", "#ffd166", "#26c6da"],
	"racing": ["#63a4ff", "#c9e6ff", "#5f6b7a", "#ff5252", "#ffee58"],
	"survival": ["#0d1b2a", "#1b3a4b", "#22303c", "#7cb342", "#5c6bc0"],
	"tycoon": ["#8ec5ff", "#e8f4ff", "#90a4ae", "#ffc107", "#66bb6a"],
	"city": ["#7db9f2", "#dcefff", "#78909c", "#ef5350", "#ffee58"],
	"horror": ["#14060f", "#3d1029", "#1d1220", "#4dd0e1", "#7e57c2"],
	"bedwars": ["#3a1f6b", "#8a4fd3", "#2a2550", "#ef5350", "#29b6f6"],
	"hide_seek": ["#4a3b7a", "#e09f6b", "#3d3560", "#ff7043", "#ffd166"],
	"adventure": ["#5fb0d9", "#cdeffd", "#66bb6a", "#ffd166", "#8d6e63"],
	"empty": ["#6ea8ff", "#d7e9ff", "#b0bec5", "#26c6da", "#ab47bc"],
	"world": ["#6ea8ff", "#d7e9ff", "#90a4ae", "#26c6da", "#66bb6a"],
}

static var _cache: Dictionary = {}


## Ambil thumbnail untuk mode; hasil di-cache dan dibagikan (jangan dimutasi).
static func get_icon(mode_id: String) -> ImageTexture:
	var key := mode_id
	if _cache.has(key):
		return _cache[key]
	var img := _draw_mode(key)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _draw_mode(mode_id: String) -> Image:
	var pal: Array = PALETTES.get(mode_id, PALETTES["empty"])
	var top := Color(String(pal[0]))
	var bot := Color(String(pal[1]))
	var ground := Color(String(pal[2]))
	var c1 := Color(String(pal[3]))
	var c2 := Color(String(pal[4]))
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)

	# --- Langit: gradien vertikal (per baris, cepat via fill_rect). ---
	for y in H:
		var t := float(y) / float(H - 1)
		var c := top.lerp(bot, t)
		img.fill_rect(Rect2i(0, y, W, 1), c)

		# --- Matahari / bulan dengan glow lembut. ---

		# --- Awan lembut (rounded rect semi-transparan). ---

		# --- Tanah / lantai dunia. ---

		# --- Aksen khas mode. ---

		# --- Vignette tipis atas & bawah untuk kedalaman. ---

		# --- Mask sudut membulat (hanya area sudut — murah). ---
	var sun_pos := Vector2i(int(W * 0.78), int(H * 0.24))
	var sun_c := c1 if mode_id != "horror" and mode_id != "survival" else Color("#e8eaf6")
	_draw_glow_circle(img, sun_pos, 30, sun_c, mode_id in ["horror", "survival"])

	# --- Awan lembut (rounded rect semi-transparan). ---
	_draw_cloud(img, Vector2i(int(W * 0.12), int(H * 0.20)), 46, 12)
	_draw_cloud(img, Vector2i(int(W * 0.52), int(H * 0.12)), 34, 10)
	if mode_id in ["horror", "bedwars"]:
		_draw_cloud(img, Vector2i(int(W * 0.30), int(H * 0.32)), 40, 9)

		# --- Tanah / lantai dunia. ---

		# --- Aksen khas mode. ---

		# --- Vignette tipis atas & bawah untuk kedalaman. ---

		# --- Mask sudut membulat (hanya area sudut — murah). ---
	var gy := int(H * 0.72)
	img.fill_rect(Rect2i(0, gy, W, H - gy), ground)
	img.fill_rect(Rect2i(0, gy, W, 4), ground.lightened(0.25))

	# --- Aksen khas mode. ---
	match mode_id:
		"obby":
			_draw_tower(img, Vector2i(int(W * 0.30), gy), c2)
			_draw_beacon(img, Vector2i(int(W * 0.52), gy - 26), c1)
			_draw_platform(img, Vector2i(int(W * 0.68), gy - 44), c2)
		"racing":
			_draw_road(img, gy, ground, c2)
			_draw_kart(img, Vector2i(int(W * 0.42), gy + 14), c1, c2)
		"survival":
			_draw_zombie(img, Vector2i(int(W * 0.36), gy), Color("#7cb342"))
			_draw_zombie(img, Vector2i(int(W * 0.58), gy), Color("#9ccc65"))
		"tycoon":
			_draw_building(img, Vector2i(int(W * 0.24), gy), 56, 40, c1)
			_draw_building(img, Vector2i(int(W * 0.44), gy), 44, 62, c2)
			_draw_coin(img, Vector2i(int(W * 0.70), gy - 18), c1)
		"city":
			_draw_building(img, Vector2i(int(W * 0.18), gy), 40, 58, Color("#546e7a"))
			_draw_building(img, Vector2i(int(W * 0.38), gy), 52, 44, Color("#607d8b"))
			_draw_building(img, Vector2i(int(W * 0.58), gy), 44, 66, Color("#546e7a"))
			_draw_lamp(img, Vector2i(int(W * 0.80), gy), c1)
		"horror":
			_draw_window(img, Vector2i(int(W * 0.26), gy - 40), 26, 34, c1)
			_draw_eye(img, Vector2i(int(W * 0.62), gy - 20), c2)
		"bedwars":
			_draw_island(img, Vector2i(int(W * 0.28), gy - 6), c2)
			_draw_bed(img, Vector2i(int(W * 0.58), gy - 6), c1)
		"hide_seek":
			_draw_bush(img, Vector2i(int(W * 0.30), gy), Color("#43a047"))
			_draw_bush(img, Vector2i(int(W * 0.66), gy), Color("#2e7d32"))
			_draw_eye(img, Vector2i(int(W * 0.48), gy - 18), c1)
		"adventure":
			_draw_tree(img, Vector2i(int(W * 0.26), gy), Color("#2e7d32"))
			_draw_tree(img, Vector2i(int(W * 0.72), gy), Color("#388e3c"))
			_draw_star(img, Vector2i(int(W * 0.50), gy - 40), c1)
		"empty", "world", _:
			_draw_block(img, Vector2i(int(W * 0.34), gy), c1)
			_draw_block(img, Vector2i(int(W * 0.52), gy - 22), c2)
			_draw_block(img, Vector2i(int(W * 0.64), gy), Color("#ef5350"))

		# --- Vignette tipis atas & bawah untuk kedalaman. ---

		# --- Mask sudut membulat (hanya area sudut — murah). ---
	img.fill_rect(Rect2i(0, 0, W, 10), Color(0, 0, 0, 0.10))
	img.fill_rect(Rect2i(0, H - 12, W, 12), Color(0, 0, 0, 0.14))

	# --- Mask sudut membulat (hanya area sudut — murah). ---
	_mask_corners(img)
	return img


# ------------------------------------------------------------------ primitif


static func _draw_glow_circle(
	img: Image, center: Vector2i, r: int, col: Color, is_moon: bool
) -> void:
	var rr := r * 3
	for y in range(-rr, rr + 1):
		for x in range(-rr, rr + 1):
			var d := sqrt(float(x * x + y * y))
			if d <= float(rr):
				var px := center.x + x
				var py := center.y + y
				if px < 0 or px >= W or py < 0 or py >= H:
					continue
				var a: float = clampf(1.0 - d / float(rr), 0.0, 1.0) * 0.16
				if d <= float(r):
					a = 1.0
				var c := col
				c.a = a
				if d > float(r):
					_blend_pixel(img, px, py, c)
				else:
					img.set_pixel(px, py, c)

		# Bulan sabit: tumpuk lingkaran warna langit.
	if is_moon:
		# Bulan sabit: tumpuk lingkaran warna langit.
		var off := Vector2i(int(float(r) * 0.7), int(float(r) * -0.25))
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + y * y <= r * r:
					var px := center.x + off.x + x
					var py := center.y + off.y + y
					if px >= 0 and px < W and py >= 0 and py < H:
						var d2 := float((x + off.x) * (x + off.x) + (y + off.y) * (y + off.y))
						if d2 > float(r * r) * 0.82:
							continue
						_blend_pixel(img, px, py, Color(col.r, col.g, col.b, 0.55))


static func _draw_cloud(img: Image, at: Vector2i, w: int, h: int) -> void:
	var c := Color(1, 1, 1, 0.30)
	img.fill_rect(Rect2i(at.x, at.y, w, h), c)
	img.fill_rect(Rect2i(at.x + w / 5, at.y - h / 2, int(w * 0.6), h), c)
	img.fill_rect(
		Rect2i(at.x - w / 8, at.y + h / 3, int(w * 1.2), int(h * 0.7)), Color(1, 1, 1, 0.16)
	)


static func _draw_block(img: Image, at: Vector2i, col: Color, s: int = 22) -> void:
	img.fill_rect(Rect2i(at.x - s / 2, at.y - s, s, s), col)
	img.fill_rect(Rect2i(at.x - s / 2, at.y - s, s, 3), col.lightened(0.35))
	img.fill_rect(Rect2i(at.x - s / 2, at.y - 3, s, 3), col.darkened(0.3))


static func _draw_tower(img: Image, base: Vector2i, col: Color) -> void:
	for i in 4:
		_draw_block(img, Vector2i(base.x + i * 14, base.y - i * 16), col, 20)
	_draw_beacon(img, Vector2i(base.x + 4 * 14, base.y - 4 * 16 - 10), Color("#ffee58"))


static func _draw_beacon(img: Image, at: Vector2i, col: Color) -> void:
	for y in 3:
		var w := 4 + y * 3
		img.fill_rect(
			Rect2i(at.x - w / 2, at.y + y * 4, w, 4), Color(col.r, col.g, col.b, 0.85 - y * 0.2)
		)
	img.fill_rect(Rect2i(at.x - 2, at.y - 8, 4, 10), col)


static func _draw_platform(img: Image, at: Vector2i, col: Color) -> void:
	img.fill_rect(Rect2i(at.x - 16, at.y - 5, 32, 6), col)
	img.fill_rect(Rect2i(at.x - 16, at.y - 5, 32, 2), col.lightened(0.4))


static func _draw_road(img: Image, gy: int, _ground: Color, mark_col: Color) -> void:
	img.fill_rect(Rect2i(0, gy + 8, W, 18), Color("#37474f"))
	img.fill_rect(Rect2i(0, gy + 16, W, 2), Color("#455a64"))
	var x := 6
	while x < W:
		img.fill_rect(Rect2i(x, gy + 15, 18, 4), mark_col)
		x += 40
		# Garis finish kotak-kotak.
	for i in 8:
		var c := Color(1, 1, 1) if i % 2 == 0 else Color("#212121")
		img.fill_rect(Rect2i(W - 26, gy + 8 + i * 3, 14, 3), c)


static func _draw_kart(img: Image, at: Vector2i, body: Color, detail: Color) -> void:
	img.fill_rect(Rect2i(at.x - 18, at.y - 12, 36, 10), body)
	img.fill_rect(Rect2i(at.x - 10, at.y - 18, 20, 8), detail)
	img.fill_rect(Rect2i(at.x - 18, at.y - 4, 8, 6), Color("#212121"))
	img.fill_rect(Rect2i(at.x + 10, at.y - 4, 8, 6), Color("#212121"))
	img.fill_rect(Rect2i(at.x + 14, at.y - 16, 4, 6), Color("#212121"))


static func _draw_zombie(img: Image, base: Vector2i, col: Color) -> void:
	img.fill_rect(Rect2i(base.x - 8, base.y - 26, 16, 20), col)
	img.fill_rect(Rect2i(base.x - 6, base.y - 36, 12, 10), col.lightened(0.15))
	img.fill_rect(Rect2i(base.x - 4, base.y - 33, 3, 3), Color("#212121"))
	img.fill_rect(Rect2i(base.x + 1, base.y - 33, 3, 3), Color("#212121"))
	img.fill_rect(Rect2i(base.x - 10, base.y - 24, 4, 14), col.darkened(0.2))
	img.fill_rect(Rect2i(base.x + 6, base.y - 24, 4, 14), col.darkened(0.2))


static func _draw_building(img: Image, base: Vector2i, w: int, h: int, col: Color) -> void:
	img.fill_rect(Rect2i(base.x - w / 2, base.y - h, w, h), col)
	img.fill_rect(Rect2i(base.x - w / 2, base.y - h, w, 3), col.lightened(0.3))
	var lit := Color("#ffe082")
	for wy in range(1, int(h / 12)):
		for wx in range(1, int(w / 12)):
			if (wx + wy) % 3 != 0:
				img.fill_rect(Rect2i(base.x - w / 2 + wx * 11, base.y - h + 6 + wy * 11, 6, 6), lit)


static func _draw_coin(img: Image, at: Vector2i, col: Color) -> void:
	for y in range(-9, 10):
		for x in range(-9, 10):
			if x * x + y * y <= 81:
				var c := col if x * x + y * y >= 64 else col.lightened(0.3)
				img.set_pixel(at.x + x, at.y + y, c)


static func _draw_lamp(img: Image, base: Vector2i, glow: Color) -> void:
	img.fill_rect(Rect2i(base.x - 2, base.y - 30, 4, 30), Color("#455a64"))
	img.fill_rect(Rect2i(base.x - 7, base.y - 34, 14, 5), glow)
	_draw_glow_circle(img, Vector2i(base.x, base.y - 32), 8, glow, false)


static func _draw_window(img: Image, at: Vector2i, w: int, h: int, col: Color) -> void:
	img.fill_rect(Rect2i(at.x - w / 2, at.y - h, w, h), Color("#263238"))
	img.fill_rect(Rect2i(at.x - w / 2 + 4, at.y - h + 4, w - 8, h - 8), col)


static func _draw_eye(img: Image, at: Vector2i, col: Color) -> void:
	for y in range(-6, 7):
		for x in range(-9, 10):
			if float(x * x) / 81.0 + float(y * y) / 36.0 <= 1.0:
				img.set_pixel(at.x + x, at.y + y, Color(1, 1, 1, 0.9))
	for y in range(-3, 4):
		for x in range(-4, 5):
			if x * x + y * y <= 9:
				img.set_pixel(at.x + x + 2, at.y + y, col)


static func _draw_island(img: Image, base: Vector2i, col: Color) -> void:
	for y in 6:
		var w := 64 - y * 10
		img.fill_rect(Rect2i(base.x - w / 2, base.y - y * 6, w, 6), col.darkened(0.05 * y))
	img.fill_rect(Rect2i(base.x - 32, base.y - 8, 64, 8), Color("#66bb6a"))


static func _draw_bed(img: Image, base: Vector2i, col: Color) -> void:
	img.fill_rect(Rect2i(base.x - 16, base.y - 10, 32, 10), col)
	img.fill_rect(Rect2i(base.x - 16, base.y - 14, 10, 6), Color(1, 1, 1, 0.9))
	img.fill_rect(Rect2i(base.x - 16, base.y - 10, 32, 3), col.lightened(0.25))


static func _draw_bush(img: Image, base: Vector2i, col: Color) -> void:
	for y in 3:
		var w := 34 - y * 8
		img.fill_rect(
			Rect2i(base.x - w / 2, base.y - 12 - y * 8, w, 10), col if y < 2 else col.lightened(0.2)
		)


static func _draw_tree(img: Image, base: Vector2i, col: Color) -> void:
	img.fill_rect(Rect2i(base.x - 4, base.y - 18, 8, 18), Color("#6d4c41"))
	img.fill_rect(Rect2i(base.x - 18, base.y - 40, 36, 24), col)
	img.fill_rect(Rect2i(base.x - 12, base.y - 48, 24, 10), col.lightened(0.15))


static func _draw_star(img: Image, at: Vector2i, col: Color) -> void:
	var pts := 5
	var outer := 11.0
	var inner := 5.0
	for i in range(pts * 2):
		var ang := TAU * float(i) / float(pts * 2) - PI * 0.5
		var rr := outer if i % 2 == 0 else inner
		var px := at.x + int(cos(ang) * rr)
		var py := at.y + int(sin(ang) * rr)
		if px >= 0 and px < W and py >= 0 and py < H:
			img.set_pixel(px, py, col)
	img.fill_rect(Rect2i(at.x - 2, at.y - 2, 5, 5), col)


# ------------------------------------------------------------------ util


static func _blend_pixel(img: Image, x: int, y: int, c: Color) -> void:
	var bg := img.get_pixel(x, y)
	img.set_pixel(x, y, bg.lerp(Color(c.r, c.g, c.b), c.a))


static func _mask_corners(img: Image) -> void:
	for cy in RADIUS:
		for cx in RADIUS:
			var in_circle := (
				Vector2(float(cx - RADIUS), float(cy - RADIUS)).length() <= float(RADIUS)
			)
			if not in_circle:
				var c := Color(0, 0, 0, 0)
				img.set_pixel(cx, cy, c)
				img.set_pixel(W - 1 - cx, cy, c)
				img.set_pixel(cx, H - 1 - cy, c)
				img.set_pixel(W - 1 - cx, H - 1 - cy, c)
