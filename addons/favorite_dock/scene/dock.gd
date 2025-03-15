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
var _SHA256 : String = ""
var fav_tree : Tree = null
var _chk : float = 0.0
var _col_cache : Dictionary = {}

const FAV_FOLDER : String = "res://.godot/editor/favorites"

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
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	if !dock.files_moved.is_connected(_c0):
		dock.files_moved.disconnect(_c0)
	if dock.file_removed.is_connected(_c1):
		dock.file_removed.disconnect(_c1)
	if dock.folder_moved.is_connected(_c0):
		dock.folder_moved.disconnect(_c0)
	if dock.folder_removed.is_connected(_c1):
		dock.folder_removed.disconnect(_c1)
	if dock.folder_color_changed.is_connected(_def_update):
		dock.folder_color_changed.disconnect(_def_update)
	if fs.filesystem_changed.is_connected(_def_update):
		fs.filesystem_changed.disconnect(_def_update)
	if fav_tree.item_collapsed.is_connected(_on_collap):
		fav_tree.item_collapsed.disconnect(_on_collap)
	_col_cache.clear()

## Tree callback
func _on_collap(i : TreeItem) -> void:
	var v : Variant = i.get_metadata(0)
	if v is String:
		if v.is_empty():return
		if _col_cache.has(v):
			_col_cache[v][1] = i.collapsed

## Add recursive folders/files
func _explorer(path : String, buffer : PackedStringArray) -> void:
	var efs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	var fs : EditorFileSystemDirectory = efs.get_filesystem_path(path)
	if fs == null:return
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
	if !visible and !force:return
	if !finish_update:return
	finish_update = false
	const FAV_FOLDER : String = "res://.godot/editor/favorites"
	if FileAccess.file_exists(FAV_FOLDER):
		var n_SHA256 : String = FileAccess.get_sha256(FAV_FOLDER)
		if _SHA256 != n_SHA256 or force == true:
			_SHA256 = n_SHA256
			clear()
			var buffer : PackedStringArray = []
			var root : TreeItem = fav_tree.get_root()
			if !tree.item_collapsed.is_connected(_on_collap):
				tree.item_collapsed.connect(_on_collap)
			if root != null and root.get_first_child() != null:
				_c(root.get_first_child().get_first_child(), buffer)
			for k : Variant in _col_cache.keys():
				_col_cache[k][0] = false
			for b : String in buffer:
				if !FileAccess.file_exists(b) and DirAccess.dir_exists_absolute(b):
					_explorer(b, buffer)
				add_item(b)#, false)
			for x : String in _col_cache.keys():
				if _col_cache[x][0] == false:
					_col_cache.erase(x)
	finish_update = true

#Update use physic process!
func _on_visibility_changed() -> void:
	if visible:
		_update(true)

func _def_update() -> void:
	_update.call_deferred(true)

func _get_popup_commands(path : String = "") -> Popup:
	var fs : FileSystemDock = EditorInterface.get_file_system_dock()

	var scp : bool = false
	for x : Node in fs.get_children():
		if x is SplitContainer and x.get_child_count() > 1:
			var v : Variant = x.get_child(1)
			if v is VBoxContainer and v.visible == true:
				scp = true
				break

	if fs.get_child_count() > 0:
		var pops : Array[Popup] = []
		for p : Node in fs.get_children():
			if p is Popup:
				pops.append(p)
				if pops.size() > 1:
					break
		if pops.size() > 0:
			var is_file : bool = FileAccess.file_exists(path)
			if (!scp or !is_file) and pops.size() > 1:
				return pops[1]
			return pops[0]
	return null

## RMB Tree command
func _item_mouse_selected(mouse_position: Vector2i, mouse_button_index: int) -> void:
	if mouse_button_index == 2:
		var item : TreeItem = tree.get_selected()
		if item == null:return
		var path : String = ""
		while item != null:
			path = item.get_text(0).path_join(path)
			item = item.get_parent()
		path = path.trim_suffix("/")
		if DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path):
			EditorInterface.select_file(path)
			var popup : Popup = _get_popup_commands(path)
			popup.position = (mouse_position) + Vector2i(64, 128)
			popup.show()

func _ready() -> void:
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	_n(dock)
	if !fav_tree:
		push_error("[ERROR] Can not find favorites tree!")
		return

	_get_popup_commands()

	if tree == null:
		tree = find_child("Tree")

	tree.allow_reselect = true
	tree.allow_rmb_select = true
	tree.item_mouse_selected.connect(_item_mouse_selected)
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

	_update.call_deferred()

	#Util when used another type of dock slot
	visibility_changed.connect(_on_visibility_changed)

	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	dock.files_moved.connect(_c0)
	dock.file_removed.connect(_c1)
	dock.folder_moved.connect(_c0)
	dock.folder_removed.connect(_c0)
	dock.folder_color_changed.connect(_def_update)
	fs.filesystem_changed.connect(_def_update)

func _c0(_a : String, _b : String ) -> void:
	_def_update()

func _c1(_a : String) -> void:
	_def_update()

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
		var rp : String = "res://"
		var base_gui : Control = EditorInterface.get_base_control()
		tree.theme = base_gui.theme
		root = tree.create_item(root)
		root.set_text(0, rp)
		root.set_icon(0, _get_icon(""))
		root.set_icon_modulate(0, Color.LIGHT_BLUE)

		if _col_cache.has(rp):
			root.collapsed = _col_cache[rp][1]
		else:
			_col_cache[rp] = [true, false]
			root.collapsed = false
		_col_cache[rp][0] = true

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
			tmp.set_metadata(0, tmp_path)

			if _col_cache.has(tmp_path):
				tmp.collapsed = _col_cache[tmp_path][1]
			else:
				_col_cache[tmp_path] = [true, true]
				tmp.collapsed = true
			_col_cache[tmp_path][0] = true
			if !FileAccess.file_exists(tmp_path):
				var c : Color = base_color
				c.a = 0.8
				c = c.lightened(0.35)
				tmp.set_icon_modulate(0, c)
			root = tmp
		else:
			root = tmp
			tmp = tmp.get_first_child()

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

func _physics_process(_delta: float) -> void:
	_chk += _delta
	if _chk < 0.35:return
	_chk = 0.0
	if !visible:return
	var n_SHA256 : String = FileAccess.get_sha256(FAV_FOLDER)
	if _SHA256 != n_SHA256:
		_update(true)
