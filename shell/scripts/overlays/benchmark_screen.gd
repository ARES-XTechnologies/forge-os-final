class_name BenchmarkScreen
extends Overlay
## Benchmarks: every recorded game session with detailed stats, a frame-time graph,
## an FPS distribution, live hardware monitor, and a stress test for the console UI.

var _runs: Array = []
var _list: RowList
var _left: GlassPanel
var _right: GlassPanel
var _title: Label
var _sub: Label
var _stats_box: Control
var _graph: Control
var _hist: Control
var _data := {}
var _prev := {}
var _side := 0
var _live := false
var _stress_t := -1.0
var _stress_ft := PackedFloat32Array()

func build() -> void:
	covers_screen = true
	from_offset = Vector2(0, 90)
	var c := Control.new()
	c.name = "content"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(1728, 830)
	add_child(c)
	_left = GlassPanel.new()
	_left.radius = 40
	_left.size = Vector2(460, 830)
	_left.body_dim = 0.45
	c.add_child(_left)
	var lt := Tokens.label("Benchmarks", 36, 700)
	lt.position = Vector2(36, 30)
	_left.add_child(lt)
	_list = RowList.new()
	_list.position = Vector2(14, 96)
	_list.size = Vector2(432, 720)
	_left.add_child(_list)
	_right = GlassPanel.new()
	_right.radius = 40
	_right.position = Vector2(490, 0)
	_right.size = Vector2(1238, 830)
	_right.body_dim = 0.45
	c.add_child(_right)
	_title = Tokens.label("", 38, 700)
	_title.position = Vector2(44, 32)
	_right.add_child(_title)
	_sub = Tokens.label("", 19, 500, Tokens.INK_DIM)
	_sub.position = Vector2(46, 86)
	_right.add_child(_sub)
	_stats_box = Control.new()
	_stats_box.position = Vector2(40, 140)
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(_stats_box)
	_graph = Control.new()
	_graph.position = Vector2(44, 462)
	_graph.size = Vector2(1150, 200)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	_right.add_child(_graph)
	_hist = Control.new()
	_hist.position = Vector2(44, 680)
	_hist.size = Vector2(1150, 120)
	_hist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hist.draw.connect(_draw_hist)
	_right.add_child(_hist)
	Metrics.want(true)
	_reload()

func _content_base() -> Vector2:
	return Vector2((size.x - 1728) * 0.5, 110)

func on_close() -> void:
	Metrics.want(false)

func _reload() -> void:
	_runs = BenchParser.list_runs(Sys.bench_dir)
	var rows: Array = [
		SettingRow.action("Live system monitor", func(): _show_live(), "gauge"),
		SettingRow.action("Console UI stress test", func(): _start_stress(), "sparkle", "20 seconds"),
		SettingRow.header("Recorded sessions"),
	]
	for r in _runs:
		var rr: Dictionary = r
		var dt := Time.get_datetime_dict_from_unix_time(rr.time)
		rows.append(SettingRow.action(rr.game if rr.game != "" else "Game", func(): _show_run(rr), "chart", "%02d/%02d %02d:%02d" % [dt.day, dt.month, dt.hour, dt.minute]))
	if _runs.is_empty():
		rows.append(SettingRow.info("No recordings yet", func(): return "", "info"))
	_list.set_rows(rows)
	_list.set_active(true)
	if _runs.is_empty():
		_show_live()
	else:
		_show_run(_runs[0])

func _show_run(r: Dictionary) -> void:
	_live = false
	_title.text = r.game if r.game != "" else "Game session"
	_sub.text = "Loading…"
	_clear_stats()
	var idx := _runs.find(r)
	var prev_path: String = ""
	for k in range(idx + 1, _runs.size()):
		if _runs[k].game == r.game:
			prev_path = _runs[k].path
			break
	var me := weakref(self)          # the screen may close before parsing finishes
	_bg.append(WorkerThreadPool.add_task(func():
		var d := BenchParser.parse(r.path)
		var p := BenchParser.parse(prev_path) if prev_path != "" else {}
		var o = me.get_ref()
		if o:
			o._parsed.call_deferred(d, p)))

func _parsed(d: Dictionary, p: Dictionary) -> void:
	_collect_bg()
	_data = d
	_prev = p
	if d.is_empty():
		_sub.text = "This recording is empty or unreadable."
		_graph.queue_redraw()
		_hist.queue_redraw()
		return
	var sys: Dictionary = d.get("sys", {})
	_sub.text = "%s  ·  %d frames  ·  %s  ·  %s" % [_fmt_dur(d.duration), d.frames, sys.get("gpu", "GPU"), sys.get("cpu", "CPU")]
	var tiles := [
		["Average", "%.0f" % d.avg_fps, "FPS", _delta(d, p, "avg_fps")],
		["1% low", "%.0f" % d.low1, "FPS", _delta(d, p, "low1")],
		["0.1% low", "%.0f" % d.low01, "FPS", _delta(d, p, "low01")],
		["Min / Max", "%.0f / %.0f" % [d.min_fps, d.max_fps], "FPS", ""],
		["Frame time", "%.2f" % d.ft_avg, "ms avg", ""],
		["99th pct", "%.2f" % d.ft_p99, "ms", ""],
		["Pacing", "%.2f" % d.jitter, "ms jitter", ""],
		["Stutters", "%d" % d.stutters, "spikes", ""],
		["GPU load", _opt(d, "gpu_load_avg", "%.0f"), "% avg", ""],
		["CPU load", _opt(d, "cpu_load_avg", "%.0f"), "% avg", ""],
		["GPU temp", _opt(d, "gpu_temp_max", "%.0f"), "°C max", ""],
		["CPU temp", _opt(d, "cpu_temp_max", "%.0f"), "°C max", ""],
		["VRAM", _opt(d, "gpu_vram_used_max", "%.1f"), "GB peak", ""],
		["GPU power", _opt(d, "gpu_power_avg", "%.0f"), "W avg", ""],
		["GPU clock", _opt(d, "gpu_core_clock_avg", "%.0f"), "MHz avg", ""],
		["RAM", _opt(d, "ram_used_max", "%.1f"), "GB peak", ""],
	]
	_fill_tiles(tiles)
	_graph.queue_redraw()
	_hist.queue_redraw()

func _opt(d: Dictionary, k: String, f: String) -> String:
	return (f % d[k]) if d.has(k) else "—"

func _delta(d: Dictionary, p: Dictionary, k: String) -> String:
	if p.is_empty() or not p.has(k) or p[k] <= 0.0:
		return ""
	var pct: float = (d[k] - p[k]) / p[k] * 100.0
	return "%+.0f%% vs last" % pct

func _fmt_dur(s: float) -> String:
	if s < 60.0:
		return "%.0f s" % s
	return "%d min %02d s" % [int(s) / 60, int(s) % 60]

func _clear_stats() -> void:
	for ch in _stats_box.get_children():
		ch.queue_free()

func _fill_tiles(tiles: Array) -> void:
	_clear_stats()
	for i in tiles.size():
		var t: Array = tiles[i]
		var card := GlassPanel.new()
		card.radius = 20
		card.bevel = 12
		card.nested = true
		card.size = Vector2(272, 66)
		card.position = Vector2((i % 4) * 290, (i / 4) * 80)
		var cap := Tokens.label(t[0].to_upper(), 13, 700, Tokens.INK_FAINT)
		cap.position = Vector2(18, 10)
		card.add_child(cap)
		var v := Tokens.label(t[1], 26, 700)
		v.position = Vector2(18, 26)
		card.add_child(v)
		var u := Tokens.label(t[2], 15, 500, Tokens.INK_DIM)
		u.position = Vector2(26 + Tokens.font(700).get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, 36)
		card.add_child(u)
		card.set_meta("v", v)
		card.set_meta("u", u)
		if t[3] != "":
			var dl := Tokens.label(t[3], 14, 600, Tokens.OK if t[3].begins_with("+") else Tokens.BAD)
			dl.position = Vector2(150, 10)
			dl.size = Vector2(110, 18)
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			card.add_child(dl)
		_stats_box.add_child(card)
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(i * 0.025)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)

func _show_live() -> void:
	_live = true
	_data = {}
	_title.text = "Live system monitor"
	_sub.text = "Updates twice a second. Paused while a game runs."
	_clear_stats()
	_graph.queue_redraw()
	_hist.queue_redraw()

func _start_stress() -> void:
	_live = false
	_title.text = "Console UI stress test"
	_sub.text = "Measuring how smoothly the interface renders. Don't touch anything…"
	_clear_stats()
	_stress_t = 0.0
	_stress_ft = PackedFloat32Array()

func _process(dt: float) -> void:
	super._process(dt)
	if _stress_t >= 0.0:
		_stress_t += dt
		_stress_ft.append(dt * 1000.0)
		# stress: spin the wallpaper fast and shake the glass
		shell.wallpaper.look_at_point(Vector2(sin(_stress_t * 3.0), cos(_stress_t * 2.0)))
		_right.focus = 0.5 + 0.5 * sin(_stress_t * 6.0)
		if _stress_t > 20.0:
			_stress_t = -1.0
			_right.focus = 0.0
			var st := BenchParser.stats(_stress_ft.slice(30))
			st.frametimes = _stress_ft
			st.duration = 20.0
			_data = st
			_sub.text = "Done. %s · %s" % [Sys.about().gpu, "%d frames" % st.frames]
			_fill_tiles([
				["Average", "%.0f" % st.avg_fps, "FPS", ""], ["1% low", "%.0f" % st.low1, "FPS", ""],
				["0.1% low", "%.0f" % st.low01, "FPS", ""], ["Frame time", "%.2f" % st.ft_avg, "ms", ""],
				["99th pct", "%.2f" % st.ft_p99, "ms", ""], ["Pacing", "%.2f" % st.jitter, "ms jitter", ""],
				["Stutters", "%d" % st.stutters, "spikes", ""], ["Verdict", "Silky" if st.low1 >= 55.0 else ("Good" if st.low1 >= 40.0 else "Heavy"), "", ""],
			])
			_save_stress(st)
			_graph.queue_redraw()
			_hist.queue_redraw()
	if _live:
		_graph.queue_redraw()
		_live_tiles()

var _live_t := 0.0
func _live_tiles() -> void:
	_live_t += get_process_delta_time()
	if _live_t < 0.5:
		return
	_live_t = 0.0
	var g := Metrics.gpu
	var gb := func(b): return "%.1f" % (float(b) / 1073741824.0) if b >= 0 else "—"
	_fill_tiles_static([
		["CPU load", "%.0f" % (Metrics.cpu_total * 100.0), "%"],
		["CPU temp", ("%.0f" % Metrics.cpu_temp) if Metrics.cpu_temp >= 0 else "—", "°C"],
		["CPU clock", "%.0f" % Metrics.cpu_mhz, "MHz"],
		["RAM", "%s / %s" % [gb.call(Metrics.ram_used), gb.call(Metrics.ram_total)], "GB"],
		["GPU load", ("%.0f" % g.load) if g.load >= 0 else "—", "%"],
		["GPU temp", ("%.0f" % g.temp) if g.temp >= 0 else "—", "°C"],
		["GPU clock", ("%.0f" % g.core_mhz) if g.core_mhz >= 0 else "—", "MHz"],
		["VRAM", "%s / %s" % [gb.call(g.vram_used), gb.call(g.vram_total)], "GB"],
		["GPU power", ("%.0f" % g.power) if g.power >= 0 else "—", "W"],
		["Fan", ("%.0f" % g.fan) if g.fan >= 0 else "—", "%"],
		["UI frame rate", "%.0f" % Metrics.shell_fps(), "FPS"],
		["Cores", "%d" % Metrics.cpu_cores.size(), "threads"],
	])

func _fill_tiles_static(tiles: Array) -> void:
	if _stats_box.get_child_count() != tiles.size():
		_fill_tiles(tiles.map(func(t): return [t[0], t[1], t[2], ""]))
		return
	for i in tiles.size():
		var card := _stats_box.get_child(i)
		var v: Label = card.get_meta("v")
		var u: Label = card.get_meta("u")
		v.text = tiles[i][1]
		u.position.x = 26 + Tokens.font(700).get_string_size(tiles[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x

func _save_stress(st: Dictionary) -> void:
	var out := {}
	for k in st:
		if k != "frametimes":
			out[k] = st[k]
	out["gpu"] = Sys.about().gpu
	out["time"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(Sys.bench_dir + "/forge_ui_stress_%d.json" % int(Time.get_unix_time_from_system()), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))

# ------------------------------------------------------------------ drawing
func _draw_graph() -> void:
	var w := _graph.size.x
	var h := _graph.size.y
	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(18)
	bg.anti_aliasing = true
	bg.bg_color = Color(0, 0, 0, 0.22)
	_graph.draw_style_box(bg, Rect2(Vector2.ZERO, _graph.size))
	var font := Tokens.font(500)
	if _live:
		_draw_live(w, h, font)
		return
	if not _data.has("frametimes"):
		return
	var ft: PackedFloat32Array = _data.frametimes
	var n := ft.size()
	var cap := maxf(_data.ft_p99 * 1.6, 20.0)
	# reference lines: 60 / 120 FPS
	for ref in [[16.67, "60 fps"], [8.33, "120 fps"]]:
		if ref[0] < cap:
			var y: float = h - 16 - (ref[0] / cap) * (h - 32)
			_graph.draw_dashed_line(Vector2(12, y), Vector2(w - 12, y), Color(1, 1, 1, 0.16), 1.5, 8.0)
			_graph.draw_string(font, Vector2(w - 80, y - 6), ref[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tokens.INK_FAINT)
	# min/max envelope per pixel column
	var cols := int(w - 24)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for x in cols:
		var a := int(float(x) / cols * n)
		var b := maxi(a + 1, int(float(x + 1) / cols * n))
		var mn := INF
		var mx := 0.0
		for i in range(a, mini(b, n)):
			mn = minf(mn, ft[i])
			mx = maxf(mx, ft[i])
		var px := 12.0 + x
		top.append(Vector2(px, h - 16 - clampf(mx / cap, 0, 1) * (h - 32)))
		bot.append(Vector2(px, h - 16 - clampf(mn / cap, 0, 1) * (h - 32)))
	var poly := top.duplicate()
	var rb := bot.duplicate()
	rb.reverse()
	poly.append_array(rb)
	if poly.size() >= 3:
		_graph.draw_colored_polygon(poly, Color(Tokens.ACCENT, 0.22))
	_graph.draw_polyline(top, Tokens.ACCENT, 2.0, true)
	_graph.draw_string(font, Vector2(16, 26), "FRAME TIME (ms) — lower and flatter is better", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tokens.INK_FAINT)

func _draw_live(w: float, h: float, font: Font) -> void:
	var cores := Metrics.cpu_cores
	if cores.is_empty():
		_graph.draw_string(font, Vector2(16, 30), "Waiting for data…", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Tokens.INK_DIM)
		return
	_graph.draw_string(font, Vector2(16, 26), "CPU THREADS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tokens.INK_FAINT)
	var bw := (w - 32) / cores.size()
	for i in cores.size():
		var v := cores[i]
		var bh := (h - 56) * v
		var r := Rect2(Vector2(16 + i * bw + 2, h - 14 - bh), Vector2(bw - 4, bh))
		_graph.draw_rect(r, Tokens.ACCENT.lerp(Tokens.BAD, clampf((v - 0.6) / 0.4, 0, 1)))

func _draw_hist() -> void:
	var w := _hist.size.x
	var h := _hist.size.y
	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(18)
	bg.anti_aliasing = true
	bg.bg_color = Color(0, 0, 0, 0.22)
	_hist.draw_style_box(bg, Rect2(Vector2.ZERO, _hist.size))
	var font := Tokens.font(500)
	if _live:
		var ms := Metrics.frame_ms
		var pts := PackedVector2Array()
		for i in ms.size():
			pts.append(Vector2(12 + i * (w - 24) / ms.size(), h - 12 - clampf(ms[i] / 33.3, 0, 1) * (h - 40)))
		_hist.draw_polyline(pts, Tokens.ACCENT_2, 2.0, true)
		_hist.draw_string(font, Vector2(16, 24), "CONSOLE UI FRAME TIME", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tokens.INK_FAINT)
		return
	if not _data.has("frametimes"):
		return
	# FPS distribution: how much of the session was spent at each frame rate
	var ft: PackedFloat32Array = _data.frametimes
	var buckets := 48
	var maxfps := maxf(_data.max_fps, 60.0)
	maxfps = minf(maxfps, 360.0)
	var counts := PackedFloat32Array()
	counts.resize(buckets)
	for v in ft:
		var fps := 1000.0 / v
		var b := clampi(int(fps / maxfps * buckets), 0, buckets - 1)
		counts[b] += v
	var mx := 0.0
	for c in counts:
		mx = maxf(mx, c)
	var bw := (w - 24) / buckets
	for i in buckets:
		var bh := (h - 44) * (counts[i] / maxf(mx, 0.001))
		_hist.draw_rect(Rect2(Vector2(12 + i * bw + 1, h - 14 - bh), Vector2(bw - 2, bh)), Tokens.ACCENT_2.lerp(Tokens.ACCENT, float(i) / buckets))
	_hist.draw_string(font, Vector2(16, 24), "TIME SPENT AT EACH FPS  (0 → %.0f)" % maxfps, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tokens.INK_FAINT)

func nav_action(a: StringName) -> bool:
	if a == &"back":
		close()
		return true
	_list.handle(a)
	return true

func hints() -> Array:
	return [["A", "Open"], ["B", "Back"]]


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
