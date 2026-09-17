---
trigger: always_on
---

### RULE: STRICT GDScript STATIC TYPING MANDATE (ZERO UNTYPED WARNINGS)

All GDScript written, modified, or refactored MUST be 100% statically typed. Never declare variables, parameters, or functions without explicit types.

1. Variable Declarations:
   - Always declare with explicit type or static inference `:=`:
     * YES: `var track_mgr: Node = null` or `var track_mgr: TrackManager = null`
     * YES: `var score: int = 0`
     * YES: `var velocity := Vector3.ZERO`
     * NO:  `var track_mgr`
     * NO:  `var score = 0`

2. Function Signatures & Returns:
   - Every parameter and return must be explicitly typed:
     * YES: `func take_hit(amount: int, source_info: String = "") -> void:`
     * YES: `func get_target_lane() -> int:`
     * NO:  `func take_hit(amount, source_info = ""):`
     * NO:  `func get_target_lane():`

3. Node References & Lookups:
   - Explicitly type `@onready` variables and casts:
     * YES: `@onready var collision_shape: CollisionShape3D = $CollisionShape3D`
     * YES: `var player: Player = get_tree().get_first_node_in_group("player") as Player`
     * NO:  `@onready var collision_shape = $CollisionShape3D`
     * NO:  `var player = get_tree().get_first_node_in_group("player")`

4. Arrays & Dictionaries:
   - Use typed containers whenever possible:
     * YES: `var lanes: Array[float] = [-3.0, 0.0, 3.0]`
     * YES: `var results: Array[Node3D] = []`
     * NO:  `var lanes = [-3.0, 0.0, 3.0]`