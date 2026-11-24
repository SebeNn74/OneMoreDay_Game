class_name FatigueOverlay
extends CanvasLayer
## Model 5 made visible: below the fatigue threshold (the same one that slows the player down)
## the level loses its color and the edges darken, more the lower the energy.
## Drawn over the level and under the HUD, so the numbers stay readable.

const DRAW_LAYER: int = 5  # Above the level, below the HUD (10).
## How gray and dark the screen gets at 0 energy.
const MAX_AMOUNT: float = 0.95
## Seconds to follow a change of energy (a sudden hit does not flash the screen).
const SMOOTHING_SECONDS: float = 0.5
const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	float edge = smoothstep(0.35, 0.95, distance(SCREEN_UV, vec2(0.5)));
	color = mix(color, vec3(gray), amount);
	color *= 1.0 - edge * amount * 0.85;
	COLOR = vec4(color, 1.0);
}
"""

var _rect: ColorRect
var _material: ShaderMaterial
var _amount: float = 0.0


func _ready() -> void:
	layer = DRAW_LAYER
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	var copy: BackBufferCopy = BackBufferCopy.new()  # The rect reads the level drawn under it.
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)


func _process(delta: float) -> void:
	var threshold: float = Simulation.DYNAMICS_CONFIG.fatigue_threshold
	var energy: float = StatsManager.get_value(StatDefinition.Type.ENERGY)
	# Power 0.4: the change is already clear just under the threshold.
	var target: float = pow(clampf((threshold - energy) / threshold, 0.0, 1.0), 0.4) * MAX_AMOUNT
	_amount = move_toward(_amount, target, delta / SMOOTHING_SECONDS)
	_rect.visible = _amount > 0.01  # No screen copy while the player is fine.
	_material.set_shader_parameter("amount", _amount)
