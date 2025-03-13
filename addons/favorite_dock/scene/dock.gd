@tool
extends Control
#{
	#"type": "plugin",
	#"codeRepository": "https://github.com/CodeNameTwister",
	#"description": "Favorite dock addon for godot 4",
	#"license": "https://spdx.org/licenses/MIT",
	#"name": "Twister",
	#"version": "1.0.0"
#}
@export var tree : Tree

var finish_update : bool = true
var SHA256 : String = ""
var fav_tree : Tree = null

func clear() -> void:
	tree.clear()

## On item selection callback
func _select() -> void:
	var item : TreeItem = tree.get_selected()
	if item:
		var path : String = item.get_text(0)
		var parent : TreeItem = item.get_parent()
		while parent != null:
			path = parent.get_text(0).path_join(path)
			parent = parent.get_parent()

		if FileAccess.file_exists(path):
			EditorInterface.select_file(path)
			_edit_path(path)
		elif DirAccess.dir_exists_absolute(path):
			EditorInterface.select_file(path)
		else:
			push_error("Error on selection: ", path)

## Get icon type using path as reference
func _get_icon(path : String) -> Texture:
	var base_gui : Control = EditorInterface.get_base_control()
	var editor : EditorFileSystem = EditorInterface.get_resource_filesystem()

	if path == "":
		return base_gui.get_theme_icon("Load", "EditorIcons")

	var ticon : StringName = editor.get_file_type(path)
	var load_icon :  Texture2D = base_gui.get_theme_icon("", "EditorIcons")
	var default_icon : Texture2D = load_icon
	load_icon = base_gui.get_theme_icon(ticon, "EditorIcons")
	if load_icon == default_icon:
		if path.get_extension() == "":
			if !path.ends_with("."):
				load_icon = base_gui.get_theme_icon("Folder", "EditorIcons")
		elif ticon.ends_with("s"):
			load_icon = base_gui.get_theme_icon(ticon.trim_suffix("s"), "EditorIcons")
		if load_icon == default_icon:
			return base_gui.get_theme_icon("File", "EditorIcons")
	return load_icon

#region rescue_fav
func _n(n : Node) -> bool:
	if n is Tree:
		var t : TreeItem = (n.get_root())
		if null != t:
			t = t.get_first_child()
			if null != t:
				var txt : String = (t.get_text(0)).to_lower()
				if "fav" in txt or txt.ends_with(":") or txt.begins_with(":"):
					fav_tree = n
					return true
	for x in n.get_children():
		if _n(x): return true
	return false

func _c(i : TreeItem, p : PackedStringArray) -> void:
	if i == null : return
	var d : String = str(i.get_metadata(0))
	if FileAccess.file_exists(d) or DirAccess.dir_exists_absolute(d):
		p.append(d)
	var n : TreeItem = i.get_next()
	if n != null:
		_c(n, p)
#endregion

func _exit_tree() -> void:
	if !fav_tree:return
	if fav_tree.draw.is_connected(_update):
		fav_tree.draw.disconnect(_update)

## Add recursive folders/files
func _explorer(path : String, buffer : PackedStringArray) -> void:
	var efs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	var fs : EditorFileSystemDirectory = efs.get_filesystem_path(path)
	for x : int in fs.get_subdir_count():
		var new_path : String = fs.get_subdir(x).get_path()
		if !buffer.has(new_path):
			buffer.append(new_path)
			_explorer(new_path, buffer)
	for x : int in fs.get_file_count():
		var new_path : String = fs.get_file_path(x)
		if !buffer.has(new_path):
			buffer.append(new_path)

## Refresh dock
func _update(force : bool = false) -> void:
	if !visible:return
	if !finish_update:return
	finish_update = false
	const FAV_FOLDER : String = "res://.godot/editor/favorites"
	if FileAccess.file_exists(FAV_FOLDER):
		var _SHA256 : String = FileAccess.get_sha256(FAV_FOLDER)
		if SHA256 != _SHA256 or force == true:
			SHA256 = _SHA256
			clear()
			var buffer : PackedStringArray = []
			var root : TreeItem = fav_tree.get_root()
			if root != null and root.get_first_child() != null:
				_c(root.get_first_child().get_first_child(), buffer)
			for b : String in buffer:
				if !FileAccess.file_exists(b) and DirAccess.dir_exists_absolute(b):
					_explorer(b, buffer)
				add_item(b)#, false)
	finish_update = true

func _on_visibility_changed() -> void:
	_update()

func _def_update() -> void:
	_update.call_deferred()

func _ready() -> void:
	_n(EditorInterface.get_file_system_dock())
	if !fav_tree:
		push_error("[ERROR] Can not find favorites tree!")
		return

	if tree == null:
		tree = find_child("Tree")
	tree.item_activated.connect(_select)

	# FAV ICON
	var tittle_icon : TextureRect = $TittleBox/FavText
	if tittle_icon:
		var def : Texture = EditorInterface.get_base_control().get_theme_icon("", "EditorIcons")
		var new_text : Texture = EditorInterface.get_base_control().get_theme_icon("Favorites", "EditorIcons")
		if def != new_text:
			tittle_icon.texture = new_text

	#Refresh button
	$TittleBox/Button.pressed.connect(_update.bind(true))

	_update()
	fav_tree.draw.connect(_def_update)

	#Util when used another type of dock slot
	visibility_changed.connect(_on_visibility_changed)

	# LOAD CONFIG
	#var cfg : ConfigFile = ConfigFile.new()
	#if cfg.load(_get_user_path()) == OK:
		#if cfg.has_section("FAV_PATHS"):
			#for k : String in cfg.get_section_keys("FAV_PATHS"):
				#add_item(k, false)
			#cfg = null

## Get current user config data path
func _get_user_path() -> String:
	var save_path : String = (get_script() as Script).resource_path
	if save_path.is_empty():
		save_path = "favfolder"
	else:
		save_path = save_path.get_slice("/", min(save_path.get_slice_count("/"),3))
	return "user://editor/{0}.cfg".format([save_path])

## Make tree by item
func add_item(path : String) -> void: #, save : bool = true) -> void:
	if !path.begins_with("res://") or path == "res://":
		push_error("Trying add wrong path/item !")
		return

	path = path.trim_suffix("/")

	var ticon : Texture = _get_icon(path)
	var root : TreeItem = tree.get_root()

	if root == null:
		var base_gui : Control = EditorInterface.get_base_control()
		tree.theme = base_gui.theme
		root = tree.create_item(root)
		root.set_text(0, "res://")
		root.set_icon(0, _get_icon(""))
		root.set_icon_modulate(0, Color.LIGHT_BLUE)

	var tmp : TreeItem = root.get_first_child()
	var tmp_path : String = "res://"
	var base_color : Color = Color.TRANSPARENT

	var data : Dictionary = ProjectSettings.get_setting("file_customization/folder_colors")

	for x : String in path.trim_prefix("res://").split("/", false, 0):
		tmp_path = tmp_path.path_join(x)
		base_color.a = max(base_color.a - 0.05, 0.05)
		if data.has(tmp_path.path_join("/")):
			base_color = Color.from_string(data[tmp_path.path_join("/")], Color.TRANSPARENT)
			base_color.a = 0.1
		while tmp != null:
			if tmp.get_text(0) == x:
				break
			tmp = tmp.get_next()
		if tmp == null:
			tmp = root.create_child()
			tmp.set_text(0, x)
			tmp.set_icon(0, _get_icon(tmp_path))
			if tmp_path.get_extension() == "" and !tmp_path.ends_with("."):
				tmp.set_icon_modulate(0, Color.LIGHT_BLUE)
			tmp.set_custom_bg_color(0, base_color)
			if !FileAccess.file_exists(tmp_path):
				var c : Color = base_color
				c.a = 0.8
				c = c.lightened(0.35)
				tmp.set_icon_modulate(0, c)
			root = tmp
		else:
			root = tmp
			tmp = tmp.get_first_child()

	#if save:
		#var save_path : String = _get_user_path()
		#var cfg : ConfigFile = ConfigFile.new()
		#cfg.load(save_path)
		#cfg.set_value("FAV_PATHS", path, 0)
		#if !DirAccess.dir_exists_absolute(save_path.get_base_dir()):
			#DirAccess.make_dir_absolute(save_path.get_base_dir())
		#if cfg.save(save_path) != OK:
			#push_error("Error on try save changes!")

#region interactions
## Double click interaction
func _edit_path(asset_path: String) -> void:
	if _is_script(asset_path):
		var resource = ResourceLoader.load(asset_path) as Script
		EditorInterface.edit_script(resource)
	elif _is_scene(asset_path):
		var resource = ResourceLoader.load(asset_path)
		EditorInterface.edit_resource(resource)
		EditorInterface.open_scene_from_path(asset_path)
	else:
		var resource = ResourceLoader.load(asset_path)
		EditorInterface.edit_resource(resource)

func _is_script(asset_path: String) -> bool:
	var script_extensions : PackedStringArray = ["gd", "cs", "txt", "md", "json", "xml", "cfg", "ini", "shader", "hlsl", "glsl", "wgsl", "compute"]
	var extension : String = asset_path.get_extension()
	return (extension in script_extensions)

func _is_scene(asset_path: String) -> bool:
	return asset_path.get_extension().contains("tscn")
#endregion
