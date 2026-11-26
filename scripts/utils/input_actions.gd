class_name InputActions
extends RefCounted
## Central list of Input Map action names (Project Settings > Input Map).
## Use these constants instead of raw strings to avoid typos.

const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const INTERACT: StringName = &"interact"
const RUN: StringName = &"run"
const PAUSE: StringName = &"pause"
## Shows or hides the panel of the five models. Added at runtime by Settings (key M, gamepad Back).
const TOGGLE_MODELS: StringName = &"toggle_models"
