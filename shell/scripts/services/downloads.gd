extends Node
## Download manager: watches Steam's download folders to show live progress, speed and
## time left for every game that's installing or updating, and announces when it's ready.
## (Pausing and reordering happen in Steam's own downloads window, which FORGE can open.)

signal changed()

var items: Array = []         # [{appid, name, done, total, progress, speed, eta}]
var _last := {}               # appid -> [bytes, msec]
var _speed := {}              # appid -> smoothed bytes/s
var _was_updating := {}
var _t := 0.0
var _busy := false

func _ready() -> void:
	SteamLib.library_changed.connect(_on_library)

func active_count() -> int:
	return items.size()

func _on_library() -> void:
	var now_updating := {}
	for g in SteamLib.games:
		if g.get("source", "steam") == "steam" and g.get("updating", false):
			now_updating[g.appid] = true
	for id in _was_updating:
		if not now_updating.has(id):
			var g: Dictionary = SteamLib.by_id.get(id, {})
			if g.get("installed", false):
				Shellbus.notify({"title": "Ready to play", "body": str(g.get("name", "Your game")) + " finished downloading", "icon": "check", "color": Tokens.OK, "appid": id, "sound": "notify"})
	_was_updating = now_updating
	_sample()

func _process(dt: float) -> void:
	_t += dt
	if _t >= 2.0 and not _was_updating.is_empty() and not _busy and not Session.is_playing():
		_t = 0.0
		_sample()

func _sample() -> void:
	if SteamLib.root == "":
		return
	var targets := []
	for g in SteamLib.games:
		if g.get("source", "steam") == "steam" and g.get("updating", false):
			var dir: String = str(g.library) + "/steamapps/downloading/" + str(g.appid)
			targets.append({"appid": g.appid, "name": g.name, "total": int(g.get("bytes_total", 0)), "dir": dir, "progress": float(g.get("progress", 0.0))})
	if targets.is_empty():
		if not items.is_empty():
			items = []
			changed.emit()
		return
	_busy = true
	var me := weakref(self)
	_bg.append(WorkerThreadPool.add_task(func():
		for t in targets:
			var out := []
			if DirAccess.dir_exists_absolute(t.dir):
				OS.execute("du", PackedStringArray(["-sb", t.dir]), out)
			var b := 0
			if not out.is_empty():
				var p := str(out[0]).split("\t")
				if p.size() > 0 and p[0].is_valid_int():
					b = int(p[0])
			t["bytes"] = b
		var o = me.get_ref()
		if o:
			o._done.call_deferred(targets)))

func _done(targets: Array) -> void:
	_collect_bg()
	_busy = false
	var now := Time.get_ticks_msec()
	var list := []
	for t in targets:
		var id: int = t.appid
		var b: int = t.bytes
		var total: int = t.total
		if _last.has(id):
			var prev: Array = _last[id]
			var dt := maxf(0.001, (now - int(prev[1])) / 1000.0)
			var inst := maxf(0.0, (b - int(prev[0])) / dt)
			_speed[id] = lerpf(float(_speed.get(id, inst)), inst, 0.35)
		_last[id] = [b, now]
		var progress: float = t.progress
		if total > 0 and b > 0:
			progress = clampf(float(b) / total, 0.0, 1.0)
		var spd: float = _speed.get(id, 0.0)
		var eta := -1
		if spd > 1024.0 and total > 0:
			eta = int(maxf(0.0, total - b) / spd)
		list.append({"appid": id, "name": t.name, "done": b, "total": total, "progress": progress, "speed": spd, "eta": eta})
	items = list
	changed.emit()

static func fmt_speed(bps: float) -> String:
	if bps <= 0.0:
		return "Waiting…"
	if bps >= 1048576.0:
		return "%.1f MB/s" % (bps / 1048576.0)
	return "%.0f KB/s" % (bps / 1024.0)

static func fmt_eta(s: int) -> String:
	if s < 0:
		return ""
	if s < 60:
		return "less than a minute"
	if s < 3600:
		return "%d min left" % (s / 60)
	return "%dh %02dm left" % [s / 3600, (s % 3600) / 60]


# ------------------------------------------------------------------ background tasks
## Godot needs every background task collected once it's done, or quitting crashes the
## engine. Finished ones are collected as results arrive; the rest on exit.
var _bg: Array = []

func _collect_bg() -> void:
	for t in _bg.duplicate():
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
			_bg.erase(t)

func _exit_tree() -> void:
	for t in _bg:
		TaskWait.on_exit(t)
	_bg.clear()
