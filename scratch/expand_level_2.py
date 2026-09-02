import re

def create_expanded_level():
    # Read existing file to keep exact structure
    path = r"f:/projects/cove-corsair/src/data/resources/levels/level_02_black_tide_bayou.tres"
    
    # Define our comprehensive, busy, high-action timeline
    # Entity Types: 0 = BARREL, 1 = MOB, 2 = MULTIPLIER_GATE, 3 = HAZARD, 4 = BOSS
    # Rarity Tiers: 0 = COMMON, 1 = NORMAL, 2 = RARE, 3 = ELITE, 4 = LEGENDARY
    
    events = [
        # Segment 1: 0m to 59m — Bayou Entry & First Skiffs
        {"dist": 15.0, "type": 0, "lane": 0.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 20.0, "type": 0, "lane": -1.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 20.0, "type": 0, "lane": 1.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 25.0, "type": 3, "lane": -2.8, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 25.0, "type": 0, "lane": 2.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 32.0, "type": 0, "lane": 0.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 32.0, "type": 3, "lane": 3.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 38.0, "type": 3, "lane": -3.2, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 38.0, "type": 1, "lane": -1.5, "rarity": 1, "hp": 8, "gtype": 2, "gval": 1},
        {"dist": 42.0, "type": 1, "lane": 2.0, "rarity": 1, "hp": 8, "gtype": 2, "gval": 1},
        {"dist": 42.0, "type": 0, "lane": -2.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 48.0, "type": 0, "lane": 1.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 48.0, "type": 0, "lane": -3.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 54.0, "type": 3, "lane": -2.5, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 54.0, "type": 0, "lane": 2.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},

        # First Fleet Gate (+1)
        {"dist": 60.0, "type": 2, "lane": 0.0, "rarity": 0, "hp": 0, "gtype": 2, "gval": 1},

        # Segment 2: 61m to 125m — Escalation, Harvester Miniboss
        {"dist": 68.0, "type": 1, "lane": 1.5, "rarity": 1, "hp": 10, "gtype": 2, "gval": 1},
        {"dist": 68.0, "type": 0, "lane": -2.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 75.0, "type": 1, "lane": -2.0, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 75.0, "type": 0, "lane": 2.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 82.0, "type": 3, "lane": -3.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 82.0, "type": 0, "lane": 0.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 82.0, "type": 0, "lane": 3.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 90.0, "type": 1, "lane": 3.0, "rarity": 2, "hp": 20, "gtype": 2, "gval": 1},
        {"dist": 95.0, "type": 1, "lane": -2.5, "rarity": 1, "hp": 12, "gtype": 2, "gval": 1},
        {"dist": 95.0, "type": 0, "lane": 1.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 100.0, "type": 3, "lane": -2.8, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 100.0, "type": 0, "lane": 0.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 100.0, "type": 3, "lane": 2.8, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 105.0, "type": 0, "lane": -1.5, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 105.0, "type": 3, "lane": 2.5, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        
        # 110m Harvester Mini-Boss Encounter
        {"dist": 110.0, "type": 3, "lane": -3.2, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 110.0, "type": 1, "lane": 0.0, "rarity": 3, "hp": 95, "gtype": 2, "gval": 1},
        {"dist": 110.0, "type": 3, "lane": 3.2, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 115.0, "type": 0, "lane": -3.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 115.0, "type": 0, "lane": 3.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},

        # 120m Reward Barrels & 128m Fleet Gate (+1)
        {"dist": 120.0, "type": 0, "lane": -2.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 120.0, "type": 0, "lane": 0.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 120.0, "type": 0, "lane": 2.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 124.0, "type": 3, "lane": -2.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 124.0, "type": 0, "lane": 1.5, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 128.0, "type": 2, "lane": 0.0, "rarity": 0, "hp": 0, "gtype": 2, "gval": 1},

        # Segment 3: 130m to 219m — Heavy Skiff Squadrons & Double Cutters
        {"dist": 136.0, "type": 1, "lane": 0.0, "rarity": 2, "hp": 20, "gtype": 2, "gval": 1},
        {"dist": 136.0, "type": 0, "lane": -2.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 136.0, "type": 0, "lane": 2.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 145.0, "type": 1, "lane": -3.0, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 145.0, "type": 1, "lane": 3.0, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 152.0, "type": 1, "lane": 2.0, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 152.0, "type": 3, "lane": -3.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 152.0, "type": 0, "lane": 0.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 160.0, "type": 3, "lane": -3.2, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 160.0, "type": 1, "lane": 0.0, "rarity": 2, "hp": 22, "gtype": 2, "gval": 1},
        {"dist": 160.0, "type": 3, "lane": 3.2, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 170.0, "type": 3, "lane": 2.8, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 170.0, "type": 0, "lane": -1.5, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 170.0, "type": 0, "lane": 1.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 180.0, "type": 1, "lane": -3.5, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 180.0, "type": 0, "lane": -1.5, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 180.0, "type": 0, "lane": 1.5, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 180.0, "type": 1, "lane": 3.5, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 190.0, "type": 1, "lane": -1.5, "rarity": 2, "hp": 20, "gtype": 2, "gval": 1},
        {"dist": 190.0, "type": 1, "lane": 2.5, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 190.0, "type": 0, "lane": 0.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 200.0, "type": 1, "lane": -2.5, "rarity": 2, "hp": 20, "gtype": 2, "gval": 1},
        {"dist": 200.0, "type": 3, "lane": 0.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 200.0, "type": 1, "lane": 2.5, "rarity": 2, "hp": 20, "gtype": 2, "gval": 1},
        {"dist": 208.0, "type": 3, "lane": -3.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 208.0, "type": 0, "lane": 0.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 208.0, "type": 3, "lane": 3.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},

        # Fleet Gate (+2)
        {"dist": 218.0, "type": 2, "lane": 0.0, "rarity": 0, "hp": 0, "gtype": 2, "gval": 2},

        # Segment 4: 220m to 280m — Final Run-up & Boss Approach
        {"dist": 224.0, "type": 1, "lane": 1.5, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 224.0, "type": 0, "lane": -2.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 230.0, "type": 0, "lane": -4.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 230.0, "type": 0, "lane": -1.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 230.0, "type": 0, "lane": 1.5, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 230.0, "type": 0, "lane": 4.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 236.0, "type": 3, "lane": -2.5, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 236.0, "type": 0, "lane": 2.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 242.0, "type": 1, "lane": -3.0, "rarity": 1, "hp": 12, "gtype": 2, "gval": 1},
        {"dist": 242.0, "type": 3, "lane": 0.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 242.0, "type": 1, "lane": 3.0, "rarity": 1, "hp": 12, "gtype": 2, "gval": 1},
        {"dist": 248.0, "type": 1, "lane": -2.0, "rarity": 2, "hp": 22, "gtype": 2, "gval": 1},
        {"dist": 248.0, "type": 1, "lane": 2.0, "rarity": 2, "hp": 14, "gtype": 2, "gval": 1},
        {"dist": 254.0, "type": 0, "lane": -3.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 254.0, "type": 0, "lane": 0.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 254.0, "type": 0, "lane": 3.0, "rarity": 0, "hp": 2, "gtype": 2, "gval": 1},
        {"dist": 258.0, "type": 3, "lane": 3.0, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 258.0, "type": 0, "lane": -1.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 258.0, "type": 0, "lane": 1.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 265.0, "type": 1, "lane": -2.0, "rarity": 2, "hp": 16, "gtype": 2, "gval": 1},
        {"dist": 265.0, "type": 0, "lane": 0.0, "rarity": 1, "hp": 4, "gtype": 2, "gval": 1},
        {"dist": 265.0, "type": 1, "lane": 2.0, "rarity": 2, "hp": 16, "gtype": 2, "gval": 1},
        {"dist": 272.0, "type": 1, "lane": 0.0, "rarity": 2, "hp": 16, "gtype": 2, "gval": 1},
        {"dist": 272.0, "type": 3, "lane": -3.2, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},
        {"dist": 272.0, "type": 3, "lane": 3.2, "rarity": 0, "hp": 1, "gtype": 2, "gval": 1},

        # Boss Trigger
        {"dist": 280.0, "type": 4, "lane": 0.0, "rarity": 4, "hp": 750, "gtype": 2, "gval": 1},
    ]

    total_subresources = len(events)
    header_steps = total_subresources + 4  # 3 ext_resources + subresources

    output = []
    output.append(f'[gd_resource type="Resource" script_class="LevelData" load_steps={header_steps} format=3]\n')
    output.append('[ext_resource type="Script" path="res://src/data/level_data.gd" id="1_level_script"]')
    output.append('[ext_resource type="Script" path="res://src/data/spawn_event.gd" id="2_spawn_event"]')
    output.append('[ext_resource type="PackedScene" path="res://src/gameplay/enemies/boss_phantom_dredge.tscn" id="3_boss"]\n')

    sub_ids = []
    for i, ev in enumerate(events, 1):
        sid = f"Resource_se_{i:02d}"
        sub_ids.append(f'SubResource("{sid}")')
        output.append(f'[sub_resource type="Resource" id="{sid}"]')
        output.append('script = ExtResource("2_spawn_event")')
        output.append(f'trigger_distance = {ev["dist"]:.1f}')
        output.append(f'entity_type = {ev["type"]}')
        output.append(f'lane_x = {ev["lane"]:.1f}')
        output.append(f'rarity_tier = {ev["rarity"]}')
        output.append(f'base_hp_override = {ev["hp"]}')
        output.append(f'gate_type = {ev["gtype"]}')
        output.append(f'gate_value = {ev["gval"]}\n')

    output.append('[resource]')
    output.append('script = ExtResource("1_level_script")')
    output.append('level_id = 2')
    output.append('level_name = "Level 2: Black Tide Bayou"')
    output.append('target_distance = 280.0')
    output.append('starting_hull = 1')
    output.append('boss_hp = 750')
    output.append('boss_scene = ExtResource("3_boss")')
    output.append('biome_type = "black_tide_bayou"')
    output.append('water_albedo = Color(0.04, 0.28, 0.22, 0.92)')
    output.append('fog_color = Color(0.06, 0.18, 0.14, 1.0)')
    output.append('fog_density = 0.022')
    output.append('river_width_world = 12.0')
    output.append('base_scroll_speed = 10.0')
    output.append(f'timeline_events = Array[ExtResource("2_spawn_event")]([{", ".join(sub_ids)}])')
    output.append('total_distance = 280.0')
    output.append('wave_events = Array[Dictionary]([])\n')

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(output))
    print(f"Generated Level 2 with {len(events)} events!")

if __name__ == "__main__":
    create_expanded_level()
