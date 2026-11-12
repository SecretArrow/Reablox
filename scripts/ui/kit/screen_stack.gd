class_name ScreenStack
extends Control
## Navigasi layar bertumpuk ala aplikasi mobile (push / pop / replace).
##
## Hanya layar teratas yang terlihat; layar di bawahnya disembunyikan tanpa
## dihapus sehingga statusnya utuh saat kembali (pop).

var _screens: Array[Control] = []


## Tambah layar baru di atas tumpukan; layar aktif lama disembunyikan.
func push(screen: Control) -> void:
	if screen == null:
		return
	var top := current()
	if top != null:
		top.visible = false
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.visible = true
	_screens.append(screen)


## Hapus layar teratas (dibebaskan saat idle) lalu tampilkan layar sebelumnya.
## Mengembalikan layar yang dihapus (masih valid sampai akhir frame).
func pop() -> Control:
	if _screens.is_empty():
		return null
	var top: Control = _screens.pop_back()
	_detach_and_free(top)
	var below := current()
	if below != null:
		below.visible = true
	return top


## Buang seluruh tumpukan lalu tampilkan satu layar baru.
func replace(screen: Control) -> void:
	clear()
	push(screen)


## Layar aktif (teratas); null bila tumpukan kosong.
func current() -> Control:
	if _screens.is_empty():
		return null
	var top: Control = _screens.back()
	if top != null and not is_instance_valid(top):
		return null
	return top


## Jumlah layar di dalam tumpukan.
func depth() -> int:
	return _screens.size()


## Kosongkan seluruh tumpukan dan bebaskan semua layar.
func clear() -> void:
	while not _screens.is_empty():
		var top: Control = _screens.pop_back()
		_detach_and_free(top)


## Lepaskan layar dari tree lalu jadwalkan pembebasan (aman untuk null).
func _detach_and_free(screen: Control) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if screen.get_parent() == self:
		remove_child(screen)
	screen.queue_free()
