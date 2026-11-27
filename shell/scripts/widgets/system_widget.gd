class_name SystemWidget
extends GlassWidget
## CPU, GPU and RAM rings that fill on springs.

var _cpu: Spring
var _gpu: Spring
var _ram: Spring

func setup() -> void:
	size = Vector2(522, 170)
	span = 2
	_cpu = Spring.preset(0.0, &"smooth")
	_gpu = Spring.preset(0.0, &"smooth")
	_ram = Spring.preset(0.0, &"smooth")
	Metrics.want(true)
	tree_exiting.connect(func(): Metrics.want(false))

func tick_rate() -> float: return 0.5

func update() -> void:
	_cpu.target = Metrics.cpu_total
	_gpu.target = maxf(0.0, Metrics.gpu.load / 100.0)
	_ram.target = 0.0 if Metrics.ram_total <= 0 else float(Metrics.ram_used) / Metrics.ram_total

func _paint() -> void:
	caption("System")
	var d := get_process_delta_time()
	var vals := [[_cpu.step(d), "CPU", Tokens.ACCENT], [_gpu.step(d), "GPU", Tokens.ACCENT_2], [_ram.step(d), "RAM", Tokens.OK]]
	for i in 3:
		var cx := 92.0 + i * 170.0
		ring(Vector2(cx, 100), 38, vals[i][0], vals[i][2])
		text("%d%%" % int(clampf(vals[i][0], 0, 1) * 100.0), Vector2(cx - 40, 107), 20, 600, Tokens.INK, HORIZONTAL_ALIGNMENT_CENTER, 80)
		text(vals[i][1], Vector2(cx + 48, 106), 15, 700, Tokens.INK_DIM)
