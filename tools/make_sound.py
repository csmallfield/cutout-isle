#!/usr/bin/env python3
"""Cutout Isle sound sheet: every recipe, the cue map and the music as .tres
files (open them in the Audio Kit dock or Sound Lab and tweak by ear).
Regenerate after editing:  python3 tools/make_sound.py

Sound sheet (no palette; shared reverb 0.35, small room, outdoors):
  swing          airy band-passed whoosh; combo step = intensity: louder,
                 longer, brighter on the finisher
  swing.charge   a big low whoosh with a thump under it
  hit.wood       knock (resonant click) on a woody thump: the dummy
  hit.flesh      a soft, low smack with a squelch: enemies
  hit.metal      a bright clang: armour, blocks
  block          a short dull clank
  step.grass     soft dull scuff        step.stone  sharp gritty tick
  step.sand      a hiss of grains       step.wood   hollow knock
  dash           fast rising whoosh     land        thump
  pickup         two rising glass notes (a fifth apart)
  enemy.alert    a quick rising blip    enemy.ko    a falling boing and a puff
  charge.full    a bright glass ping    heart       a low double thump (low HP)
  ambience       sea wash: a long slow noise swell, looped (continuous voice)
Music: "Isle" at 100 bpm in D dorian, explore (pluck arp, pad, soft perc)
and combat (adds kick, clap, a busier bass); the game queues sections on
the bar. Ducks under the effects.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.realpath(os.path.join(ROOT, "addons", "audio_kit", "..", ".."))
sys.path.insert(0, os.path.join(KIT, "tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

SFX = os.path.join(ROOT, "audio", "sfx")
MUS = os.path.join(ROOT, "audio", "music")
R = "res://audio/sfx/"
M = "res://audio/music/"
S = "res://addons/audio_kit/sequencer/"
I = {"intensity": {"gain_db": [-10.0, 0.0]}}
# Note: an intensity binding on gain_db sets the level outright (it replaces
# gain_db), so balance bound recipes through their binding range.


def sfx(name, **f):
    recipe(os.path.join(SFX, name + ".tres"), **f)
    return R + name + ".tres"


cues = {}
# ---- combat
cues["swing"] = sfx("swing", voice="whoosh", seed=101, send=0.12, gain_db=-5.0,
    params={"length_s": 0.2, "low_hz": 380.0, "high_hz": 2600.0, "peak": 0.35, "shape": 2.2, "mode": "band", "q": 1.4, "noise": "pink"},
    vary={"length_s": 0.18, "high_hz": 0.22, "low_hz": 0.15, "peak": 0.2, "q": 0.25},
    bind={"intensity": {"gain_db": [-9.0, 0.0], "length_s": [0.17, 0.27], "high_hz": [2100.0, 3400.0]}})
cues["swing.charge"] = sfx("swing_charge", voice="whoosh", seed=102, send=0.2, gain_db=-3.0,
    params={"length_s": 0.42, "low_hz": 160.0, "high_hz": 2200.0, "peak": 0.45, "shape": 1.8, "mode": "band", "q": 1.1, "noise": "pink"},
    layers=[{"voice": "boing", "params": {"start_hz": 140.0, "end_hz": 50.0, "drop_s": 0.12, "decay_s": 0.25, "sub": 0.7, "click": 0.1},
             "gain_db": -8.0, "offset_s": 0.12}],
    vary={"length_s": 0.1, "high_hz": 0.15})
cues["hit.wood"] = sfx("hit_wood", voice="click", seed=103, send=0.2,
    params={"freq_hz": 900.0, "mode": "band", "q": 9.0, "decay_s": 0.05, "body_hz": 220.0, "body": 0.7},
    layers=[{"voice": "boing", "params": {"start_hz": 180.0, "end_hz": 70.0, "drop_s": 0.08, "decay_s": 0.12, "sub": 0.6, "click": 0.2}, "gain_db": -6.0}],
    vary={"freq_hz": 0.18, "body_hz": 0.15, "decay_s": 0.2},
    bind={"intensity": {"gain_db": [-10.0, 0.0], "decay_s": [0.04, 0.08]}})
cues["hit.flesh"] = sfx("hit_flesh", voice="boing", seed=104, send=0.15,
    params={"start_hz": 210.0, "end_hz": 60.0, "drop_s": 0.05, "decay_s": 0.1, "sub": 0.8, "click": 0.5, "click_hz": 2400.0},
    layers=[{"voice": "click", "params": {"freq_hz": 1600.0, "mode": "low", "q": 0.7, "attack_s": 0.002, "decay_s": 0.03}, "gain_db": -9.0}],
    vary={"start_hz": 0.2, "decay_s": 0.25, "click_hz": 0.3}, bind=I)
cues["hit.metal"] = sfx("hit_metal", voice="mallet", seed=105, send=0.3,
    params={"freq_hz": 1250.0, "material": "metal", "hardness": 0.9, "decay_s": 0.5},
    layers=[{"voice": "click", "params": {"freq_hz": 5200.0, "mode": "band", "q": 3.0, "decay_s": 0.01}, "gain_db": -4.0}],
    vary={"freq_hz": 0.08, "decay_s": 0.2}, bind=I)
cues["block"] = sfx("block", voice="click", seed=106, send=0.15,
    params={"freq_hz": 1900.0, "mode": "band", "q": 5.0, "decay_s": 0.04, "body_hz": 300.0, "body": 0.5},
    vary={"freq_hz": 0.1}, bind=I)
cues["charge.full"] = sfx("charge_full", voice="mallet", seed=107, send=0.3, gain_db=-8.0,
    params={"freq_hz": 1318.5, "material": "glass", "hardness": 0.7, "decay_s": 0.35}, vary={"freq_hz": 0.02})
cues["heart"] = sfx("heart", voice="boing", seed=108, gain_db=-4.0,
    params={"start_hz": 90.0, "end_hz": 45.0, "drop_s": 0.06, "decay_s": 0.09, "sub": 0.5, "click": 0.0},
    layers=[{"voice": "boing", "params": {"start_hz": 80.0, "end_hz": 42.0, "drop_s": 0.06, "decay_s": 0.08, "sub": 0.5, "click": 0.0},
             "gain_db": -5.0, "offset_s": 0.16}])

# ---- movement: footsteps by surface (intensity = speed)
STEP = {"intensity": {"gain_db": [-16.0, -6.0]}}
cues["step.grass"] = sfx("step_grass", voice="click", seed=111, send=0.08,
    params={"freq_hz": 1400.0, "mode": "low", "q": 0.8, "attack_s": 0.004, "decay_s": 0.035, "body_hz": 110.0, "body": 0.35},
    layers=[{"voice": "whoosh", "params": {"length_s": 0.07, "low_hz": 500.0, "high_hz": 2600.0, "peak": 0.2, "shape": 1.2, "noise": "pink"}, "gain_db": -12.0}],
    vary={"freq_hz": 0.3, "decay_s": 0.25, "body_hz": 0.15}, bind=STEP)
cues["step.stone"] = sfx("step_stone", voice="click", seed=112, send=0.12,
    params={"freq_hz": 3200.0, "mode": "band", "q": 2.2, "attack_s": 0.0005, "decay_s": 0.018, "body_hz": 160.0, "body": 0.3},
    layers=[{"voice": "static", "params": {"hiss": 0.4, "color_hz": 5000.0, "crackles_per_s": 120.0, "length_s": 0.05}, "gain_db": -18.0}],
    vary={"freq_hz": 0.2, "decay_s": 0.3}, bind={"intensity": {"gain_db": [-18.5, -8.5]}})
cues["step.sand"] = sfx("step_sand", voice="whoosh", seed=113, send=0.05,
    params={"length_s": 0.11, "low_hz": 1200.0, "high_hz": 6500.0, "peak": 0.25, "shape": 1.0, "mode": "high", "noise": "white"},
    layers=[{"voice": "click", "params": {"freq_hz": 600.0, "mode": "low", "attack_s": 0.006, "decay_s": 0.04, "body_hz": 90.0, "body": 0.4}, "gain_db": -6.0}],
    vary={"length_s": 0.3, "high_hz": 0.2}, bind={"intensity": {"gain_db": [-22.0, -12.0]}})
cues["step.wood"] = sfx("step_wood", voice="click", seed=114, send=0.15,
    params={"freq_hz": 700.0, "mode": "band", "q": 6.0, "attack_s": 0.001, "decay_s": 0.05, "body_hz": 180.0, "body": 0.8},
    vary={"freq_hz": 0.15, "body_hz": 0.12, "decay_s": 0.2}, bind={"intensity": {"gain_db": [-23.0, -13.0]}})
cues["dash"] = sfx("dash", voice="whoosh", seed=115, send=0.1, gain_db=-4.0,
    params={"length_s": 0.22, "low_hz": 600.0, "high_hz": 4200.0, "peak": 0.25, "shape": 2.5, "mode": "band", "q": 1.0, "noise": "white"},
    vary={"length_s": 0.15, "high_hz": 0.2})
cues["land"] = sfx("land", voice="boing", seed=116, send=0.1,
    params={"start_hz": 150.0, "end_hz": 55.0, "drop_s": 0.07, "decay_s": 0.14, "sub": 0.7, "click": 0.3, "click_hz": 3000.0},
    vary={"start_hz": 0.15}, bind={"intensity": {"gain_db": [-15.0, -5.0]}})

# ---- world
cues["pickup"] = sfx("pickup", voice="mallet", seed=121, send=0.35, gain_db=-10.0,
    params={"freq_hz": 1174.7, "material": "glass", "hardness": 0.6, "decay_s": 0.3},
    layers=[{"voice": "mallet", "params": {"freq_hz": 1760.0, "material": "glass", "hardness": 0.6, "decay_s": 0.4}, "offset_s": 0.07}],
    vary={"freq_hz": 0.015})
cues["enemy.alert"] = sfx("enemy_alert", voice="tone", seed=122, send=0.15, gain_db=-8.0,
    params={"wave": "square", "freq_hz": 520.0, "end_hz": 900.0, "glide_s": 0.08, "attack_s": 0.002, "decay_s": 0.09, "sustain": 0.0, "release_s": 0.02},
    vary={"freq_hz": 0.06})
cues["enemy.ko"] = sfx("enemy_ko", voice="boing", seed=123, send=0.25, gain_db=-3.0,
    params={"start_hz": 420.0, "end_hz": 70.0, "drop_s": 0.22, "decay_s": 0.35, "wobble_hz": 9.0, "wobble_semitones": 3.0, "sub": 0.4, "click": 0.3},
    layers=[{"voice": "static", "params": {"hiss": 0.8, "color_hz": 2500.0, "length_s": 0.25}, "gain_db": -16.0, "offset_s": 0.05}],
    vary={"start_hz": 0.1})

# ---- the ambience loop (a continuous voice loops it at a gliding rate)
recipe(os.path.join(SFX, "sea_wash.tres"), voice="whoosh", seed=131, gain_db=-14.0, send=0.2,
       params={"length_s": 3.2, "low_hz": 220.0, "high_hz": 1400.0, "peak": 0.42, "shape": 1.2, "mode": "low", "noise": "pink", "slope_db": 12.0})

cue_map(os.path.join(ROOT, "audio", "cue_map.tres"), cues,
        reverb={"room": 0.35, "damp": 0.6, "width": 1.0, "quality": "small", "return_db": -4.0})
# ducking: music dips under the effects
with open(os.path.join(ROOT, "audio", "cue_map.tres"), "a") as f:
    f.write('duck = {"depth_db": 7.0, "full_at_db": -18.0, "release_s": 0.3}\n')

# ---- music: "Isle", 100 bpm, D dorian (Dm7 - G - Fmaj7 - C over four bars)
recipe(os.path.join(MUS, "pluck.tres"), voice="pluck", seed=201, send=0.3, vary={"brightness": 0.1}, vary_variants=4,
       params={"brightness": 0.55, "decay_s": 0.45, "tone_hz": 3200.0}, bind={"intensity": {"gain_db": [-8.0, 0.0]}})
recipe(os.path.join(MUS, "pad.tres"), voice="wavetable", seed=202, send=0.5,
       params={"position": 0.35, "unison": 4, "detune_cents": 14.0, "cutoff_hz": 1100.0, "env_octaves": 0.4, "filter_decay_s": 1.2,
               "q": 0.6, "attack_s": 0.6, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.6})
recipe(os.path.join(MUS, "bass.tres"), voice="wavetable", seed=203,
       params={"position": 0.5, "sub": 0.35, "cutoff_hz": 420.0, "env_octaves": 1.6, "filter_decay_s": 0.15, "q": 1.1,
               "attack_s": 0.004, "decay_s": 0.16, "sustain": 0.35, "release_s": 0.06}, bind={"intensity": {"gain_db": [-8.0, 0.0]}})
recipe(os.path.join(MUS, "shaker.tres"), voice="hat", seed=204, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.05, "tone_hz": 7000.0, "metal": 0.15}, bind={"intensity": {"gain_db": [-10.0, 0.0]}})
recipe(os.path.join(MUS, "kick.tres"), voice="kick", seed=205,
       params={"tune_hz": 52.0, "punch": 2.2, "decay_s": 0.22, "click": 0.25}, bind={"intensity": {"gain_db": [-6.0, 0.0]}})
recipe(os.path.join(MUS, "clap.tres"), voice="clap", seed=206, send=0.3,
       params={"color_hz": 1500.0, "tail_decay_s": 0.09}, bind={"intensity": {"gain_db": [-6.0, 0.0]}})

ROOTS = [50, 55, 53, 48]               # D, G, F, C (MIDI)
CHORDS = [[0, 3, 7, 10], [0, 4, 7, 12], [0, 4, 7, 11], [0, 4, 7, 12]]
arp = []
for b in range(4):
    tones = [ROOTS[b] + 12 + t for t in CHORDS[b]]
    for s in range(16):
        arp.append(tones[[0, 2, 1, 3, 2, 1, 3, 2][s % 8]] + (12 if s % 8 == 7 else 0))
bass_slow = [ROOTS[b] - 12 for b in range(4) for _ in range(2)]
bass_busy = [ROOTS[b] - 12 + [0, 0, 7, 0, 12, 0, 7, 10][s % 8] for b in range(4) for s in range(8)]
pluck = {"name": "pluck", "recipe": M + "pluck.tres", "steps": "x.o.x.o.x.o.xo.o" * 4, "notes": arp[::1], "gain_db": -9.0, "pan": -0.15}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 15, "notes": ROOTS, "chord": [0, 7, 12, 15], "gate": 15.5, "gain_db": -11.0}
shaker = {"name": "shaker", "recipe": M + "shaker.tres", "steps": ".o.x.o.x.o.x.oox", "length": 16, "gain_db": -17.0, "pan": 0.25}
bass_e = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.......x......." * 4, "notes": bass_slow, "gate": 6.0, "gain_db": -6.0}
bass_c = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.xxx.x.x.xxx.x." * 4, "notes": bass_busy, "gate": 0.8, "gain_db": -4.0}
kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x.....X.x...", "length": 16, "gain_db": -3.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -8.0}

P = "AKPattern"
resource(os.path.join(MUS, "explore.tres"), P, S + "pattern.gd", {"steps": 64, "seed": 11, "swing": 0.56, "lanes": [pluck, pad, shaker, bass_e]}, typed={"lanes"})
resource(os.path.join(MUS, "combat.tres"), P, S + "pattern.gd", {"steps": 64, "seed": 12, "swing": 0.54, "lanes": [pluck, pad, shaker, bass_c, kick, clap]}, typed={"lanes"})
resource(os.path.join(MUS, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 100.0, "beats_per_bar": 4, "offset_s": 0.0})
resource(os.path.join(MUS, "isle_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "explore", "bars": 4, "patterns": [M + "explore.tres"]},
        {"name": "combat", "bars": 4, "patterns": [M + "combat.tres"]},
    ],
    "gain_db": -6.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d cues, the sea-wash loop, the cue map and the music (2 sections)" % len(cues))
