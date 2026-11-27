class_name Spring
extends RefCounted
## Damped harmonic spring. Every moving thing in FORGE OS runs on one of these.
## Integrated with fixed 1/240 s sub-steps so motion is identical at 30, 60, 144 or 240 Hz.

const SUBSTEP := 1.0 / 240.0

var value: float = 0.0
var velocity: float = 0.0
var target: float = 0.0
var stiffness: float = 300.0
var damping: float = 26.0
var mass: float = 1.0
var _accum: float = 0.0

static func make(start: float, k: float, d: float) -> Spring:
	var s := Spring.new()
	s.value = start
	s.target = start
	s.stiffness = k
	s.damping = d
	return s

static func params(name: StringName) -> Vector2:
	var p: Vector2 = Tokens.SPRINGS.get(name, Tokens.SPRINGS[&"snappy"])
	# User "bounciness": 0 = critically damped (no overshoot), 1 = designed, 2 = extra bouncy.
	var b := Config.bounce()
	var critical := 2.0 * sqrt(p.x)
	var d := critical + (p.y - critical) * b if b <= 1.0 else p.y / lerpf(1.0, 1.6, b - 1.0)
	return Vector2(p.x, clampf(d, 4.0, critical * 1.2))

static func preset(start: float, name: StringName) -> Spring:
	var p := params(name)
	return make(start, p.x, p.y)

func set_preset(name: StringName) -> void:
	var p := params(name)
	stiffness = p.x
	damping = p.y

func snap(v: float) -> void:
	value = v
	target = v
	velocity = 0.0

func kick(impulse: float) -> void:
	velocity += impulse

func step(dt: float) -> float:
	dt = minf(dt, 0.1) * Config.anim_speed()
	_accum += dt
	while _accum >= SUBSTEP:
		_accum -= SUBSTEP
		var force := -stiffness * (value - target) - damping * velocity
		velocity += force / mass * SUBSTEP
		value += velocity * SUBSTEP
	return value

func settled(eps: float = 0.001) -> bool:
	return absf(value - target) < eps and absf(velocity) < eps * 10.0
