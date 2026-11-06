## no_text_audit.gd - dev-only check for the jam's NO TEXT rule (CLAUDE.md).
## Scans every .tscn and .gd under res:// (except tools/ and addons/) for things that
## put words or digits on screen: Label / RichTextLabel / LineEdit / Button nodes,
## text properties, draw_string / draw_char, and Font use. Prints each hit with its
## file and line, and quits with the number of hits that are not on the allow list.
## Run it headless (no editor needed):
##   godot --headless --path . --script res://tools/no_text_audit.gd
## `extends SceneTree` makes this a script Godot can run as the whole program.
extends SceneTree

## Patterns that can show text. A plain substring match keeps it simple and loud:
## a false hit is cheap to look at, a missed one could break the jam rule.
const PATTERNS: Array[String] = [
	'type="Label"', 'type="RichTextLabel"', 'type="LineEdit"', 'type="Button"',
	"Label.new(", "RichTextLabel.new(", "LineEdit.new(", "Button.new(",
	"draw_string(", "draw_char(", "draw_multiline_string(",
	".text =", "\ntext = ", "Font",
]

## Files allowed to draw text, and why. key_hint.gd draws key-cap letters (A, D, J,
## K, S), which CLAUDE.md allows as icons.
const ALLOW: Dictionary = {
	"res://scripts/key_hint.gd": "key-cap letters (allowed by the rule)",
	"res://scripts/pause_menu.gd": "icon-only Buttons: their text is never set, they draw shapes",
}

## Folders not shipped as game content.
const SKIP_DIRS: Array[String] = ["res://tools", "res://addons", "res://.godot", "res://worker", "res://build"]


## _initialize runs once when a SceneTree script starts; quit() ends the program.
func _initialize() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	var bad: int = 0
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			if line.strip_edges().begins_with("#"):
				continue  # comments (## doc lines too) never reach the screen
			for pattern: String in PATTERNS:
				if pattern.strip_edges() in line:
					var allowed: bool = ALLOW.has(path)
					print("%s %s:%d  %s" % ["ALLOWED" if allowed else "HIT", path, i + 1, line.strip_edges()])
					if not allowed:
						bad += 1
					break
	print("no_text_audit: %d file(s) scanned, %d hit(s)" % [files.size(), bad])
	quit(bad)


## Walks a folder tree and adds every .gd and .tscn path to `out`.
func _collect(dir_path: String, out: Array[String]) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			out.append(dir_path.path_join(file))
