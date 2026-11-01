class_name SandfallWorldCanvas
extends Control

# Presentation only: copied native RG8 values, a material appearance lookup,
# and a bounded sixteen-body graph. There is no actor overlay or input polling.
const WORLD_SIZE: Vector2i = Vector2i(1024, 1024)
const INITIAL_VIEW: Vector2 = Vector2(480, 270)
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 4.0
const MAX_BODIES: int = 16
const MATERIAL_SHADER: String = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D material_lut : filter_nearest, repeat_disable;
uniform vec2 camera_origin = vec2(0.0);
uniform vec2 view_size = vec2(480.0, 270.0);
uniform int body_count = 0;
uniform int presentation_theme = 0;
uniform vec4 body_data[16];
uniform float body_rotation[16];

bool inside_body(vec2 pixel, vec4 body, float rotation) {
    vec2 d = pixel + vec2(0.5) - body.xy;
    float c = cos(rotation);
    float s = sin(rotation);
    vec2 local = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);
    return abs(local.x) < body.z * 0.5 && abs(local.y) < body.w * 0.5;
}

void fragment() {
    vec2 pixel = floor(camera_origin + clamp(UV, vec2(0.0), vec2(0.999999)) * view_size);
    vec2 material_state = texture(TEXTURE, (pixel + vec2(0.5)) / vec2(1024.0)).rg;
    float id = floor(material_state.r * 255.0 + 0.5);
    float variation = mod(pixel.x * 17.0 + pixel.y * 29.0, 64.0);
    vec4 colour = texture(material_lut, vec2((variation + 0.5) / 64.0, (id + 0.5) / 256.0));
    if (id == 3.0) {
        colour.rgb *= 0.8 + 0.2 * material_state.g;
    }
    if (presentation_theme == 1) {
        float luminance = dot(colour.rgb, vec3(0.2126, 0.7152, 0.0722));
        colour.rgb = mix(colour.rgb, vec3(luminance), 0.45);
    } else if (presentation_theme == 2) {
        colour.rgb = clamp((colour.rgb - vec3(0.16)) * 1.35, vec3(0.0), vec3(1.0));
    }
    for (int index = 0; index < 16; index++) {
        if (index >= body_count) { break; }
        if (inside_body(pixel, body_data[index], body_rotation[index])) {
            colour = vec4(0.95, 0.22, 0.18, 1.0);
            break;
        }
    }
    COLOR = vec4(colour.rgb, 1.0);
}
"""

var _host: Node
var _image: Image
var _texture: ImageTexture
var _shader_material: ShaderMaterial
var _camera_origin: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _last_packet_serial: int = 0
var _uploads: int = 0
var _rejections: int = 0
var _last_error: String = ""
var _last_patch_count: int = 0
var _last_payload_bytes: int = 0
var _force_full_required: bool = true
var _rendered_body_ids: Array = []
var _rendered_body_count: int = 0
var _presentation_theme: String = "classic"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image = Image.create_empty(WORLD_SIZE.x, WORLD_SIZE.y, false, Image.FORMAT_RG8)
	_texture = ImageTexture.create_from_image(_image)
	var shader: Shader = Shader.new()
	shader.code = MATERIAL_SHADER
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("material_lut", CyberMaterialAppearanceLut.create_texture())
	material = _shader_material
	resized.connect(_camera_changed)


func bind_host(host: Node) -> void:
	_host = host
	fit()
	publish(true)


func publish(force_full: bool = false) -> bool:
	if not is_instance_valid(_host):
		return false
	var host_state: Dictionary = _host.state()
	_update_body_parameters(host_state)
	if not bool(host_state.get("ready", false)):
		return false
	var packet: Dictionary = _host.take_render_snapshot(force_full or _force_full_required)
	if bool(packet.get("failed", false)):
		_last_error = str(packet.get("error", "Native render publication failed"))
		_rejections += 1
		_force_full_required = true
		return false
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	if rectangles.is_empty() and cells.is_empty():
		queue_redraw()
		return true
	var validation: String = validate_packet(rectangles, cells, int(packet.get("channels", 0)))
	if not validation.is_empty():
		_last_error = validation
		_rejections += 1
		_force_full_required = true
		return false
	# Every range was validated before this owned Image is changed. Snapshot
	# packed values are copies; later native publication cannot mutate them.
	for offset: int in range(0, rectangles.size(), 6):
		var width: int = rectangles[offset + 2]
		var height: int = rectangles[offset + 3]
		var first: int = rectangles[offset + 4]
		var stride: int = rectangles[offset + 5]
		var row_bytes: int = width * 2
		var compact: PackedByteArray
		if stride == row_bytes:
			compact = cells.slice(first, first + row_bytes * height)
		else:
			compact = PackedByteArray()
			for row: int in range(height):
				compact.append_array(cells.slice(first + row * stride, first + row * stride + row_bytes))
		var patch: Image = Image.create_from_data(width, height, false, Image.FORMAT_RG8, compact)
		_image.blit_rect(patch, Rect2i(0, 0, width, height), Vector2i(rectangles[offset], rectangles[offset + 1]))
	_texture.update(_image)
	_last_packet_serial = int(packet.get("serial", 0))
	_last_patch_count = rectangles.size() / 6
	_last_payload_bytes = cells.size()
	_uploads += 1
	_last_error = ""
	_force_full_required = false
	queue_redraw()
	return true


static func validate_packet(rectangles: PackedInt32Array, cells: PackedByteArray, channels: int) -> String:
	if channels != 2:
		return "Render packet must contain RG8 channels"
	if rectangles.is_empty() or rectangles.size() % 6 != 0:
		return "Render rectangle metadata must contain complete six-integer records"
	if cells.is_empty():
		return "Render payload is empty"
	for offset: int in range(0, rectangles.size(), 6):
		var x: int = rectangles[offset]
		var y: int = rectangles[offset + 1]
		var width: int = rectangles[offset + 2]
		var height: int = rectangles[offset + 3]
		var first: int = rectangles[offset + 4]
		var stride: int = rectangles[offset + 5]
		if x < 0 or y < 0 or width <= 0 or height <= 0 \
				or x + width > WORLD_SIZE.x or y + height > WORLD_SIZE.y:
			return "Render patch is outside the world"
		if first < 0 or stride < width * 2 \
				or first + (height - 1) * stride + width * 2 > cells.size():
			return "Render patch exceeds the copied payload"
	return ""


func content_rect() -> Rect2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var factor: float = minf(size.x / INITIAL_VIEW.x, size.y / INITIAL_VIEW.y)
	var fitted: Vector2 = INITIAL_VIEW * factor
	return Rect2((size - fitted) * 0.5, fitted)


func global_content_rect() -> Rect2:
	var local: Rect2 = content_rect()
	var transform: Transform2D = get_global_transform_with_canvas()
	return Rect2(transform * local.position, (transform * local.end) - (transform * local.position))


func global_to_world(global_point: Vector2) -> Vector2:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * global_point
	var fitted: Rect2 = content_rect()
	if fitted.size.x <= 0.0 or fitted.size.y <= 0.0:
		return _camera_origin
	return _camera_origin + (local - fitted.position) / fitted.size * _view_size()


func pan(delta_pixels: Vector2) -> void:
	var fitted: Rect2 = content_rect()
	if not delta_pixels.is_finite() or fitted.size.x <= 0.0 or fitted.size.y <= 0.0:
		return
	_camera_origin -= delta_pixels / fitted.size * _view_size()
	_camera_changed()


func zoom_at(factor: float, global_anchor: Vector2) -> void:
	if not is_finite(factor) or factor <= 0.0 or not global_anchor.is_finite():
		return
	var before: Vector2 = global_to_world(global_anchor)
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_camera_origin += before - global_to_world(global_anchor)
	_camera_changed()


func fit() -> void:
	_zoom = 1.0
	_camera_origin = Vector2.ZERO
	_camera_changed()


func set_initial_camera(camera: Dictionary) -> void:
	var origin: Array = camera.get("origin", [0.0, 0.0])
	var view_size: Array = camera.get("size", [480.0, 270.0])
	if origin.size() != 2 or view_size.size() != 2 or float(view_size[0]) <= 0.0:
		return
	_zoom = clampf(float(camera.get("zoom", 1.0)), MIN_ZOOM, MAX_ZOOM)
	_camera_origin = Vector2(float(origin[0]), float(origin[1]))
	_camera_changed()


func set_presentation_style(style: Dictionary) -> void:
	var theme: String = str(style.get("theme", "classic"))
	if theme == _presentation_theme:
		return
	_presentation_theme = theme
	_shader_material.set_shader_parameter("presentation_theme", SandfallPresentationModel.THEMES.find(theme))
	queue_redraw()


func state() -> Dictionary:
	var content: Rect2 = global_content_rect()
	var dimensions: Vector2 = _view_size()
	return {
		"content_rect": [content.position.x, content.position.y, content.size.x, content.size.y],
		"camera_origin": [_camera_origin.x, _camera_origin.y],
		"view_size": [dimensions.x, dimensions.y], "zoom": _zoom,
		"render_uploads": _uploads, "render_rejections": _rejections,
		"render_error": _last_error, "render_packet_serial": _last_packet_serial,
		"render_patch_count": _last_patch_count, "render_payload_bytes": _last_payload_bytes,
		"projection": "copied native RG8 / material appearance LUT / bounded rigid-body overlay",
		"body_capacity": MAX_BODIES, "body_count": _rendered_body_count, "body_ids": _rendered_body_ids.duplicate(),
		"presentation_theme": _presentation_theme,
	}


func _view_size() -> Vector2:
	return INITIAL_VIEW / _zoom


func _camera_changed() -> void:
	var dimensions: Vector2 = _view_size()
	_camera_origin = _camera_origin.clamp(Vector2.ZERO, Vector2(WORLD_SIZE) - dimensions)
	if _shader_material != null:
		_shader_material.set_shader_parameter("camera_origin", _camera_origin)
		_shader_material.set_shader_parameter("view_size", dimensions)
	queue_redraw()


func _update_body_parameters(host_state: Dictionary) -> void:
	var bodies: Array = host_state.get("body_states", [])
	var sizes: Array = host_state.get("body_sizes", [])
	var ids: Array = host_state.get("body_ids", [])
	var body_data: PackedVector4Array = PackedVector4Array()
	var rotations: PackedFloat32Array = PackedFloat32Array()
	body_data.resize(MAX_BODIES)
	rotations.resize(MAX_BODIES)
	_rendered_body_count = mini(MAX_BODIES, mini(bodies.size(), sizes.size()))
	_rendered_body_ids = ids.slice(0, _rendered_body_count)
	for index: int in range(MAX_BODIES):
		body_data[index] = Vector4(-4096, -4096, 0, 0)
		rotations[index] = 0.0
		if index < _rendered_body_count:
			body_data[index] = Vector4(bodies[index][0], bodies[index][1], sizes[index][0], sizes[index][1])
			rotations[index] = float(bodies[index][2])
	_shader_material.set_shader_parameter("body_count", _rendered_body_count)
	_shader_material.set_shader_parameter("body_data", body_data)
	_shader_material.set_shader_parameter("body_rotation", rotations)


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, content_rect(), false)
