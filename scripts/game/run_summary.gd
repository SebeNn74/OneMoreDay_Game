class_name RunSummary
extends RefCounted
## What the endings need to know about a finished day. Plain data, built by RunLog.

## Value of depleted_stat when no stat ran out (the clock of a challenge, or unknown).
const NO_STAT: int = -1

var is_victory: bool = false
## StatDefinition.Type of the stat that ran out, or NO_STAT.
var depleted_stat: int = NO_STAT
## Stats at the end of the day.
var money: float = 0.0
var energy: float = 0.0
var time: float = 0.0
## The player bought the game from the street vendor (V-06).
var bought_game: bool = false
## The player helped, or accepted help from, an NPC (V-03).
var helped: bool = false
## El Marcador was running when the day ended (a stat ran out during the encounter).
var challenge_active: bool = false
var challenge_success: bool = false
var challenge_failed: bool = false
## Seconds left on the clock when the folders were delivered.
var challenge_seconds_left: float = 0.0
## The last time money went down it was a theft: EV-20 or a hit of a hostile that takes money (D-04).
var last_money_loss_was_theft: bool = false

## For the end-of-day summary (not used by EndingResolver).
## Events that happened, as their text; decisions as "speaker: option".
var events: PackedStringArray = []
var decisions: PackedStringArray = []
var hostile_hits: int = 0
## Risky options picked (model 3) and how many of them went wrong.
var risks_taken: int = 0
var risks_lost: int = 0
