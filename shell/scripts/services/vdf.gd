class_name VDF
extends RefCounted
## Parser for Valve's text KeyValues format (libraryfolders.vdf, appmanifest_*.acf,
## localconfig.vdf, registry.vdf). All keys are lower-cased for easy lookup.

static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	return parse(f.get_as_text())

static func parse(text: String, keep_case := false) -> Dictionary:
	var root := {}
	var stack: Array = [root]
	var pending_key = null
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			i += 1
			continue
		if c == "/" and i + 1 < n and text[i + 1] == "/":
			var nl := text.find("\n", i)
			i = n if nl == -1 else nl + 1
			continue
		if c == "{":
			var d := {}
			if pending_key != null:
				(stack.back() as Dictionary)[pending_key] = d
				pending_key = null
			stack.append(d)
			i += 1
			continue
		if c == "}":
			if stack.size() > 1:
				stack.pop_back()
			pending_key = null
			i += 1
			continue
		# token: quoted or bare
		var tok := ""
		if c == "\"":
			i += 1
			var sb := PackedStringArray()
			var start := i
			while i < n:
				var ch := text[i]
				if ch == "\\" and i + 1 < n:
					sb.append(text.substr(start, i - start))
					var nx := text[i + 1]
					match nx:
						"n": sb.append("\n")
						"t": sb.append("\t")
						_: sb.append(nx)
					i += 2
					start = i
					continue
				if ch == "\"":
					break
				i += 1
			sb.append(text.substr(start, i - start))
			tok = "".join(sb)
			i += 1
		else:
			var start2 := i
			while i < n and not (text[i] in [" ", "\t", "\n", "\r", "{", "}", "\""]):
				i += 1
			tok = text.substr(start2, i - start2)
		# skip [$CONDITIONAL] tokens
		if tok.begins_with("[") and tok.ends_with("]"):
			continue
		if pending_key == null:
			pending_key = tok if keep_case else tok.to_lower()
		else:
			(stack.back() as Dictionary)[pending_key] = tok
			pending_key = null
	return root

## Walk a path of lower-case keys: dig(d, ["libraryfolders", "0", "path"])
static func dig(d, keys: Array, default = null):
	var cur = d
	for k in keys:
		if cur is Dictionary and cur.has(str(k).to_lower()):
			cur = cur[str(k).to_lower()]
		else:
			return default
	return cur

## Read a file keeping key case (for files we edit and write back).
static func parse_file_raw(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	return {} if f == null else parse(f.get_as_text(), true)

static func _esc(s: String) -> String:
	return s.replace("\\", "\\\\").replace("\"", "\\\"")

## Serialise back to Valve's text format (tabs, quoted keys).
static func stringify(d: Dictionary, indent := 0) -> String:
	var out := PackedStringArray()
	var tabs := "\t".repeat(indent)
	for k in d:
		var v = d[k]
		if v is Dictionary:
			out.append('%s"%s"' % [tabs, _esc(str(k))])
			out.append(tabs + "{")
			out.append(stringify(v, indent + 1))
			out.append(tabs + "}")
		else:
			out.append('%s"%s"\t\t"%s"' % [tabs, _esc(str(k)), _esc(str(v))])
	return "\n".join(out)

static func save_file(path: String, d: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(stringify(d) + "\n")
	return true

## Case-insensitive walk that creates missing sections; returns the innermost Dictionary.
static func ensure(d: Dictionary, keys: Array) -> Dictionary:
	var cur := d
	for k in keys:
		var found = null
		for existing in cur:
			if str(existing).to_lower() == str(k).to_lower():
				found = existing
				break
		if found == null or not (cur[found] is Dictionary):
			var nk = str(k) if found == null else found
			cur[nk] = {}
			found = nk
		cur = cur[found]
	return cur

static func set_ci(d: Dictionary, key: String, value) -> void:
	for existing in d.keys():
		if str(existing).to_lower() == key.to_lower():
			d.erase(existing)
	d[key] = value
