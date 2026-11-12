class_name NameTag
extends Label3D
## NameTag — label nama 3D di atas kepala pemain. Label (Control) tidak cocok
## untuk dunia 3D, jadi memakai Label3D dengan billboard agar selalu menghadap
## kamera. Dibuat lewat NameTag.make(parent, "Nama", tinggi).

var is_visible_tag := true


## Buat tag nama sebagai anak `parent` (mis. node avatar pemain).
## Billboard enum milik BaseMaterial3D dipakai Label3D agar tag selalu
## menghadap kamera dari arah mana pun.
static func make(parent: Node3D, player_name: String, height := 6.2) -> NameTag:
	var tag := NameTag.new()
	tag.text = player_name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.01
	tag.position = Vector3(0.0, height, 0.0)
	parent.add_child(tag)
	return tag


func set_display_name(nama: String) -> void:
	text = nama


func get_display_name() -> String:
	return text


## Tampilkan/sembunyikan lewat alpha modulate (is_visible_tag).
func set_tag_visible(value: bool) -> void:
	is_visible_tag = value
	modulate.a = 1.0 if value else 0.0
