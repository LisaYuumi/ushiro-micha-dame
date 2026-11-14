class_name VolumePanel
extends VBoxContainer
## 音量のスライダー: 「全体」「BGM」「効果音」(0〜100%)。動かすとすぐ大きさが変わり、端末に保存する。
## ロビーと ⚙メニューの両方で使う

const ROWS := [["全体", "vol_master"], ["BGM", "vol_bgm"], ["効果音", "vol_sfx"]]

var _sliders := {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var title := UiStyle.label("🔊 音の大きさ", 26, GameConfig.COLOR_INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	for r in ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		add_child(row)
		var l := UiStyle.label(r[0], 24, GameConfig.COLOR_INK)
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(320, 48)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.focus_mode = Control.FOCUS_NONE
		# 指で押しやすいように、太いみぞと大きなつまみ
		var groove := StyleBoxFlat.new()
		groove.bg_color = Color("D9D2C5")
		groove.set_corner_radius_all(8)
		groove.content_margin_top = 8
		groove.content_margin_bottom = 8
		sl.add_theme_stylebox_override("slider", groove)
		var filled := StyleBoxFlat.new()
		filled.bg_color = GameConfig.COLOR_ACCENT
		filled.set_corner_radius_all(8)
		filled.content_margin_top = 8
		filled.content_margin_bottom = 8
		sl.add_theme_stylebox_override("grabber_area", filled)
		sl.add_theme_stylebox_override("grabber_area_highlight", filled)
		sl.value = Profile.get_volume(r[1])
		var key: String = r[1]
		sl.value_changed.connect(func(v: float) -> void: _changed(key, v))
		row.add_child(sl)
		var pct := UiStyle.label("", 22, GameConfig.COLOR_INK)
		pct.custom_minimum_size = Vector2(70, 0)
		row.add_child(pct)
		_sliders[key] = [sl, pct]
	_update_labels()


## スマホの指: このゲームは指ごとにボタンを扱うため「指をマウスとして扱う」をオフにしている。
## そのままではスライダーが指で動かないので、指が触れた・動いた位置から値を決める
var _drag := {}  # 指の番号 -> つまんでいるスライダーの名前


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			for key in _sliders:
				var sl: HSlider = _sliders[key][0]
				if sl.get_global_rect().grow(12.0).has_point(t.position):
					_drag[t.index] = key
					_set_from_x(key, t.position.x)
					get_viewport().set_input_as_handled()
					return
		else:
			_drag.erase(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _drag.has(d.index):
			_set_from_x(_drag[d.index], d.position.x)
			get_viewport().set_input_as_handled()


func _set_from_x(key: String, x: float) -> void:
	var sl: HSlider = _sliders[key][0]
	var r := sl.get_global_rect()
	sl.value = clampf((x - r.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0)


func _changed(key: String, v: float) -> void:
	Profile.set_volume(key, v)
	Sfx.apply_volumes()
	Profile.save()
	_update_labels()
	# 効果音・全体を動かしたら、大きさがわかるように「ポッ」
	if key != "vol_bgm":
		AudioDirector.click()


## 保存されている音量にそろえる(開くたびに)
func refresh() -> void:
	for key in _sliders:
		(_sliders[key][0] as HSlider).set_value_no_signal(Profile.get_volume(key))
	_update_labels()


func _update_labels() -> void:
	for key in _sliders:
		(_sliders[key][1] as Label).text = "%d%%" % int(round((_sliders[key][0] as HSlider).value * 100.0))
