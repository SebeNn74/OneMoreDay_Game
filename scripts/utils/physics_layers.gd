@tool
class_name PhysicsLayers
extends RefCounted
## Bit masks of the 2D physics layers.
##   world         structural solids: walls, level bounds
##   player        the player's body
##   npc           NPC bodies (solid)
##   enemy         enemy bodies
##   interactable  zones the player can interact with (passive Areas)
##   decoration    solid props (furniture): block characters, not projectiles
##   hitbox        areas that deal damage (active: scan hurtboxes)
##   hurtbox       areas that receive damage (passive)
##   detection     sensor areas scanned by AI (e.g. enemy vision)
##   projectile    moving hazards that cross the level

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const NPC: int = 1 << 2
const ENEMY: int = 1 << 3
const INTERACTABLE: int = 1 << 4
const DECORATION: int = 1 << 5
const HITBOX: int = 1 << 6
const HURTBOX: int = 1 << 7
const DETECTION: int = 1 << 8
const PROJECTILE: int = 1 << 9

## What physically blocks each kind of body.
const PLAYER_BLOCKERS: int = WORLD | DECORATION | NPC
const ENEMY_BLOCKERS: int = WORLD | DECORATION
const PROJECTILE_BLOCKERS: int = WORLD
