extends Node
## Steam Web API: owned games (installed or not) and per-game achievements.
## Needs the player's own free Web API key (Settings › Library). The SteamID comes
## from the account signed in to Steam on this console, so nothing else is asked for.
## While a Steam game runs, achievements are polled so unlocks pop up as notifications.

signal owned_changed()
signal achievements_ready(appid: int)

const API := "https://api.steampowered.com"
var owned: Array = []                 # [{appid, name, playtime, last_played, icon}]
var _ach := {}                        # appid -> {time_ms, data}
var _poll_t := 0.0
var _poll_known := {}                 # apiname -> true for the running game

func _ready() -> void:
	_load_cache()
	Config.changed.connect(func(k):
		if k == "steam.api_key":
			refresh_owned())
	Session.started.connect(func(g):
		_poll_known.clear()
		if g.get("source", "steam") == "steam" and has_key():
			achievements(int(g.appid), func(d): _seed_known(d), true))
	await get_tree().create_timer(4.0).timeout
	refresh_owned()

func has_key() -> bool:
	return Config.get_s("steam.api_key").strip_edges().length() >= 20

func steam_id() -> String:
	return GameSettings.current_steam_id()

func _cache_path() -> String:
	return "user://owned_games.json"

func _load_cache() -> void:
	if FileAccess.file_exists(_cache_path()):
		var p = JSON.parse_string(FileAccess.get_file_as_string(_cache_path()))
		if p is Array:
			owned = p

# ------------------------------------------------------------------ HTTP
func _get_json(url: String, cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			cb.call(null, code)
			return
		cb.call(JSON.parse_string(body.get_string_from_utf8()), code))
	if req.request(url) != OK:
		req.queue_free()
		cb.call(null, 0)

# ------------------------------------------------------------------ owned games
func refresh_owned() -> void:
	if not has_key() or steam_id() == "":
		return
	var url := "%s/IPlayerService/GetOwnedGames/v1/?key=%s&steamid=%s&include_appinfo=1&include_played_free_games=1&format=json" % [API, Config.get_s("steam.api_key").strip_edges(), steam_id()]
	_get_json(url, func(data, code):
		if data == null:
			if code == 401 or code == 403:
				Shellbus.notify({"title": "Steam key didn't work", "body": "Check the Web API key in Settings › Library.", "icon": "steam", "color": Tokens.BAD})
			return
		var games = VDF.dig(data, ["response", "games"], [])
		if not (games is Array):
			# empty response = private game details on the Steam profile
			Shellbus.notify({"title": "Your Steam game list is private", "body": "Set Steam › Privacy › Game details to Public to see games you haven't installed.", "icon": "steam", "color": Tokens.WARN, "duration": 7.0})
			return
		var list := []
		for g in games:
			list.append({"appid": int(g.get("appid", 0)), "name": str(g.get("name", "")),
				"playtime": int(g.get("playtime_forever", 0)), "last_played": int(g.get("rtime_last_played", 0))})
		owned = list
		var f := FileAccess.open(_cache_path(), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(list))
		owned_changed.emit())

# ------------------------------------------------------------------ achievements
## cb(data) where data = {total, unlocked, list:[...]} or {} if unavailable.
func achievements(appid: int, cb: Callable, force := false) -> void:
	if not has_key():
		cb.call({})
		return
	var c: Dictionary = _ach.get(appid, {})
	if not force and not c.is_empty() and Time.get_ticks_msec() - int(c.time_ms) < 300000:
		cb.call(c.data)
		return
	var key := Config.get_s("steam.api_key").strip_edges()
	var sid := steam_id()
	var res := {"schema": null, "player": null, "global": null, "left": 3}
	var done := func():
		res.left -= 1
		if res.left > 0:
			return
		var data := _merge(res)
		_ach[appid] = {"time_ms": Time.get_ticks_msec(), "data": data}
		cb.call(data)
		achievements_ready.emit(appid)
	_get_json("%s/ISteamUserStats/GetSchemaForGame/v2/?key=%s&appid=%d&l=english" % [API, key, appid], func(d, _c):
		res.schema = d
		done.call())
	_get_json("%s/ISteamUserStats/GetPlayerAchievements/v1/?key=%s&steamid=%s&appid=%d&l=english" % [API, key, sid, appid], func(d, _c):
		res.player = d
		done.call())
	_get_json("%s/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=%d" % [API, appid], func(d, _c):
		res.global = d
		done.call())

func _merge(res: Dictionary) -> Dictionary:
	var schema = VDF.dig(res.schema, ["game", "availablegamestats", "achievements"], null)
	if schema == null and res.schema is Dictionary:
		schema = ((res.schema.get("game", {}) as Dictionary).get("availableGameStats", {}) as Dictionary).get("achievements", null)
	if not (schema is Array) or schema.is_empty():
		return {}
	var mine := {}
	if res.player is Dictionary:
		var ps = (res.player.get("playerstats", {}) as Dictionary).get("achievements", [])
		if ps is Array:
			for a in ps:
				mine[str(a.get("apiname", ""))] = a
	var pct := {}
	if res.global is Dictionary:
		var gs = (res.global.get("achievementpercentages", {}) as Dictionary).get("achievements", [])
		if gs is Array:
			for a in gs:
				pct[str(a.get("name", ""))] = float(a.get("percent", 0.0))
	var list := []
	var unlocked := 0
	for a in schema:
		var api := str(a.get("name", ""))
		var m: Dictionary = mine.get(api, {})
		var got := int(m.get("achieved", 0)) == 1
		if got:
			unlocked += 1
		list.append({"api": api, "name": str(a.get("displayName", api)), "desc": str(a.get("description", "")),
			"icon": str(a.get("icon", "")), "icon_gray": str(a.get("icongray", "")), "hidden": int(a.get("hidden", 0)) == 1,
			"achieved": got, "time": int(m.get("unlocktime", 0)), "percent": float(pct.get(api, -1.0))})
	list.sort_custom(func(x, y):
		if x.achieved != y.achieved: return x.achieved
		if x.achieved: return x.time > y.time
		return x.percent > y.percent)
	return {"total": list.size(), "unlocked": unlocked, "list": list, "private": mine.is_empty() and res.player == null}

# ------------------------------------------------------------------ unlock notifications while playing
func _seed_known(d: Dictionary) -> void:
	for a in d.get("list", []):
		if a.achieved:
			_poll_known[a.api] = true

func _process(dt: float) -> void:
	if not Session.is_playing() or Session.current.get("source", "steam") != "steam" or not has_key():
		return
	if not Config.get_b("ingame.achievement_toasts"):
		return
	_poll_t += dt
	if _poll_t < 75.0:
		return
	_poll_t = 0.0
	var appid := int(Session.current.get("appid", 0))
	achievements(appid, func(d: Dictionary):
		for a in d.get("list", []):
			if a.achieved and not _poll_known.has(a.api):
				_poll_known[a.api] = true
				var rare := ("  ·  %.1f%% of players" % a.percent) if a.percent >= 0.0 else ""
				Shellbus.notify({"title": "Achievement unlocked", "body": a.name + rare, "icon": "star_filled",
					"color": Tokens.GOLD, "image_url": a.icon, "sound": "achievement", "duration": 6.0}), true)
