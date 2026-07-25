extends Resource

const MainMenuAmbientProjection := preload("res://scripts/ui/main_menu_ambient_projection.gd")

const SCHEMA_VERSION := 1

@export var schema_version := SCHEMA_VERSION
@export var source_image_size := Vector2i.ZERO
@export var letter_mask_rect := Rect2i()
@export var orb_mask_rect := Rect2i()
@export var letter_mask := PackedByteArray()
@export var orb_mask := PackedByteArray()


func is_valid_for(letter_rect: Rect2i, orb_rect: Rect2i) -> bool:
	return (
		schema_version == SCHEMA_VERSION
		and source_image_size == Vector2i(MainMenuAmbientProjection.BACKGROUND_SOURCE_SIZE)
		and letter_mask_rect == letter_rect
		and orb_mask_rect == orb_rect
		and letter_mask.size() == letter_rect.size.x * letter_rect.size.y
		and orb_mask.size() == orb_rect.size.x * orb_rect.size.y
	)
