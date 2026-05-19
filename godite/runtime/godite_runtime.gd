@tool
extends Node
class_name GoditeRuntime

@export var configuration: GoditeRuntimeConfig:
	set(value):
		if configuration and configuration.changed.is_connected(_on_configuration_change):
			configuration.changed.disconnect(_on_configuration_change)

		if configuration and configuration.reconstruct.is_connected(_on_reconstruct):
			configuration.reconstruct.disconnect(_on_reconstruct)

		if configuration and configuration.reload.is_connected(_on_reload):
			configuration.reconstruct.disconnect(_on_reload)
			
		configuration = value

		if configuration:
			configuration.changed.connect(_on_configuration_change)
			configuration.reconstruct.connect(_on_reconstruct)
			configuration.reload.connect(_on_reload)


## Load 'load_composite' in editor
@export var load_in_editor: bool = false


## Path to composite to load; game-runtime (also usable in editor using 'load_in_editor')
@export var load_composite_path: String
# Dont do this below; as it will cause (slow) saving of the referred resource, even if not changed
#@e xport_file("*.res") var load_composite: String

			
var _renderer: GoditeBeamRenderer

# Dont make it a export var; the inspector will try to build a UI for the whole tree and freeze
var _composite: GoditeComposite


func _ready() -> void:
	_on_reload()

func _on_reload() -> void:
	stop()
	_composite = null
	_load_composite()
	start()


func _load_composite() -> void:
	if not Engine.is_editor_hint() or load_in_editor:
		_composite = GoditeCompositeLoader.load_composite(load_composite_path, configuration)


func _on_configuration_change() -> void:
	pass

func _on_reconstruct() -> void:
	start()

func _update_renderer_config() -> void:
	if _renderer:
		_renderer.configure(configuration)


## This is used by pre-production tooling; not intended for in-game use
static func get_current_for(node: Node3D) -> GoditeRuntime:
	var scene_tree: SceneTree = node.get_tree()
	var scene: Node3D = scene_tree.edited_scene_root if Engine.is_editor_hint() else scene_tree.current_scene
	var runtime_nodes: Array[Node] = scene.find_children("*", "GoditeRuntime")
	return runtime_nodes[0] if runtime_nodes and not runtime_nodes.is_empty() else null


func set_composite(composite: GoditeComposite) -> void:
	print("Godite runtime; new composite " + str(composite.get_instance_id()))
	_composite = composite
	start()


func start() -> void:
	stop()
	
	if not _composite or not configuration:
		print("Start aborted, no composite and/or no configuration")
		return
	
	var is_editor: bool = Engine.is_editor_hint()
	var is_runtime: bool = not is_editor
	if not configuration.runtime and is_runtime:
		return

	if not configuration.editor and is_editor:
		return

	print("New runtime renderer")
	_renderer = GoditeBeamRenderer.new(_composite)
	_update_renderer_config()
	add_child(_renderer)	

func stop() -> void:
	if _renderer:
		if is_inside_tree():
			_renderer.queue_free()
			_renderer = null
		else:
			_renderer.free()
