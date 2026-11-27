extends Node
## Live hardware metrics: per-core CPU load, CPU temp, RAM, GPU load/temp/clocks/VRAM/power.
## Sampling only runs while something on screen asks for it (ref-counted), and never
## while a game is running, so it costs nothing when you're playing.

signal sampled()

var cpu_total := 0.0
var cpu_cores: PackedFloat32Array = []
var cpu_temp := -1.0
var cpu_mhz := 0.0
var ram_used := 0
var ram_total := 0
var gpu := {"load": -1.0, "temp": -1.0, "core_mhz": -1.0, "mem_mhz": -1.0, "vram_used": -1, "vram_total": -1, "power": -1.0, "fan": -1.0, "vendor": ""}
var frame_ms := PackedFloat32Array()   # shell frame times, ring buffer
const FRAME_HISTORY := 240

var _users := 0
var _t := 0.0
var _prev_stat := {}
var _gpu_busy := false
var _amd_dir := ""
var _hwmon_cpu := ""

func _ready() -> void:
	frame_ms.resize(FRAME_HISTORY)
	_detect()

func want(on: bool) -> void:
	_users = maxi(0, _users + (1 if on else -1))

func _process(dt: float) -> void:
	frame_ms.remove_at(0)
	frame_ms.append(dt * 1000.0)
	if _users <= 0 or SteamLib.is_running():
		return
	_t += dt
	if _t >= 0.5:
		_t = 0.0
		_sample()

func shell_fps() -> float:
	var s := 0.0
	var n := 0
	for i in range(FRAME_HISTORY - 60, FRAME_HISTORY):
		if frame_ms[i] > 0.0:
			s += frame_ms[i]
			n += 1
	return 0.0 if s <= 0.0 else 1000.0 * n / s

func _detect() -> void:
	if not Sys.is_linux:
		return
	var d := DirAccess.open("/sys/class/drm")
	if d:
		for e in d.get_directories():
			if e.begins_with("card") and not e.contains("-"):
				var dev := "/sys/class/drm/%s/device" % e
				var vendor := Sys.read_text(dev + "/vendor").strip_edges()
				if vendor == "0x1002" and FileAccess.file_exists(dev + "/gpu_busy_percent"):
					_amd_dir = dev
					gpu.vendor = "AMD"
				elif vendor == "0x10de":
					gpu.vendor = "NVIDIA"
				elif vendor == "0x8086" and gpu.vendor == "":
					gpu.vendor = "Intel"
	var hw := DirAccess.open("/sys/class/hwmon")
	if hw:
		for h in hw.get_directories():
			var name := Sys.read_text("/sys/class/hwmon/%s/name" % h).strip_edges()
			if name in ["k10temp", "coretemp", "zenpower", "cpu_thermal"]:
				_hwmon_cpu = "/sys/class/hwmon/" + h
				break

func _sample() -> void:
	_sample_cpu()
	_sample_ram()
	if gpu.vendor == "AMD":
		_sample_amd()
	elif gpu.vendor == "NVIDIA" and not _gpu_busy and Sys.has_cmd("nvidia-smi"):
		_gpu_busy = true
		Sys.run("nvidia-smi", ["--query-gpu=utilization.gpu,temperature.gpu,clocks.gr,clocks.mem,memory.used,memory.total,power.draw,fan.speed", "--format=csv,noheader,nounits"], func(t: String, c: int):
			_gpu_busy = false
			if c == 0:
				var p := t.strip_edges().split(",")
				if p.size() >= 8:
					gpu.load = _num(p[0]); gpu.temp = _num(p[1]); gpu.core_mhz = _num(p[2]); gpu.mem_mhz = _num(p[3])
					gpu.vram_used = int(_num(p[4]) * 1048576.0); gpu.vram_total = int(_num(p[5]) * 1048576.0)
					gpu.power = _num(p[6]); gpu.fan = _num(p[7]))
	sampled.emit()

func _num(s: String) -> float:
	s = s.strip_edges()
	return float(s) if s.is_valid_float() or s.is_valid_int() else -1.0

func _sample_cpu() -> void:
	var cores := PackedFloat32Array()
	for line in Sys.read_text("/proc/stat").split("\n", false):
		if not line.begins_with("cpu"):
			break
		var p := line.split(" ", false)
		var idle := float(p[4]) + float(p[5])
		var total := 0.0
		for i in range(1, mini(p.size(), 9)):
			total += float(p[i])
		var key := p[0]
		var load := 0.0
		if _prev_stat.has(key):
			var dt: float = total - _prev_stat[key].x
			var di: float = idle - _prev_stat[key].y
			load = 0.0 if dt <= 0.0 else clampf(1.0 - di / dt, 0.0, 1.0)
		_prev_stat[key] = Vector2(total, idle)
		if key == "cpu":
			cpu_total = load
		else:
			cores.append(load)
	cpu_cores = cores
	if _hwmon_cpu != "":
		var t := Sys.read_text(_hwmon_cpu + "/temp1_input").strip_edges()
		if t.is_valid_int():
			cpu_temp = int(t) / 1000.0
	var mhz := Sys.read_text("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq").strip_edges()
	if mhz.is_valid_int():
		cpu_mhz = int(mhz) / 1000.0

func _sample_ram() -> void:
	var total := 0
	var avail := 0
	for line in Sys.read_text("/proc/meminfo").split("\n", false):
		if line.begins_with("MemTotal:"):
			total = int(line.split(" ", false)[1]) * 1024
		elif line.begins_with("MemAvailable:"):
			avail = int(line.split(" ", false)[1]) * 1024
	ram_total = total
	ram_used = total - avail

func _sample_amd() -> void:
	var b := Sys.read_text(_amd_dir + "/gpu_busy_percent").strip_edges()
	gpu.load = float(b) if b.is_valid_int() else -1.0
	var vu := Sys.read_text(_amd_dir + "/mem_info_vram_used").strip_edges()
	var vt := Sys.read_text(_amd_dir + "/mem_info_vram_total").strip_edges()
	gpu.vram_used = int(vu) if vu.is_valid_int() else -1
	gpu.vram_total = int(vt) if vt.is_valid_int() else -1
	gpu.core_mhz = _amd_clock(_amd_dir + "/pp_dpm_sclk")
	gpu.mem_mhz = _amd_clock(_amd_dir + "/pp_dpm_mclk")
	var hw := DirAccess.open(_amd_dir + "/hwmon")
	if hw:
		for h in hw.get_directories():
			var base := _amd_dir + "/hwmon/" + h
			var t := Sys.read_text(base + "/temp1_input").strip_edges()
			if t.is_valid_int(): gpu.temp = int(t) / 1000.0
			var pw := Sys.read_text(base + "/power1_average").strip_edges()
			if not pw.is_valid_int(): pw = Sys.read_text(base + "/power1_input").strip_edges()
			if pw.is_valid_int(): gpu.power = int(pw) / 1000000.0
			break

func _amd_clock(path: String) -> float:
	for line in Sys.read_text(path).split("\n", false):
		if line.ends_with("*"):
			var p := line.split(" ", false)
			if p.size() >= 2:
				return float(p[1].trim_suffix("Mhz").trim_suffix("MHz"))
	return -1.0
