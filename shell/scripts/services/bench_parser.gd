class_name BenchParser
extends RefCounted
## Reads MangoHud CSV logs and computes detailed benchmark statistics.

static func list_runs(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".csv") and not f.ends_with("_summary.csv"):
			var p := dir + "/" + f
			out.append({"path": p, "file": f, "time": FileAccess.get_modified_time(p), "game": _game_from_name(f)})
	out.sort_custom(func(a, b): return a.time > b.time)
	return out

static func _game_from_name(f: String) -> String:
	# MangoHud names logs "<exe>_<YYYY-MM-DD>_<HH-MM-SS>.csv"
	var base := f.trim_suffix(".csv")
	var parts := base.split("_")
	var keep := []
	for p in parts:
		if p.length() >= 8 and p[4] == "-" and p.substr(0, 4).is_valid_int():
			break
		keep.append(p)
	var n := "_".join(keep)
	return n.trim_suffix(".exe").replace("-", " ").replace("Win64", "").replace("Shipping", "").strip_edges()

static func parse(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var lines := f.get_as_text().split("\n", false)
	var sysinfo := {}
	var header := PackedStringArray()
	var start := -1
	for i in mini(lines.size(), 12):
		if lines[i].begins_with("os,") and i + 1 < lines.size():
			var keys := lines[i].split(",")
			var vals := lines[i + 1].split(",")
			for k in keys.size():
				sysinfo[keys[k]] = vals[k] if k < vals.size() else ""
		if lines[i].find("frametime") != -1 and lines[i].find(",") != -1:
			header = lines[i].split(",")
			start = i + 1
			break
	if start < 0:
		return {}
	var col := {}
	for i in header.size():
		col[header[i].strip_edges()] = i
	var ft := PackedFloat32Array()
	var series := {"cpu_load": [], "gpu_load": [], "cpu_temp": [], "gpu_temp": [], "gpu_core_clock": [],
		"gpu_vram_used": [], "gpu_power": [], "cpu_power": [], "ram_used": []}
	var elapsed_last := 0.0
	for i in range(start, lines.size()):
		var p := lines[i].split(",")
		if p.size() < header.size() - 1:
			continue
		var t := float(p[col.get("frametime", 1)])
		if t <= 0.0:
			continue
		ft.append(t)
		for k in series:
			if col.has(k) and col[k] < p.size():
				(series[k] as Array).append(float(p[col[k]]))
		if col.has("elapsed"):
			elapsed_last = float(p[col.elapsed])
	if ft.is_empty():
		return {}
	var r := stats(ft)
	r.sys = sysinfo
	r.frametimes = ft
	for k in series:
		var s: Array = series[k]
		if s.size() > 0:
			var sum := 0.0
			var mx := -INF
			for v in s:
				sum += v
				mx = maxf(mx, v)
			r[k + "_avg"] = sum / s.size()
			r[k + "_max"] = mx
	var total_ms := 0.0
	for v in ft:
		total_ms += v
	r.duration = elapsed_last / 1e9 if elapsed_last > 1e6 else total_ms / 1000.0
	return r

static func stats(ft: PackedFloat32Array) -> Dictionary:
	var n := ft.size()
	var sorted := ft.duplicate()
	sorted.sort()
	var sum := 0.0
	for v in ft:
		sum += v
	var mean := sum / n
	var median := sorted[n / 2]
	var worst := func(frac: float) -> float:
		var k := maxi(1, int(n * frac))
		var s := 0.0
		for i in range(n - k, n):
			s += sorted[i]
		return s / k
	var p := func(q: float) -> float: return sorted[clampi(int(q * (n - 1)), 0, n - 1)]
	# frame pacing: average absolute change between consecutive frames
	var jitter := 0.0
	var stutters := 0
	for i in range(1, n):
		jitter += absf(ft[i] - ft[i - 1])
		if ft[i] > median * 2.0 and ft[i] > 8.0:
			stutters += 1
	jitter /= maxf(1.0, n - 1)
	var var_sum := 0.0
	for v in ft:
		var_sum += (v - mean) * (v - mean)
	return {
		"frames": n,
		"avg_fps": 1000.0 / mean,
		"low1": 1000.0 / worst.call(0.01),
		"low01": 1000.0 / worst.call(0.001),
		"min_fps": 1000.0 / sorted[n - 1],
		"max_fps": 1000.0 / sorted[0],
		"ft_avg": mean,
		"ft_p50": median,
		"ft_p95": p.call(0.95),
		"ft_p99": p.call(0.99),
		"ft_std": sqrt(var_sum / n),
		"jitter": jitter,
		"stutters": stutters,
	}
