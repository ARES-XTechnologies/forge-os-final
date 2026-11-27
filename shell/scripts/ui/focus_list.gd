class_name FocusList
extends RefCounted
## Linear focus helper for rows/columns of focusable controls (anything with set_focused()).

var items: Array = []
var index := 0
var horizontal := true
var active := true

func _init(list: Array = [], horiz := true) -> void:
	items = list
	horizontal = horiz

func current():
	return items[index] if index < items.size() else null

func apply() -> void:
	for i in items.size():
		if items[i].has_method("set_focused"):
			items[i].set_focused(active and i == index)

func set_active(on: bool) -> void:
	active = on
	apply()

func focus(i: int) -> void:
	index = clampi(i, 0, maxi(0, items.size() - 1))
	apply()

## Returns true if the action was a move along this list's axis (even at an edge).
func handle(a: StringName) -> bool:
	var d := 0
	if horizontal:
		if a == &"left": d = -1
		elif a == &"right": d = 1
	else:
		if a == &"up": d = -1
		elif a == &"down": d = 1
	if d == 0:
		return false
	var n := index + d
	if n < 0 or n >= items.size():
		Sfx.play("edge")
		return false
	index = n
	apply()
	Sfx.focus_tick(index)
	return true

func press() -> void:
	var c = current()
	if c and c.has_method("press"):
		c.press()
