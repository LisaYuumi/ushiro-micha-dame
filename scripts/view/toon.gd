class_name Toon
extends RefCounted
## A案「放課後ポップ」の塗り: アニメ塗り(2〜3段の陰影)+太い黒の輪郭線。
## 輪郭線は「少し大きくした裏返しのコピーを黒で描く」軽い方法(スマホのブラウザでも重くならない)。
## 色は GameConfig の見た目の設定から取る。

## アニメ塗り: 光の当たり方を3段階にする。リアルな陰影や光沢は使わない
const _TOON_CODE := """
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float shade_mid = 0.82;
uniform float shade_dark = 0.66;

void fragment() {
	ALBEDO = albedo.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.25 ? 1.0 : (ndl > -0.25 ? shade_mid : shade_dark);
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, vec3(band));
}
"""

## 輪郭線: 形の中心から外へ少しふくらませて、裏側だけを黒で描く
## (箱の角でも線が切れないように、法線ではなく中心からの向きでふくらませる)
const _OUTLINE_CODE := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.118, 0.106, 0.094, 1.0);
uniform float width = 0.03;

void vertex() {
	vec3 dir = length(VERTEX) > 0.0001 ? normalize(VERTEX) : NORMAL;
	VERTEX += normalize(mix(NORMAL, dir, 0.5)) * width;
}

void fragment() {
	ALBEDO = ink.rgb;
}
"""

## まとめた背景用の輪郭線: 箱ごとの中心(CUSTOM0)からふくらませる
const _OUTLINE_BATCHED_CODE := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.118, 0.106, 0.094, 1.0);
uniform float width = 0.03;

void vertex() {
	vec3 d = VERTEX - CUSTOM0.xyz;
	vec3 dir = length(d) > 0.0001 ? normalize(d) : NORMAL;
	VERTEX += normalize(mix(NORMAL, dir, 0.5)) * width;
}

void fragment() {
	ALBEDO = ink.rgb;
}
"""

static var _toon_shader: Shader
static var _outline_shader: Shader
static var _outline_batched_shader: Shader
## 同じ色・同じ太さの材質は使い回す(色ごとに1つ)
static var _cache := {}


## アニメ塗りの材質。outline > 0 なら、その太さ(メートル)の黒い輪郭線もつける
static func material(color: Color, outline: float = GameConfig.OUTLINE_WIDTH) -> Material:
	var key := "%s|%.3f" % [color.to_html(), outline]
	if _cache.has(key):
		return _cache[key]
	if _toon_shader == null:
		_toon_shader = Shader.new()
		_toon_shader.code = _TOON_CODE
		_outline_shader = Shader.new()
		_outline_shader.code = _OUTLINE_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _toon_shader
	mat.set_shader_parameter("albedo", color)
	if outline > 0.0:
		var line := ShaderMaterial.new()
		line.shader = _outline_shader
		line.set_shader_parameter("ink", GameConfig.COLOR_INK)
		line.set_shader_parameter("width", outline)
		mat.next_pass = line
	_cache[key] = mat
	return mat


## まとめた背景(StaticBatch)用の材質。塗りは同じ、輪郭線は箱ごとの中心からふくらませる
static func material_batched(color: Color, outline: float) -> Material:
	var key := "B|%s|%.3f" % [color.to_html(), outline]
	if _cache.has(key):
		return _cache[key]
	var base: ShaderMaterial = (material(color, 0.0) as ShaderMaterial).duplicate()
	if outline > 0.0:
		if _outline_batched_shader == null:
			_outline_batched_shader = Shader.new()
			_outline_batched_shader.code = _OUTLINE_BATCHED_CODE
		var line := ShaderMaterial.new()
		line.shader = _outline_batched_shader
		line.set_shader_parameter("ink", GameConfig.COLOR_INK)
		line.set_shader_parameter("width", outline)
		base.next_pass = line
	_cache[key] = base
	return base


## メッシュに材質をつけた MeshInstance3D を作る(影は落とさない: アニメ塗りなので)
static func mesh(m: Mesh, color: Color, outline: float = GameConfig.OUTLINE_WIDTH) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material(color, outline)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
