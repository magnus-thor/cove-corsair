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

# Biome definitions
BIOMES = {
    "tropical": {
        "name": "tropical",
        "horizon": "res://assets/textures/horizon_smugglers_run.png",
        "water": "Color(0.08, 0.58, 0.82, 0.88)",
        "fog_color": "Color(0.48, 0.76, 0.94, 1.0)",
        "fog_density": 0.005,
    },
    "bayou": {
        "name": "black_tide_bayou",
        "horizon": "res://assets/textures/horizon_bayou.png",
        "water": "Color(0.12, 0.32, 0.22, 0.92)",
        "fog_color": "Color(0.20, 0.38, 0.30, 1.0)",
        "fog_density": 0.02,
    },
    "citadel": {
        "name": "pirate_citadel",
        "horizon": "res://assets/textures/horizon_citadel.png",
        "water": "Color(0.10, 0.28, 0.46, 0.90)",
        "fog_color": "Color(0.72, 0.48, 0.30, 1.0)",
        "fog_density": 0.01,
    },
    "brimstone": {
        "name": "brimstone_bastion",
        "horizon": "res://assets/textures/horizon_brimstone.png",
        "water": "Color(0.28, 0.14, 0.12, 0.92)",
        "fog_color": "Color(0.45, 0.22, 0.18, 1.0)",
        "fog_density": 0.018,
    }
}

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

def get_biome_key(lvl: int) -> str:
    if 1 <= lvl <= 5:
        return "tropical"
    elif 6 <= lvl <= 10:
        return "bayou"
    elif 11 <= lvl <= 15:
        return "citadel"
    elif 16 <= lvl <= 20:
        return "brimstone"
    elif 21 <= lvl <= 25:
        return "bayou"
    elif 26 <= lvl <= 30:
        return "citadel"
    elif 31 <= lvl <= 35:
        return "tropical"
    elif 36 <= lvl <= 40:
        return "brimstone"
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

def get_chunk_sequence(lvl: int) -> list:
    is_boss = (lvl % 5 == 0)
    
    # Base chunk pools
    C_WARMUP = "res://src/gameplay/chunks/chunk_warmup.tscn"
    C_MINE = "res://src/gameplay/chunks/chunk_mine_gauntlet.tscn"
    C_BARRICADE = "res://src/gameplay/chunks/chunk_barricade_siege.tscn"
    C_REEF = "res://src/gameplay/chunks/chunk_reef_slalom.tscn"
    C_GUNNER = "res://src/gameplay/chunks/chunk_gunner_ambush.tscn"
    C_FINISH = "res://src/gameplay/chunks/chunk_finish_line.tscn"
    
    # Progressive sequence recipes
    if lvl == 1:
        chunks = [C_WARMUP, C_MINE, C_BARRICADE, C_FINISH]
    elif lvl == 2:
        chunks = [C_WARMUP, C_MINE, C_REEF, C_BARRICADE, C_FINISH]
    elif lvl == 3:
        chunks = [C_WARMUP, C_REEF, C_MINE, C_GUNNER, C_FINISH]
    elif lvl == 4:
        chunks = [C_WARMUP, C_MINE, C_BARRICADE, C_REEF, C_GUNNER, C_FINISH]
    elif lvl == 5:
        chunks = [C_WARMUP, C_REEF, C_MINE, C_BARRICADE, C_GUNNER, get_boss_chunk(5)]
    elif lvl == 6:
        chunks = [C_WARMUP, C_REEF, C_MINE, C_BARRICADE, C_FINISH]
    elif lvl == 7:
        chunks = [C_WARMUP, C_MINE, C_REEF, C_GUNNER, C_FINISH]
    elif lvl == 8:
        chunks = [C_WARMUP, C_BARRICADE, C_GUNNER, C_REEF, C_BARRICADE, C_FINISH]
    elif lvl == 9:
        chunks = [C_WARMUP, C_MINE, C_REEF, C_GUNNER, C_BARRICADE, C_FINISH]
    elif lvl == 10:
        chunks = [C_WARMUP, C_MINE, C_REEF, C_BARRICADE, C_GUNNER, get_boss_chunk(10)]
    else:
        # General algorithmic progression for L11-45
        pattern = [
            C_WARMUP,
            C_REEF if lvl % 2 == 0 else C_MINE,
            C_BARRICADE if lvl % 3 == 0 else C_GUNNER,
            C_MINE if lvl % 2 == 1 else C_REEF,
            C_GUNNER if lvl % 3 != 0 else C_BARRICADE,
        ]
        if lvl > 15:
            pattern.append(C_REEF if lvl % 2 == 1 else C_GUNNER)
        if lvl > 25:
            pattern.append(C_BARRICADE if lvl % 2 == 0 else C_MINE)
        if lvl > 35:
            pattern.append(C_GUNNER)
            
        if is_boss:
            pattern.append(get_boss_chunk(lvl))
        else:
            pattern.append(C_FINISH)
        chunks = pattern
        
    return chunks

def calculate_speed(lvl: int) -> float:
    # 6.5 m/s at L1 up to 12.0 m/s at L45
    return round(6.5 + (lvl - 1) * (5.5 / 44.0), 1)

def calculate_reward(lvl: int) -> int:
    is_boss = (lvl % 5 == 0)
    base = 50 + (lvl - 1) * 15
    if is_boss:
        base += 100 + (lvl // 5) * 50
    # User request: Reduce coins by 10% per level
    return int(round(base * 0.90))

def build_tres_content(lvl: int) -> str:
    biome_key = get_biome_key(lvl)
    b = BIOMES[biome_key]
    title = LEVEL_TITLES.get(lvl, f"Level {lvl}")
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
        biome_key = get_biome_key(lvl)
        b = BIOMES[biome_key]
        title = LEVEL_TITLES[lvl]
        chunks = get_chunk_sequence(lvl)
        dist = len(chunks) * 50.0
        
        # Update frontmatter
        content = re.sub(r'level_title:\s*".*?"', f'level_title: "{title}"', content)
        content = re.sub(r'biome_name:\s*".*?"', f'biome_name: "{b["name"]}"', content)
        content = re.sub(r'base_scroll_speed:\s*[\d\.]+', f'base_scroll_speed: {speed}', content)
        content = re.sub(r'completion_doubloon_reward:\s*\d+', f'completion_doubloon_reward: {reward}', content)
        
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)
            
        print(f"Synced doc: {fname} (L{lvl}) -> Biome: {b['name']}, Speed: {speed}, Reward: {reward}")

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
        print(f"Updated {filename}: {LEVEL_TITLES[lvl]} | Biome: {get_biome_key(lvl)} | Chunks: {len(get_chunk_sequence(lvl))} | Speed: {calculate_speed(lvl)}m/s")
        
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

