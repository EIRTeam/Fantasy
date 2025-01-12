class_name HBUserSettings

static var singleton: HBUserSettings

static var msaa_cvar := CVar.create(&"mat_msaa", TYPE_INT, 0, "Controls the MSAA level, with 0 being off") \
.with_getter(func():
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		return scene_tree.root.msaa_3d
	return 0
) \
.with_setter(func(new_val: int):
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		scene_tree.root.msaa_3d = new_val
)

static var taa_cvar := CVar.create(&"mat_taa", TYPE_BOOL, false, "Controls whether or not to use TAA") \
.with_getter(func():
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		return scene_tree.root.use_taa
	return false
) \
.with_setter(func(new_val: bool):
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		scene_tree.root.use_taa = new_val
)

static var fxaa_cvar := CVar.create(&"mat_fxaa", TYPE_BOOL, false, "Controls whether or not to use FXAA") \
.with_getter(func():
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		return scene_tree.root.screen_space_a == Viewport.SCREEN_SPACE_AA_FXAA
	return false
) \
.with_setter(func(new_val: bool):
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		scene_tree.root.screen_space_a = Viewport.SCREEN_SPACE_AA_FXAA if new_val else Viewport.SCREEN_SPACE_AA_DISABLED
)

static var scaling_mode_cvar := CVar.create(
	&"mat_scaling_mode", TYPE_INT, 0,
	"Controls which viewport scaling mode to use.", PROPERTY_HINT_ENUM, "Bilinear,FSR,FSR2") \
.with_getter(func():
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		return scene_tree.root.scaling_3d_mode
	return 0
) \
.with_setter(func(new_val: int):
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree.root is Viewport:
		scene_tree.root.scaling_3d_mode = new_val
)

# Map of cvar -> category
const USER_SETTINGS_CVARS: Dictionary[StringName, StringName] = {
	&"mat_msaa": &"graphics"
}

var config_file: ConfigFile

const USER_CONFIG_LOCATION := "user://user.cfg"

func _init() -> void:
	singleton = self
	config_file = ConfigFile.new()
	#config_file.load()

func save_user_settings():
	pass
