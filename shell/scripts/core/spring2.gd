class_name Spring2
extends RefCounted
## 2D version of Spring (position, offsets, sizes).

var x: Spring
var y: Spring

static func make(start: Vector2, k: float, d: float) -> Spring2:
	var s := Spring2.new()
	s.x = Spring.make(start.x, k, d)
	s.y = Spring.make(start.y, k, d)
	return s

static func preset(start: Vector2, name: StringName) -> Spring2:
	var p := Spring.params(name)
	return make(start, p.x, p.y)

var value: Vector2:
	get: return Vector2(x.value, y.value)

var target: Vector2:
	get: return Vector2(x.target, y.target)
	set(v):
		x.target = v.x
		y.target = v.y

func snap(v: Vector2) -> void:
	x.snap(v.x)
	y.snap(v.y)

func kick(v: Vector2) -> void:
	x.kick(v.x)
	y.kick(v.y)

func step(dt: float) -> Vector2:
	return Vector2(x.step(dt), y.step(dt))

func settled(eps: float = 0.01) -> bool:
	return x.settled(eps) and y.settled(eps)
