# Cutout Isle: results

Where the prototype stands after phase 7, measured against what the brief
(`godot-motion-kit` branch `docs/live-game-handoff`,
`docs/HANDOFF_procedural_action_prototype.md`) said it must prove.

Everything here was built and checked in a cloud container. It renders with software GL on shared
CPU cores and falls back to the Compatibility renderer. **None of the numbers below are frame
rates or GPU costs.** They are CPU script costs, and the frame rate needs Chris's 3080.

## Phases

| Phase | What it added |
|---|---|
| 1 | Look-and-feel spike: flat-shaded outlined island, orthographic camera, hit-stop, shake |
| 2a | Cutout rig in three views (front, back, side) with a paper turn, IK limbs, look-at |
| 2b | Planted feet (MotionGait), legs driven by the gait, footsteps |
| 3 | Scarf, pouch and dummy tag on verlet chains; squash and stretch |
| 4 | Authored moves (MotionPoseCurve): 3-hit combo, charged swing, smear, impact stars |
| 5 | Sound sheet, ground surfaces, live voices, music driven by game state, dash |
| 6 | The island chunk, a cave with a lens blend, blobs and grunts, the HUD |
| 7 | Consolidation: kit helpers, kit example scene, skill sections, this note |

## The five goals

**1. Curves driven by game events instead of a timeline: proven.**
Every reaction is a pure function of "frames since event", read from a MotionClock:

- hit flash, squash, impact stars, the HUD's heart drain and combo pop;
- the move curves themselves, whose markers set the hit window, buffer and cancel frames.

Followers use springs: the camera, the head aim, the dummy's wobble.
Hit-stop is a freeze envelope on a clock. Each entity has its own clock (parented to the world
clock), so per-entity and global hit-stop are one switch (F3). Physics runs at a fixed step and is
read back with the interpolation fraction, and posing happens in `_process`. In captures the two
compose without visible jitter. Jitter at a high refresh rate is still to be checked on a real
display (see below).

**2. Locomotion and secondary motion that read as hand-made: largely proven, your eye decides.**
Authored key poses carry the shape and the procedural layers stay small on top of them:

- the swings are hand-keyed arcs with per-view overrides;
- gait bob and lean are a few centimetres;
- the chains have shape memory, so the scarf trails and settles rather than flapping.

Every layer can be toggled in the overlay, so each one can be judged on its own. Two things to
judge in play, not from video:

- whether chains should flow through hit-stop (H);
- whether the paper turn (0) reads as charming or as a glitch at your frame rate.

**3. The flat, outlined 3D look holds up in play: proven in captures.**
What the captures show working:

- the orthographic camera follows the hero, with a lens blend toward perspective in the cave;
- the hero walks behind trees and props;
- seven enemies and the dummy are on screen together.

Two problems came up and were fixed:

- outline z-fighting between cutout layers (layer step 0.004 against an outline bias of 0.001);
- grass rendering black under Compatibility (MultiMesh colours instead of INSTANCE_CUSTOM).

Forward+ on the 3080 is the real test of the look. The cloud only ever saw Compatibility.

**4. Live procedural sound with variety and no sample library: proven in captures. Listen with
your own ears.**
All sound comes from recipes:

- 17 one-shot cues, a looped sea wash, and four live voices (wind, charge riser, low-health drone
  plus heartbeat);
- a two-section song queued on the bar from game state.

Variety comes from pools. A swing has 8 takes at 3 intensity steps, and takes are picked at random
with no immediate repeat. Each footstep surface (grass, stone, sand, wood) has its own 8 to 10
takes.

This is not "every swing unique". It is a rotation of 8 takes per intensity, which I think reads
as unique at game pace. If it doesn't, the cheap step up is more variants (load time grows
linearly). The next step after that is a small per-trigger pitch or filter jitter in AKLive.

**5. 60 fps on the 3080 with headroom: only you can show this.**
I measured CPU script cost per system over a 20 s autoplay bench at a fixed 60 fps, headless in
the cloud:

| System | 7 enemies + dummy | + 10 extra dummies |
|---|---|---|
| hero (update + pose) | 0.39 ms | 0.31 ms |
| enemies | 0.46 ms | 0.57 ms |
| chains | 0.09 ms | 0.22 ms |
| gait, secondary, camera, world, sound, dummies | 0.33 ms | 0.55 ms |
| **total GDScript** | **1.28 ms** | **1.64 ms** |

The brief's budget is under 2 ms of GDScript and under 1 ms of chains, with the hero and 10
enemies. Both runs are inside it on a slower, shared CPU. The 10 extra actors are dummies, which
are cheaper than grunts, so a run with 10 real grunts is the honest test. Enemies off screen skip
posing. Sound pools take about 1.1 s to render at load.

## What to profile on the 3080

1. Run `godot --path . -- --autoplay` with F1 on and watch the frame-time readout.
   - The budget says no frame over 20 ms in 60 s. Press R to reset the worst-frame readout after
     loading.
   - Note the draw-call count with the cave and all the enemies on screen.
2. Use Godot's profiler for the GPU side. The flat shaders are unlit vertex colour plus instance
   uniforms, so I expect very little there. The outline passes and the grass MultiMesh are the
   likeliest costs.
3. Check physics-interpolation jitter at your refresh rate (above 60 Hz). Watch the hero's feet
   against the ground and the scarf.
4. Check for shader-compile hitches the first time each of these appears:
   - a hit flash;
   - the cave;
   - the charge ring.

   MotionWarmup draws every material once at load, and Forward+ ubershaders should cover the rest.
5. Compare F3 (per-entity against global hit-stop) and H (chains through hit-stop) by feel.

## Open items

- **One object leaks at exit since phase 7.** It happens on most headless runs, only at shutdown,
  and nothing grows at runtime.
  - Bisecting pinned it to the switch from the prototype's own `PerfProbe` to the kit's
    `MotionPerfProbe`. The two scripts have the same code, and a minimal script using the kit
    class doesn't leak.
  - The leaked object has an empty class name and isn't an orphan node.
  - It is harmless, but worth one look with the debugger's object monitor on Windows.
- **Enemies steer directly**, with no NavigationAgent3D. That is enough for one open chunk, not for
  corridors.
- **The art is a first attempt** at the Ditto style, as agreed: three hero views, a blob, a grunt,
  props.
- **The kits are private**, so this public repo only builds for people with access to them.

## What moved into the kits

All of it is documented in each kit's API.md and skill.

**Motion kit** (`feat/live-game`):

- MotionClock;
- MotionTrauma;
- MotionSpring2D and MotionSpring3D;
- MotionAimSpring;
- MotionIK;
- MotionGait and its settings;
- MotionChain;
- MotionSquash;
- MotionPoseCurve;
- MotionRipples;
- MotionPerfProbe;
- MotionCutoutRig (now with `card()`);
- MotionCutout;
- MotionRibbon3D;
- MotionGrass3D;
- MotionWarmup;
- instanced flat and cutout shaders;
- skill section 9, "Live game systems";
- the example scene `demo/live/live_example.tscn`.

**Audio kit** (`feat/live-game`): variant pools in AKLive and AKLivePlayer, and skill section 4a,
"Sound for a live game".

What stays here is game-specific:

- the state machines;
- the moves;
- the HUD;
- the island layout;
- the sound sheet;
- the autoplay bot.
