extends Control

const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultDrawSceneHandler := preload("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
const StageClearResultInputSceneHandler := preload("res://scripts/ui/stage_clear_result_input_scene_handler.gd")
const StageClearResultUpdateSceneHandler := preload("res://scripts/ui/stage_clear_result_update_scene_handler.gd")

const DALJI_CLICK_DIALOGUE_DURATION := 1.55
const DALJI_CLICK_DIALOGUE_FADE_DURATION := 0.20
const DALJI_CLICK_DIALOGUE := "건들지마"

var timer: float = 0.0
var player_score: int = 0
var boss_score: int = 0
var current_stage: int = 1
var selected_character_type: String = "smasher"
var reward_plan: Dictionary = {}
var stage_reward_snapshot: Dictionary = {}
var confirmed_callback: Callable = Callable()
var enter_plaza_callback: Callable = Callable()
var exit_to_menu_callback: Callable = Callable()
var reward_roll_callback: Callable = Callable()
var immediate_reward_callback: Callable = Callable()

var _boxes: Array = []
var _hovered_box_index: int = -1
var _scroll_phase: String = "hidden"
var _scroll_timer: float = 0.0
var _scroll_position_offset: Vector2 = Vector2.ZERO
var _scroll_dragging: bool = false
var _scroll_drag_grab_offset: Vector2 = Vector2.ZERO
var _next_stage_button_rect: Rect2 = Rect2()
var _plaza_button_rect: Rect2 = Rect2()
var _exit_button_rect: Rect2 = Rect2()
var _hovered_button: String = "none"
var _plaza_notice_until: float = -1.0
var _reward_icon_cache: Dictionary = {}
var _scene_field_name_lookup: Dictionary = {}
var _dalji_click_rect: Rect2 = Rect2()
var _player_victory_click_rect: Rect2 = Rect2()
var _stage4_ponk_boss_defeat_click_rect: Rect2 = Rect2()
var _stage5_hongryun_result_click_rect: Rect2 = Rect2()
var _stage6_boss_defeat_click_rect: Rect2 = Rect2()
var _background_texture: Texture2D
var _dalji_defeat_sheet: Texture2D
var _dalji_click_reaction_sheet: Texture2D
var _stage2_boss_defeat_live2d_sheet: Texture2D
var _stage2_boss_defeat_click_reaction_sheet: Texture2D
var _stage3_boss_defeat_live2d_sheet: Texture2D
var _stage3_boss_defeat_click_reaction_sheet: Texture2D
var _stage4_ponk_boss_defeat_live2d_sheet: Texture2D
var _stage4_ponk_boss_defeat_click_reaction_sheet: Texture2D
var _stage5_hongryun_result_sheet: Texture2D
var _stage6_boss_defeat_sheet: Texture2D
var _player_victory_sheet: Texture2D
var _player_victory_click_reaction_sheet: Texture2D
var _player_victory_sheet_loaded_path: String = ""
var _player_victory_click_reaction_sheet_loaded_path: String = ""
var _scroll_texture: Texture2D
var _result_box_sheet_common: Texture2D
var _result_box_sheet_mythic: Texture2D
var _result_box_sheet_guaranteed_mythic: Texture2D
var _dalji_click_voice_stream: AudioStream
var _dalji_click_voice_player: AudioStreamPlayer
var _perk_catalog: Object = StageClearResultConfigSceneHandler.create_default_perk_catalog()
var _perk_icon_renderer: Object = StageClearResultConfigSceneHandler.create_default_perk_icon_renderer()
var _runtime_perk_overlay_renderer: Object = StageClearResultConfigSceneHandler.create_default_runtime_perk_overlay_renderer()
var _runtime_perk_state: Object
var _runtime_perk_catalog: Object
var _runtime_perk_icon_renderer: Object
var _runtime_perk_owner: Object
var _runtime_perk_registry: Object
var _mythic_item_runtime: Object
var _treasure_hunt_runtime: Object
var _game_audio: Object
var _driven_by_controller: bool = false
var _dalji_base_timer: float = 0.0
var _dalji_click_reaction_timer: float = StageClearResultConfigSceneHandler.get_default_reaction_timer("dalji_click_reaction_timer")
var _player_victory_click_reaction_timer: float = StageClearResultConfigSceneHandler.get_default_reaction_timer("player_victory_click_reaction_timer")
var _stage2_boss_defeat_click_reaction_timer: float = StageClearResultConfigSceneHandler.get_default_reaction_timer("stage2_boss_defeat_click_reaction_timer")
var _stage3_boss_defeat_click_reaction_timer: float = StageClearResultConfigSceneHandler.get_default_reaction_timer("stage3_boss_defeat_click_reaction_timer")
var _stage4_ponk_boss_defeat_click_reaction_timer: float = StageClearResultConfigSceneHandler.get_default_reaction_timer("stage4_ponk_boss_defeat_click_reaction_timer")
var _stage5_hongryun_result_click_reaction_timer: float = StageClearResultConfigSceneHandler.get_default_reaction_timer("stage5_hongryun_result_click_reaction_timer")
var _stage6_boss_defeat_click_reaction_timer: float = StageClearResultConfigSceneHandler.get_default_reaction_timer("stage6_boss_defeat_click_reaction_timer")
var _dalji_dialogue_timer: float = 0.0
var _dalji_click_transition_base_frame: int = 0
var _player_victory_click_transition_base_frame: int = 0
var _stage2_boss_defeat_click_transition_base_frame: int = 0
var _stage3_boss_defeat_click_transition_base_frame: int = 0
var _stage4_ponk_boss_defeat_click_transition_base_frame: int = 0
var _stage5_hongryun_result_click_transition_base_frame: int = 0
var _stage6_boss_defeat_click_transition_base_frame: int = 0
var _font_cache: Object = StageClearResultConfigSceneHandler.create_font_cache()
var _fx_host_pool: Object = StageClearResultConfigSceneHandler.create_fx_host_pool()
var _lid_open_counter: int = 0
var _starpoint_choice_gate_active: bool = false
var _starpoint_choice_gate_box_index: int = -1

func _ready() -> void:
	StageClearResultConfigSceneHandler.ready_scene(self)


func _process(delta: float) -> void:
	if _driven_by_controller:
		return
	StageClearResultUpdateSceneHandler.update_result_scene(self, delta)


func _exit_tree() -> void:
	StageClearResultConfigSceneHandler.exit_tree(self)


func _gui_input(event: InputEvent) -> void:
	if StageClearResultInputSceneHandler.handle_result_input(self, event, DALJI_CLICK_DIALOGUE_DURATION):
		accept_event()


func _draw() -> void:
	StageClearResultDrawSceneHandler.draw_result_scene(
		self,
		DALJI_CLICK_DIALOGUE,
		DALJI_CLICK_DIALOGUE_FADE_DURATION
	)
