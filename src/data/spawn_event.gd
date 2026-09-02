class_name SpawnEvent
extends Resource

## Strongly typed Spawn Event definition for Cove Corsair deterministic level timeline

enum EntityType {
	BARREL,
	MOB,
	MULTIPLIER_GATE,
	HAZARD,
	BOSS
}

enum RarityTier {
	COMMON,
	NORMAL,
	RARE,
	ELITE,
	LEGENDARY
}

enum GateType {
	CANNONBALL_ADD,
	CANNONBALL_MULT,
	FLEET_SUMMON
}

@export var trigger_distance: float = 0.0
@export var entity_type: EntityType = EntityType.BARREL
@export_range(-7.5, 7.5, 0.1) var lane_x: float = 0.0:
	set(val):
		lane_x = clampf(val, -7.5, 7.5)
@export var rarity_tier: RarityTier = RarityTier.NORMAL
@export var base_hp_override: int = 0
@export var gate_type: GateType = GateType.FLEET_SUMMON
@export var gate_value: int = 1
