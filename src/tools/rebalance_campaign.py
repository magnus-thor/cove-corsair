#!/usr/bin/env python3
"""
Cove Corsair - Complete Campaign Rebalancer & Synchronizer
Re-architects all 45 levels with:
- 5-level boss cadence (Bosses at 5, 10, 15, 20, 25, 30, 35, 40, 45)
- Grand Finish Line Gate on all non-boss levels (1-4, 6-9, 11-14, etc.)
- 4 rotating biome themes (Tropical, Bayou, Citadel, Brimstone) with dedicated horizons, water albedo, and fog
- Diverse chunk recipes using warmup, mine_gauntlet, barricade_siege, reef_slalom, gunner_ambush, finish_line
- Smooth scroll speed and doubloon progression
"""

import os
import sys
import re

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RESOURCES_DIR = os.path.join(ROOT_DIR, "src", "data", "resources", "levels")
DOCS_DIR = os.path.join(ROOT_DIR, "documents", "levels")

# 45 Level Titles
LEVEL_TITLES = {
    1: "Level 1: Smuggler's Run",
    2: "Level 2: Palm Shallows",
    3: "Level 3: Serpent's Reach",
    4: "Level 4: Sunken Reefs",
    5: "Level 5: Captain Ironjaw",
    6: "Level 6: Corsair's Cut",
    7: "Level 7: Bone Cay",
    8: "Level 8: Pelican Point",
    9: "Level 9: Sharktooth Shoal",
    10: "Level 10: The Phantom Dredge",
    11: "Level 11: Dead Calm Pass",
    12: "Level 12: Smuggler's Gate",
    13: "Level 13: Coral Labyrinth",
    14: "Level 14: Siren's Shoals",
    15: "Level 15: The Siege Fortress",
    16: "Level 16: The Iron Wall",
    17: "Level 17: Murkwater Run",
    18: "Level 18: Witch's Channel",
    19: "Level 19: Devil's Slalom",
    20: "Level 20: Captain Bone-Beard",
    21: "Level 21: Serpent's Nest",
    22: "Level 22: Gloom Mire",
    23: "Level 23: Rotwood Reach",
    24: "Level 24: Blackwater Hollow",
    25: "Level 25: Phantom Trench",
    26: "Level 26: Stagnant Cut",
    27: "Level 27: Banshee Bog",
    28: "Level 28: Dead Man's Bayou",
    29: "Level 29: Voodoo Crossing",
    30: "Level 30: Bonebeard's Armada",
    31: "Level 31: Cinder Rapids",
    32: "Level 32: Magma Surge",
    33: "Level 33: Ashfall Gorge",
    34: "Level 34: Obsidian Strait",
    35: "Level 35: Ironjaw's Crucible",
    36: "Level 36: Pyroclast Pass",
    37: "Level 37: Hellmouth Trench",
    38: "Level 38: Boiling Reach",
    39: "Level 39: Sulfur Chasm",
    40: "Level 40: Molten Bulwark",
    41: "Level 41: Inferno Gate",
    42: "Level 42: Doomspire Channel",
    43: "Level 43: Abyssal Rift",
    44: "Level 44: Dreadflame Basin",
    45: "Level 45: Bonebeard's Throne",
}

# Biome definitions with progressive atmospheric tuning
def get_biome_data(lvl: int) -> dict:
    if 1 <= lvl <= 15:
        # Tropical: Shallows -> Lagoons -> Storm Citadel Reefs
        if lvl <= 5:
            return {
                "name": "tropical",
                "horizon": "res://assets/textures/horizon_smugglers_run.png",
                "water": "Color(0.08, 0.58, 0.82, 0.88)",
                "fog_color": "Color(0.48, 0.76, 0.94, 1.0)",
                "fog_density": 0.002,
            }
        elif lvl <= 10:
            return {
                "name": "tropical",
                "horizon": "res://assets/textures/horizon_smugglers_run.png",
                "water": "Color(0.06, 0.52, 0.66, 0.88)",
                "fog_color": "Color(0.44, 0.72, 0.88, 1.0)",
                "fog_density": 0.006,
            }
        else:
            return {
                "name": "tropical",
                "horizon": "res://assets/textures/horizon_smugglers_run.png",
                "water": "Color(0.05, 0.40, 0.58, 0.90)",
                "fog_color": "Color(0.38, 0.65, 0.82, 1.0)",
                "fog_density": 0.010,
            }
    elif 16 <= lvl <= 30:
        # Bayou: Murkwater Run -> Gloom Mire -> Black Tide Abyss
        if lvl <= 20:
            return {
                "name": "bayou",
                "horizon": "res://assets/textures/horizon_bayou.png",
                "water": "Color(0.14, 0.35, 0.22, 0.92)",
                "fog_color": "Color(0.24, 0.40, 0.32, 1.0)",
                "fog_density": 0.016,
            }
        elif lvl <= 25:
            return {
                "name": "bayou",
                "horizon": "res://assets/textures/horizon_bayou.png",
                "water": "Color(0.10, 0.26, 0.18, 0.94)",
                "fog_color": "Color(0.18, 0.35, 0.26, 1.0)",
                "fog_density": 0.022,
            }
        else:
            return {
                "name": "bayou",
                "horizon": "res://assets/textures/horizon_bayou.png",
                "water": "Color(0.07, 0.18, 0.14, 0.95)",
                "fog_color": "Color(0.15, 0.28, 0.22, 1.0)",
                "fog_density": 0.028,
            }
    else:
        # Brimstone: Cinder Rapids -> Magma Surge -> Abyssal Inferno
        if lvl <= 35:
            return {
                "name": "brimstone",
                "horizon": "res://assets/textures/horizon_brimstone.png",
                "water": "Color(0.30, 0.14, 0.12, 0.92)",
                "fog_color": "Color(0.48, 0.24, 0.18, 1.0)",
                "fog_density": 0.016,
            }
        elif lvl <= 40:
            return {
                "name": "brimstone",
                "horizon": "res://assets/textures/horizon_brimstone.png",
                "water": "Color(0.38, 0.12, 0.08, 0.94)",
                "fog_color": "Color(0.44, 0.20, 0.16, 1.0)",
                "fog_density": 0.022,
            }
        else:
            return {
                "name": "brimstone",
                "horizon": "res://assets/textures/horizon_brimstone.png",
                "water": "Color(0.24, 0.06, 0.06, 0.96)",
                "fog_color": "Color(0.40, 0.16, 0.14, 1.0)",
                "fog_density": 0.028,
            }

def get_biome_key(lvl: int) -> str:
    if 1 <= lvl <= 15:
        return "tropical"
    elif 16 <= lvl <= 30:
        return "bayou"
    else:
        return "brimstone"

def get_boss_chunk(lvl: int) -> str:
    if lvl == 5 or lvl == 35:
        return "res://src/gameplay/chunks/chunk_boss_ironjaw.tscn"
    elif lvl == 10 or lvl == 25:
        return "res://src/gameplay/chunks/chunk_boss_phantom_dredge.tscn"
    elif lvl == 15 or lvl == 40:
        return "res://src/gameplay/chunks/chunk_boss_siege_fortress.tscn"
    elif lvl == 20 or lvl == 30 or lvl == 45:
        return "res://src/gameplay/chunks/chunk_boss_bonebeard.tscn"
    return ""

def get_level_title(lvl: int) -> str:
    base = LEVEL_TITLES.get(lvl, f"Level {lvl}: Expedition {lvl}")
    if lvl == 1:
        return f"{base} (Intro)"
    elif lvl == 2:
        return f"{base} (Armada Build)"
    elif lvl == 3:
        return f"{base} (Gunner Skirmish)"
    elif lvl == 4:
        return f"{base} (Hazard Gauntlet)"
    elif lvl % 5 == 0:
        return f"{base} (Boss Threat)"
    elif lvl % 2 == 1:
        return f"{base} (Swarm Threat)"
    else:
        return f"{base} (Hazard Nav)"

def get_chunk_sequence(lvl: int) -> list:
    C_WARMUP = "res://src/gameplay/chunks/chunk_warmup.tscn"              # Contains Gate 1
    C_OPENER_AMBUSH = "res://src/gameplay/chunks/chunk_opener_ambush.tscn"
    C_OPENER_GAUNTLET = "res://src/gameplay/chunks/chunk_opener_gauntlet.tscn"
    C_OPENER_SLALOM = "res://src/gameplay/chunks/chunk_opener_slalom.tscn"

    C_MINE = "res://src/gameplay/chunks/chunk_mine_gauntlet.tscn"
    C_BARRICADE = "res://src/gameplay/chunks/chunk_barricade_siege.tscn"    # Contains Gate 2
    C_REEF = "res://src/gameplay/chunks/chunk_reef_slalom.tscn"
    C_GUNNER = "res://src/gameplay/chunks/chunk_gunner_ambush.tscn"
    C_FODDER = "res://src/gameplay/chunks/chunk_fodder_swarm.tscn"
    C_CLIMAX = "res://src/gameplay/chunks/chunk_vanguard_climax.tscn"
    C_FINISH = "res://src/gameplay/chunks/chunk_finish_line.tscn"

    # Handcrafted, distinctive sequences for every level: NO two consecutive levels share order or pacing!
    SEQUENCES = {
        1: [C_OPENER_AMBUSH, C_WARMUP, C_GUNNER, C_BARRICADE, C_FINISH],
        2: [C_OPENER_SLALOM, C_WARMUP, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        3: [C_OPENER_GAUNTLET, C_GUNNER, C_WARMUP, C_REEF, C_BARRICADE, C_FODDER, C_FINISH],
        4: [C_OPENER_AMBUSH, C_REEF, C_WARMUP, C_MINE, C_BARRICADE, C_CLIMAX, C_FINISH],
        5: [C_OPENER_AMBUSH, C_GUNNER, C_WARMUP, C_MINE, C_BARRICADE, C_FODDER, get_boss_chunk(5)],
        
        6: [C_OPENER_SLALOM, C_MINE, C_WARMUP, C_GUNNER, C_REEF, C_BARRICADE, C_FODDER, C_FINISH],
        7: [C_OPENER_GAUNTLET, C_REEF, C_WARMUP, C_MINE, C_GUNNER, C_BARRICADE, C_CLIMAX, C_FINISH],
        8: [C_OPENER_AMBUSH, C_GUNNER, C_WARMUP, C_REEF, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        9: [C_OPENER_SLALOM, C_WARMUP, C_MINE, C_GUNNER, C_REEF, C_BARRICADE, C_CLIMAX, C_FINISH],
        10: [C_OPENER_GAUNTLET, C_REEF, C_WARMUP, C_GUNNER, C_MINE, C_BARRICADE, C_CLIMAX, get_boss_chunk(10)],

        11: [C_OPENER_AMBUSH, C_MINE, C_WARMUP, C_REEF, C_GUNNER, C_BARRICADE, C_FODDER, C_FINISH],
        12: [C_OPENER_SLALOM, C_GUNNER, C_WARMUP, C_MINE, C_REEF, C_BARRICADE, C_CLIMAX, C_FINISH],
        13: [C_OPENER_GAUNTLET, C_WARMUP, C_REEF, C_GUNNER, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        14: [C_OPENER_AMBUSH, C_REEF, C_WARMUP, C_GUNNER, C_MINE, C_BARRICADE, C_CLIMAX, C_FINISH],
        15: [C_OPENER_GAUNTLET, C_MINE, C_GUNNER, C_WARMUP, C_REEF, C_BARRICADE, C_CLIMAX, get_boss_chunk(15)],

        16: [C_OPENER_GAUNTLET, C_MINE, C_WARMUP, C_GUNNER, C_REEF, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        17: [C_OPENER_SLALOM, C_REEF, C_WARMUP, C_MINE, C_GUNNER, C_REEF, C_BARRICADE, C_CLIMAX, C_FINISH],
        18: [C_OPENER_AMBUSH, C_GUNNER, C_WARMUP, C_REEF, C_MINE, C_GUNNER, C_BARRICADE, C_FODDER, C_FINISH],
        19: [C_OPENER_GAUNTLET, C_MINE, C_WARMUP, C_REEF, C_GUNNER, C_BARRICADE, C_FODDER, C_CLIMAX, C_FINISH],
        20: [C_OPENER_SLALOM, C_GUNNER, C_WARMUP, C_REEF, C_MINE, C_GUNNER, C_BARRICADE, C_CLIMAX, get_boss_chunk(20)],

        21: [C_OPENER_AMBUSH, C_WARMUP, C_MINE, C_GUNNER, C_REEF, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        22: [C_OPENER_SLALOM, C_MINE, C_WARMUP, C_REEF, C_GUNNER, C_REEF, C_BARRICADE, C_CLIMAX, C_FINISH],
        23: [C_OPENER_GAUNTLET, C_REEF, C_WARMUP, C_GUNNER, C_MINE, C_GUNNER, C_BARRICADE, C_FODDER, C_FINISH],
        24: [C_OPENER_AMBUSH, C_GUNNER, C_WARMUP, C_MINE, C_REEF, C_MINE, C_BARRICADE, C_CLIMAX, C_FINISH],
        25: [C_OPENER_SLALOM, C_REEF, C_WARMUP, C_GUNNER, C_MINE, C_REEF, C_BARRICADE, C_FODDER, get_boss_chunk(25)],

        26: [C_OPENER_GAUNTLET, C_WARMUP, C_MINE, C_REEF, C_GUNNER, C_MINE, C_BARRICADE, C_CLIMAX, C_FINISH],
        27: [C_OPENER_AMBUSH, C_REEF, C_WARMUP, C_MINE, C_GUNNER, C_REEF, C_BARRICADE, C_FODDER, C_FINISH],
        28: [C_OPENER_SLALOM, C_GUNNER, C_WARMUP, C_REEF, C_MINE, C_GUNNER, C_BARRICADE, C_CLIMAX, C_FINISH],
        29: [C_OPENER_GAUNTLET, C_MINE, C_WARMUP, C_GUNNER, C_REEF, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        30: [C_OPENER_AMBUSH, C_GUNNER, C_WARMUP, C_MINE, C_REEF, C_GUNNER, C_BARRICADE, C_CLIMAX, get_boss_chunk(30)],

        31: [C_OPENER_GAUNTLET, C_MINE, C_WARMUP, C_REEF, C_GUNNER, C_MINE, C_REEF, C_BARRICADE, C_FODDER, C_FINISH],
        32: [C_OPENER_SLALOM, C_REEF, C_WARMUP, C_GUNNER, C_MINE, C_REEF, C_GUNNER, C_BARRICADE, C_CLIMAX, C_FINISH],
        33: [C_OPENER_AMBUSH, C_GUNNER, C_WARMUP, C_MINE, C_REEF, C_GUNNER, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        34: [C_OPENER_GAUNTLET, C_WARMUP, C_REEF, C_MINE, C_GUNNER, C_REEF, C_MINE, C_BARRICADE, C_CLIMAX, C_FINISH],
        35: [C_OPENER_SLALOM, C_MINE, C_WARMUP, C_REEF, C_GUNNER, C_MINE, C_REEF, C_BARRICADE, C_FODDER, get_boss_chunk(35)],

        36: [C_OPENER_AMBUSH, C_REEF, C_WARMUP, C_GUNNER, C_MINE, C_REEF, C_GUNNER, C_BARRICADE, C_CLIMAX, C_FINISH],
        37: [C_OPENER_GAUNTLET, C_GUNNER, C_WARMUP, C_REEF, C_MINE, C_GUNNER, C_REEF, C_BARRICADE, C_FODDER, C_FINISH],
        38: [C_OPENER_SLALOM, C_MINE, C_WARMUP, C_GUNNER, C_REEF, C_MINE, C_GUNNER, C_BARRICADE, C_CLIMAX, C_FINISH],
        39: [C_OPENER_AMBUSH, C_WARMUP, C_MINE, C_REEF, C_GUNNER, C_MINE, C_REEF, C_BARRICADE, C_FODDER, C_FINISH],
        40: [C_OPENER_GAUNTLET, C_REEF, C_WARMUP, C_MINE, C_GUNNER, C_REEF, C_MINE, C_BARRICADE, C_CLIMAX, get_boss_chunk(40)],

        41: [C_OPENER_SLALOM, C_GUNNER, C_WARMUP, C_REEF, C_MINE, C_GUNNER, C_REEF, C_BARRICADE, C_FODDER, C_FINISH],
        42: [C_OPENER_AMBUSH, C_MINE, C_WARMUP, C_GUNNER, C_REEF, C_MINE, C_GUNNER, C_BARRICADE, C_CLIMAX, C_FINISH],
        43: [C_OPENER_GAUNTLET, C_REEF, C_WARMUP, C_MINE, C_GUNNER, C_REEF, C_MINE, C_BARRICADE, C_FODDER, C_FINISH],
        44: [C_OPENER_SLALOM, C_GUNNER, C_WARMUP, C_MINE, C_REEF, C_GUNNER, C_MINE, C_BARRICADE, C_CLIMAX, C_FINISH],
        45: [C_OPENER_GAUNTLET, C_GUNNER, C_MINE, C_WARMUP, C_REEF, C_GUNNER, C_REEF, C_BARRICADE, C_CLIMAX, get_boss_chunk(45)],
    }
    return SEQUENCES[lvl]

def calculate_speed(lvl: int) -> float:
    if lvl == 1:
        return 6.5
    elif lvl == 2:
        return 6.8
    elif lvl == 3:
        return 7.0
    elif lvl == 4:
        return 7.3
    elif lvl == 5:
        return 7.5
    # 7.5 m/s at L5 up to 12.0 m/s at L45
    return round(7.5 + (lvl - 5) * (4.5 / 40.0), 1)

def calculate_reward(lvl: int) -> int:
    is_boss = (lvl % 5 == 0)
    base = 50 + (lvl - 1) * 15
    if is_boss:
        base += 100 + (lvl // 5) * 50
    # User request: Reduce coins by 10% per level
    return int(round(base * 0.90))

def build_tres_content(lvl: int) -> str:
    b = get_biome_data(lvl)
    title = get_level_title(lvl)
    speed = calculate_speed(lvl)
    reward = calculate_reward(lvl)
    chunks = get_chunk_sequence(lvl)
    
    # Collect unique chunk scenes
    unique_scenes = []
    for c in chunks:
        if c not in unique_scenes:
            unique_scenes.append(c)
            
    # Generate ext_resource entries
    lines = ['[gd_resource type="Resource" script_class="LevelData" format=3]', '']
    
    id_map = {}
    ext_id = 1
    for c in unique_scenes:
        tag = f"chunk_{ext_id}"
        lines.append(f'[ext_resource type="PackedScene" path="{c}" id="{tag}"]')
        id_map[c] = tag
        ext_id += 1
        
    horizon_id = f"ext_horizon"
    lines.append(f'[ext_resource type="Texture2D" path="{b["horizon"]}" id="{horizon_id}"]')
    
    script_id = "ext_script"
    lines.append(f'[ext_resource type="Script" path="res://src/data/resources/level_data.gd" id="{script_id}"]')
    lines.append('')
    
    lines.append('[resource]')
    lines.append(f'script = ExtResource("{script_id}")')
    lines.append(f'level_id = {lvl}')
    lines.append(f'level_title = "{title}"')
    lines.append(f'biome_name = "{b["name"]}"')
    lines.append(f'base_scroll_speed = {speed}')
    
    chunk_refs = ", ".join([f'ExtResource("{id_map[c]}")' for c in chunks])
    lines.append(f'chunk_scenes = Array[PackedScene]([{chunk_refs}])')
    lines.append(f'completion_doubloon_reward = {reward}')
    lines.append(f'horizon_texture = ExtResource("{horizon_id}")')
    lines.append(f'water_albedo = {b["water"]}')
    lines.append(f'fog_color = {b["fog_color"]}')
    lines.append(f'fog_density = {b["fog_density"]}')
    lines.append('river_width_world = 12.0')
    lines.append('')
    
    return "\n".join(lines)

def update_markdown_docs():
    print("\n=== UPDATING MARKDOWN LEVEL DOCUMENTS ===")
    if not os.path.exists(DOCS_DIR):
        return
        
    doc_files = os.listdir(DOCS_DIR)
    for fname in doc_files:
        if not fname.endswith(".md"):
            continue
        m = re.match(r"^level_(\d+)", fname)
        if not m:
            continue
        lvl = int(m.group(1))
        if lvl not in LEVEL_TITLES:
            continue
            
        fpath = os.path.join(DOCS_DIR, fname)
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()
            
        speed = calculate_speed(lvl)
        reward = calculate_reward(lvl)
        b = get_biome_data(lvl)
        title = get_level_title(lvl)
        chunks = get_chunk_sequence(lvl)
        dist = len(chunks) * 50.0
        
        # Update frontmatter
        content = re.sub(r'level_title:\s*".*?"', f'level_title: "{title}"', content)
        content = re.sub(r'biome_name:\s*".*?"', f'biome_name: "{b["name"]}"', content)
        content = re.sub(r'base_scroll_speed:\s*[\d\.]+', f'base_scroll_speed: {speed}', content)
        content = re.sub(r'completion_doubloon_reward:\s*\d+', f'completion_doubloon_reward: {reward}', content)
        
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)
            
        print(f"Synced doc: {fname} (L{lvl}) -> Title: {title}, Biome: {b['name']}, Chunks: {len(chunks)}, Speed: {speed}, Reward: {reward}")

def main():
    print(f"=== REBALANCING CAMPAIGN ACROSS ALL 45 LEVELS ===")
    os.makedirs(RESOURCES_DIR, exist_ok=True)
    
    alias_map = {
        1: "level_01_smugglers_run.tres",
        2: "level_02_black_tide_bayou.tres",
        3: "level_03_brimstone_bastion.tres",
        4: "level_04_smugglers_nightmare.tres",
        5: "level_05_black_tide_abyss.tres",
        6: "level_06_brimstone_inferno.tres",
    }
    
    for lvl in range(1, 46):
        tres_content = build_tres_content(lvl)
        filename = f"level_{lvl:02d}.tres"
        filepath = os.path.join(RESOURCES_DIR, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(tres_content)
        print(f"Updated {filename}: {get_level_title(lvl)} | Biome: {get_biome_key(lvl)} | Chunks: {len(get_chunk_sequence(lvl))} | Speed: {calculate_speed(lvl)}m/s")
        
        # Also sync alias if present
        if lvl in alias_map:
            alias_path = os.path.join(RESOURCES_DIR, alias_map[lvl])
            with open(alias_path, "w", encoding="utf-8") as f:
                f.write(tres_content)
            print(f"  -> Synced alias: {alias_map[lvl]}")

    update_markdown_docs()
    print("\n=== ALL 45 LEVELS & DOCUMENTS SUCCESSFULLY REBALANCED & CONFIGURED! ===")

if __name__ == "__main__":
    main()

