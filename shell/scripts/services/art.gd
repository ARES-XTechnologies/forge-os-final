extends Node
## Game artwork: portrait covers, hero backdrops, logos and headers.
## Order of lookup:
##   1. Custom art the user set in Steam (userdata/<id>/config/grid)
##   2. Steam's local library cache (appcache/librarycache) — no network
##   3. One-time download from Steam's public image CDN, then cached forever
## Images decode on worker threads so scrolling never hitches.

signal art_ready(appid: int, kind: String)
signal url_ready(url: String)

## Art for non-Steam games (Epic/GOG/RetroArch) comes from URLs or local files.
var _custom := {}      # appid -> {kind: url_or_path}
var _url_tex := {}     # url -> Texture2D
var _url_state := {}   # url -> "loading" | "missing"
var colors := {}       # appid -> dominant Color of its art (for dynamic themes)

const KINDS := {
	"portrait": {"files": ["library_600x900.jpg", "library_600x900_2x.jpg", "library_capsule.jpg"], "grid": "%dp", "max": Vector2i(460, 690)},
	"hero": {"files": ["library_hero.jpg", "library_hero_blur.jpg"], "grid": "%d_hero", "max": Vector2i(1920, 620)},
	"logo": {"files": ["logo.png"], "grid": "%d_logo", "max": Vector2i(800, 400)},
	"header": {"files": ["header.jpg", "capsule_616x353.jpg"], "grid": "%d", "max": Vector2i(616, 353)},
}
const CDN := [
	"https://shared.steamstatic.com/store_item_assets/steam/apps/%d/%s",
	"https://cdn.cloudflare.steamstatic.com/steam/apps/%d/%s",
]
const CACHE := "user://art"

var _tex := {}         # "appid:kind" -> Texture2D
var _state := {}       # "appid:kind" -> "loading" | "missing" | "ok"
var _queue: Array = [] # download jobs
var _active := 0
const MAX_DL := 4

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))

func get_tex(appid: int, kind: String) -> Texture2D:
	var key := "%d:%s" % [appid, kind]
	if _tex.has(key):
		return _tex[key]
	var st: String = _state.get(key, "")
	if st == "" or (st.begins_with("retry:") and Time.get_ticks_msec() - int(st.substr(6)) > 60000):
		_state[key] = "loading"
		_resolve(appid, kind)
	return null

func is_missing(appid: int, kind: String) -> bool:
	return _state.get("%d:%s" % [appid, kind], "") == "missing"

func register(appid: int, sources: Dictionary) -> void:
	_custom[appid] = sources

## Drop everything loaded for a game (its art was changed) and tell the screens, so the new
## art shows straight away instead of the old cached picture.
func forget(appid: int) -> void:
	for kind in KINDS:
		var key := "%d:%s" % [appid, kind]
		_tex.erase(key)
		_state.erase(key)
	colors.erase(appid)
	for kind in KINDS:
		art_ready.emit(appid, kind)

func _resolve(appid: int, kind: String) -> void:
	if _custom.has(appid):
		var src: String = (_custom[appid] as Dictionary).get(kind, "")
		if src == "":
			_state["%d:%s" % [appid, kind]] = "missing"
			art_ready.emit.call_deferred(appid, kind)
			return
		if src.begins_with("http"):
			var cached := _url_cache_path(src)
			if FileAccess.file_exists(cached):
				_load_async(appid, kind, cached)
			else:
				_fetch_url(src, func(ok: bool):
					if ok:
						_load_async(appid, kind, cached)
					else:
						_state["%d:%s" % [appid, kind]] = "missing"
						art_ready.emit(appid, kind))
		else:
			_load_async(appid, kind, src)
		return
	var local := _find_local(appid, kind)
	if local != "":
		_load_async(appid, kind, local)
		return
	var cached := ProjectSettings.globalize_path("%s/%d_%s" % [CACHE, appid, kind])
	for ext in [".jpg", ".png"]:
		if FileAccess.file_exists(cached + ext):
			_load_async(appid, kind, cached + ext)
			return
	if FileAccess.file_exists(cached + ".missing"):
		_state["%d:%s" % [appid, kind]] = "missing"
		return
	_queue.append({"appid": appid, "kind": kind, "try": 0})
	_pump()

func _find_local(appid: int, kind: String) -> String:
	var root: String = SteamLib.root
	if root == "":
		return ""
	var spec: Dictionary = KINDS[kind]
	# 1. user's custom grid art
	var ud := DirAccess.open(root + "/userdata")
	if ud:
		for u in ud.get_directories():
			var g: String = root + "/userdata/" + u + "/config/grid/" + (str(spec.grid) % appid)
			for ext in [".png", ".jpg", ".jpeg", ".webp"]:
				if FileAccess.file_exists(g + ext):
					return g + ext
	# 2. librarycache, old flat layout
	var lc := root + "/appcache/librarycache"
	for f in spec.files:
		var p := "%s/%d_%s" % [lc, appid, f]
		if FileAccess.file_exists(p):
			return p
	# 3. librarycache, new per-app folder layout (may contain hashed sub-folders)
	var dir := lc + "/" + str(appid)
	if DirAccess.dir_exists_absolute(dir):
		for f in spec.files:
			var found := _find_in(dir, f, 2)
			if found != "":
				return found
	return ""

func _find_in(dir: String, file: String, depth: int) -> String:
	if FileAccess.file_exists(dir + "/" + file):
		return dir + "/" + file
	if depth <= 0:
		return ""
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	for sub in d.get_directories():
		var r := _find_in(dir + "/" + sub, file, depth - 1)
		if r != "":
			return r
	return ""

func _load_async(appid: int, kind: String, path: String) -> void:
	var maxs: Vector2i = KINDS[kind].max
	var me := weakref(self)          # FORGE may quit mid-load: never call back into a freed node
	_bg.append(WorkerThreadPool.add_task(func():
		var img := Image.new()
		var err := img.load(path)
		var o0 = me.get_ref()
		if err != OK or img.is_empty():
			if o0:
				o0._loaded.call_deferred(appid, kind, null)
			return
		if img.get_width() > maxs.x or img.get_height() > maxs.y:
			var s := minf(float(maxs.x) / img.get_width(), float(maxs.y) / img.get_height())
			img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		var o = me.get_ref()
		if o:
			o._loaded.call_deferred(appid, kind, img)))

func _loaded(appid: int, kind: String, img: Image) -> void:
	_collect_bg()
	var key := "%d:%s" % [appid, kind]
	if img != null and (kind == "portrait" or (kind == "hero" and not colors.has(appid))):
		colors[appid] = _dominant(img)
	if img == null:
		_state[key] = "missing"
		art_ready.emit(appid, kind)
		return
	_tex[key] = ImageTexture.create_from_image(img)
	_state[key] = "ok"
	art_ready.emit(appid, kind)

# ------------------------------------------------------------------ downloads
func _pump() -> void:
	while _active < MAX_DL and not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		_download(job)

func _download(job: Dictionary) -> void:
	var spec: Dictionary = KINDS[job.kind]
	var urls := []
	for base in CDN:
		for f in spec.files:
			urls.append(base % [job.appid, f])
	if job.try >= urls.size():
		var miss := ProjectSettings.globalize_path("%s/%d_%s.missing" % [CACHE, job.appid, job.kind])
		var mf := FileAccess.open(miss, FileAccess.WRITE)
		if mf: mf.store_string(str(Time.get_unix_time_from_system()))
		_state["%d:%s" % [job.appid, job.kind]] = "missing"
		art_ready.emit(job.appid, job.kind)
		return
	_active += 1
	var url: String = urls[job.try]
	var req := HTTPRequest.new()
	req.timeout = 12.0
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body: PackedByteArray):
		req.queue_free()
		_active -= 1
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 512:
			var ext := ".png" if url.ends_with(".png") else ".jpg"
			var out := ProjectSettings.globalize_path("%s/%d_%s%s" % [CACHE, job.appid, job.kind, ext])
			var f := FileAccess.open(out, FileAccess.WRITE)
			if f:
				f.store_buffer(body)
				f.close()
				_load_async(job.appid, job.kind, out)
		elif result != HTTPRequest.RESULT_SUCCESS and job.try == 0:
			# Offline: try again in a minute, without marking the art as missing.
			_state["%d:%s" % [job.appid, job.kind]] = "retry:%d" % Time.get_ticks_msec()
		else:
			job.try += 1
			_queue.push_front(job)
		_pump())
	if req.request(url) != OK:
		req.queue_free()
		_active -= 1
		job.try += 1
		_queue.push_front(job)
		_pump.call_deferred()

# ------------------------------------------------------------------ dominant colour
## Most vivid average colour of an image: what the dynamic theme tints the world with.
func _dominant(img: Image) -> Color:
	var small := img.duplicate() as Image
	if small.has_mipmaps():
		small.clear_mipmaps()
	small.resize(24, 24, Image.INTERPOLATE_BILINEAR)
	var acc := Color(0, 0, 0)
	var wsum := 0.0
	for y in 24:
		for x in 24:
			var c := small.get_pixel(x, y)
			var w := c.s * c.s * (0.2 + c.v)
			acc += c * w
			wsum += w
	if wsum <= 0.001:
		return Tokens.ACCENT
	var out := acc / wsum
	return Color.from_hsv(out.h, clampf(out.s * 1.2, 0.35, 0.9), clampf(out.v * 1.3, 0.6, 1.0))

# ------------------------------------------------------------------ any URL (achievement icons etc.)
func _url_cache_path(url: String) -> String:
	var ext := ".png" if url.to_lower().ends_with(".png") else ".jpg"
	return ProjectSettings.globalize_path("%s/url_%s%s" % [CACHE, url.md5_text(), ext])

func get_url_tex(url: String) -> Texture2D:
	if url == "":
		return null
	if _url_tex.has(url):
		return _url_tex[url]
	if _url_state.has(url):
		return null
	_url_state[url] = "loading"
	var path := _url_cache_path(url)
	if FileAccess.file_exists(path):
		_load_url_file(url, path)
	else:
		_fetch_url(url, func(ok: bool):
			if ok:
				_load_url_file(url, path)
			else:
				_url_state[url] = "missing")
	return null

func _load_url_file(url: String, path: String) -> void:
	var me := weakref(self)
	_bg.append(WorkerThreadPool.add_task(func():
		var img := Image.new()
		var ok := img.load(path) == OK
		if ok:
			img.generate_mipmaps()
		var o = me.get_ref()
		if o:
			o._url_loaded.call_deferred(url, img if ok else null)))

func _url_loaded(url: String, img: Image) -> void:
	_collect_bg()
	if img:
		_url_tex[url] = ImageTexture.create_from_image(img)
		_url_state.erase(url)
		url_ready.emit(url)
	else:
		_url_state[url] = "missing"

func _fetch_url(url: String, cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body: PackedByteArray):
		req.queue_free()
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 256
		if ok:
			var f := FileAccess.open(_url_cache_path(url), FileAccess.WRITE)
			if f:
				f.store_buffer(body)
				f.close()
			else:
				ok = false
		cb.call(ok))
	if req.request(url) != OK:
		req.queue_free()
		cb.call(false)


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
