class_name Tutorial
extends CanvasLayer
## はじめて遊ぶ人向けのチュートリアル(オフライン・ボットだけ・教室・5人)。3分くらい。
## 場面ごとに試合を作り直し(main.tutorial_scene)、ボットは台本どおりに動く(BotBrain は使わない。GameState.scripted)。
## 画面の上に短い吹き出し(1〜2行)を出し、「次へ」か、言われたことをやると進む。右上の「スキップ」でいつでもやめられる。
## 流れ(docs/AI_BRIEF.md にも同じ表):
##   (7人。6人以上なら、言葉を送った人の名前が出るので、だれがウソをついたか分かる)
##   A 鬼が歩いて落とす → 自分と両どなりのうしろは見えないが、ほかの人のうしろは見える → 言葉で教えてあげる(ウソもつける)→
##     教えてもらった人が拾って追いかける → 座っている人はバナナを投げてじゃまできる(投げてみる)
##   B 振り向くのはここぞの1回 → 振り向いてみる(何もない)→ ガーン、お手つきで体育座り
##   C 鬼が自分のうしろを通ったら、まわりが言葉で教えてくれる → 手下はウソをつく → じつは落ちている。振り向いて拾う →
##     追いかける(前にバケツ。よける)→ 手下に投票 → 発表
##   D 鬼の体験: フェイク → 鬼も言葉を送れる → 黒板消しで画面を白くして見えなくする → 落とす
##   (障害物は、自分が追いかける場面 C だけ)
##   おわり: 「準備OK!オンラインで遊ぼう」→ ロビーへ

signal finished(completed: bool)

## 台本の数字
const SEAT_COUNT := 6          # 席の数(鬼を入れて7人)
const SEED := 20261119
const STAMP_DELAYS := [0.6, 1.6]  # C: 本当のこと → ウソ の言葉が届くまで
const DEMO_OBSTACLE_AHEAD := 3.5  # C: 追いかける自分の前に置くバケツ(メートル)
const ONI_TRIP_AHEAD := 2.5    # C: 鬼の前に置くバケツ(鬼が転んで追いつけるように。追いかけっこを短くする)
const CHASE_LIMIT := 6.0       # C: 追いかけっこがこれより長くなったら、追いついたことにする(秒)
const MINION_ID := 4           # C: 手下(席4。正面の少し右)
const HONEST_ID := 2           # C: 本当のことを言う人(席2。正面の少し左)
const PICK_BOT := 3            # A: 落とされる人(席3。正面)

var _main: Node
var _step := ""
var _t := 0.0
var _flag := false
var _my_vote_was_right := false
var _taught_right := false
var _demo_obstacle := {}
var _chase_ready := false

var _bubble: PanelContainer
var _text: Label
var _next: Button
var _skip: Button
var _arrow: Control
var _arrow_target := Callable()
var _end_card: PanelContainer
var _end_button: Button


func setup(main: Node) -> void:
	_main = main
	layer = 4
	_build_ui()
	_go("intro")


func _state() -> GameState:
	return _main.state


func _me() -> int:
	return _state().local_player_id


# --- 見た目 ---

func _build_ui() -> void:
	_arrow = Control.new()
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)

	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 22, 4)
	st.border_color = GameConfig.COLOR_ACCENT
	st.content_margin_left = 22
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	_bubble.add_theme_stylebox_override("panel", st)
	add_child(_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bubble.add_child(row)
	_text = UiStyle.label("", 26, GameConfig.COLOR_INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(760, 0)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_text)
	_next = Button.new()
	_next.text = tr("次へ ▶")
	_next.custom_minimum_size = Vector2(130, 56)
	_next.focus_mode = Control.FOCUS_NONE
	UiStyle.button(_next, true, 24)
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next.pressed.connect(_on_next)
	row.add_child(_next)

	# スキップ(右上の⚙の左)
	_skip = Button.new()
	_skip.text = tr("スキップ")
	_skip.focus_mode = Control.FOCUS_NONE
	UiStyle.button(_skip, false, 20)
	_skip.custom_minimum_size = Vector2(120, 48)
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -UiStyle.SAFE - 96 - 130
	_skip.offset_right = -UiStyle.SAFE - 96
	_skip.offset_top = 14
	_skip.offset_bottom = 62
	_skip.pressed.connect(func() -> void:
		AudioDirector.click()
		_end(false))
	add_child(_skip)


## 吹き出しを出す。wait_next = true なら「次へ」を押すまで待つ
func _say(text: String, wait_next: bool, arrow: Callable = Callable()) -> void:
	_bubble.visible = true
	_text.text = text
	_next.visible = wait_next
	_arrow_target = arrow
	_bubble.reset_size()
	_bubble.size = _bubble.get_combined_minimum_size()
	var vp := _bubble.get_viewport_rect().size
	# 投票の間は、上の投票パネルと重ならないように画面の下に
	# (追いかけっこは、ゲームの「追いかけろ!」の文字と重ならないように下に)
	var low := _step in ["chase", "vote", "vote_now", "revealed"]
	_bubble.position = Vector2((vp.x - _bubble.size.x) / 2.0, vp.y - _bubble.size.y - 110.0 if low else 74.0)
	_bubble.pivot_offset = _bubble.size / 2.0
	_bubble.scale = Vector2(0.85, 0.85)
	var tw := _bubble.create_tween()
	tw.tween_property(_bubble, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioDirector.sfx("vote_pon", -10.0)


func _draw_arrow() -> void:
	if not _arrow_target.is_valid():
		return
	var p3: Variant = _arrow_target.call()
	if p3 == null:
		return
	var cam := _arrow.get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(p3):
		return
	var p := cam.unproject_position(p3)
	var bob := sin(Time.get_ticks_msec() / 130.0) * 8.0
	var tip := p + Vector2(0, -12.0 + bob)
	var pts := PackedVector2Array([tip, tip + Vector2(-24, -34), tip + Vector2(-10, -34), tip + Vector2(-10, -64),
			tip + Vector2(10, -64), tip + Vector2(10, -34), tip + Vector2(24, -34)])
	var outline := pts.duplicate()
	outline.append(tip)
	_arrow.draw_colored_polygon(pts, GameConfig.COLOR_ACCENT)
	_arrow.draw_polyline(outline, GameConfig.COLOR_INK, 4.0, true)


func _point_actor(id: int, h: float = 1.9) -> Callable:
	return func() -> Variant: return _main.view.actor_point(id, h)


func _point_item() -> Callable:
	return func() -> Variant:
		var s := _state()
		return s.handkerchief_position + Vector3(0, 0.3, 0) if s.handkerchief_on_floor else null


## PC とスマホで操作の言い方を変える
func _ctrl(pc: String, touch: String) -> String:
	return touch if Device.is_mobile() else pc


# --- 流れ ---

func _go(step: String) -> void:
	_step = step
	_t = 0.0
	_flag = false
	var s := _state()
	match step:
		"intro":
			_scene(false)
			# 鬼は正面の人の少し手前から歩いて、正面の人のうしろに落とす
			s.script_round(s.seat_angle(PICK_BOT) - 0.7, PICK_BOT, -1)
			s.oni_pause_left = 999.0
			_say(tr("ようこそ!遊びながら覚えよう(3分くらい)"), true)
		"oni_walk":
			s.oni_pause_left = 0.0
			_say(tr("鬼がみんなのうしろを歩いて、\nだれかのうしろに落とし物を落とすよ"), false, _point_actor(s.oni_id))
		"see_back":
			_say(tr("自分と両どなりのうしろは見えないけど、\nほかの人のうしろは見える。ほら、落ちてる!"), true, _point_item())
		"teach":
			# (名前は吹き出しに隠れて見えないことがあるので「落ちている人」。押す言葉は、自分の画面に出ている言葉そのもの)
			_say(_ctrl(tr("教えてあげよう!落ちている人をクリックして、\n「%s」を送ろう(ウソをつくこともできるよ)"),
					tr("教えてあげよう!落ちている人をタップして、\n「%s」を送ろう(ウソをつくこともできるよ)")) % _teach_word(), false, _point_actor(PICK_BOT))
		"bot_pick":
			_say(tr("教えてもらって気づいた!\n拾って鬼を追いかけるよ"), false, _point_actor(PICK_BOT))
		"banana":
			_say(_ctrl(tr("座っている人は、バナナを投げてじゃまできる!\nBキーで鬼にバナナを投げてみよう"),
					tr("座っている人は、バナナを投げてじゃまできる!\n「鬼にバナナ」を押してみよう")), false, _point_actor(s.oni_id))
		"banana_done":
			_say(tr("ナイス!踏むと転ぶよ。\n追いかける人に投げることもできる"), true)
		"teach_done":
			if _taught_right:
				_say(tr("本当のことを教えたね!\nウソを送って、だますこともできるよ"), true)
			else:
				_say(tr("ウソでだまそうとしたね!\n本当のことを教えるのも、だますのも作戦"), true)
		"look_rule":
			_scene(false)
			s.script_round(0.35, -1, -1)
			_say(tr("振り向くのは、ここぞという1回だけ。\n何もないのに振り向くと「お手つき」!"), true)
		"try_look":
			_say(_ctrl(tr("スペースキーで振り向いてみよう(いまは何もないよ)"),
					tr("「振り向く」ボタンで振り向いてみよう(いまは何もないよ)")), false)
		"out":
			# (ゲームの「ガーン!」と説明が終わってから出す。update)
			_bubble.visible = false
		"words":
			_scene(false)
			# 鬼は自分(席0)のうしろに落とす。席3が手下
			s.script_round(-0.6, 0, MINION_ID)
			# 「拾おう」と言うまでは振り向けない(先に拾うと、鬼がすぐそばにいてすぐタッチになるので)
			s.get_local_player().looks_left = 0
			s.oni_pause_left = 999.0
			_say(tr("鬼が自分のうしろを通ったら、\nまわりが言葉で教えてくれるよ"), true)
		"wait_words":
			s.oni_pause_left = 0.0
			_say(tr("鬼がうしろを通るよ…"), false, _point_actor(s.oni_id))
		"minion":
			_say(tr("でも、ウソをつく「鬼の手下」がまぎれている!\nだれが何と言ったか、覚えておこう"), true)
		"pick":
			var me_a := s.get_local_player()
			if me_a:
				me_a.looks_left = maxi(me_a.looks_left, 1)
			_say(_ctrl(tr("じつは本当に落ちてるよ!\nスペースキーで振り向いて拾おう"),
					tr("じつは本当に落ちてるよ!\n「振り向く」ボタンで拾おう")), false)
		"chase":
			_say(_ctrl(tr("鬼を追いかけてタッチ!\nA・Dキーで障害物をよける"),
					tr("鬼を追いかけてタッチ!\nスティックを左右に倒して障害物をよける")), false, _point_actor(s.oni_id))
		"vote":
			_say(tr("さいごに、ウソをついた手下はだれか、みんなで投票しよう"), false)
		"vote_now":
			_say(_ctrl(tr("「落ちてないよ」とウソをついた人をクリックして投票!"), tr("「落ちてないよ」とウソをついた人をタップして投票!")), false)
		"revealed":
			var who: String = _main._name(MINION_ID)
			if _my_vote_was_right:
				_say(tr("当たり!手下は %s だった。\n当てると点がもらえるよ") % who, true)
			else:
				_say(tr("手下は %s だった。\n当てると点がもらえるよ") % who, true)
		"oni_intro":
			_scene(true)
			s.script_round(s.seat_angle(0) + 0.4, -1, -1)
			s.oni_pause_left = 999.0
			_say(tr("こんどは鬼をやってみよう!\n鬼は自動で歩くよ"), true)
		"fake":
			s.oni_pause_left = 0.0
			_say(_ctrl(tr("Fキーで「フェイク」。\n落とす音だけ出して、だまそう"),
					tr("「フェイク」ボタンで、\n落とす音だけ出して、だまそう")), false)
		"oni_stamp":
			_say(_ctrl(tr("鬼も言葉を送れるよ。座っている人をクリックして送ろう\n(ウソでだますのもアリ)"),
					tr("鬼も言葉を送れるよ。座っている人をタップして送ろう\n(ウソでだますのもアリ)")), false)
		"eraser":
			_say(_ctrl(tr("黒板消しで画面を白くして、うしろを見えなくできる!\nMキーを押して、座っている人をクリック"),
					tr("黒板消しで画面を白くして、うしろを見えなくできる!\n「黒板消し」を押して、座っている人をタップ")), false)
		"drop":
			_say(_ctrl(tr("Eキーで、本当に落とそう"), tr("「落とす」ボタンで、本当に落とそう")), false)
		"oni_done":
			_say(tr("ナイス!気づかれずに1周すれば鬼の勝ち。\n気づかれたら追いかけっこ!"), true)
		"end":
			_show_end()


func _on_next() -> void:
	if not (_bubble.visible and _next.visible):
		return
	AudioDirector.click()
	match _step:
		"intro":
			_go("oni_walk")
		"see_back":
			_go("teach")
		"teach_done", "banana_done":
			_go("look_rule")
		"look_rule":
			_go("try_look")
		"out":
			_go("words")
		"words":
			_go("wait_words")
		"minion":
			_go("pick")
		"revealed":
			_go("oni_intro")
		"oni_intro":
			_go("fake")
		"oni_done":
			_go("end")


## 毎フレーム(main の _physics_process から。ボットの代わり)
func update(delta: float) -> void:
	_t += delta
	_arrow.queue_redraw()
	var s := _state()
	var me := s.get_local_player()
	if _step in ["wait_words", "minion", "pick"] and me and me.role == GameState.Role.OUT:
		# 落とされる前に振り向いてお手つきになった: この場面をやり直す
		_go("words")
		return
	# 落としたあと、鬼は1席ぶん先まで歩いてから止まって待つ(すぐ止めると、拾った瞬間にタッチになるので)
	if s.scripted and s.phase == GameState.Phase.DROPPED and not s.oni_is_player \
			and s.oni_angle >= s.drop_angle + TAU / s.seat_count * 0.9:
		s.oni_pause_left = 999.0
	# 追いかけっこが始まった瞬間: ランダムの障害物は消して、追いかける人の前(鬼より手前)にバケツを1つだけ置く
	# (ランダムの障害物で鬼がすぐ転ぶと、拾った瞬間にタッチになってしまうので)。state.tick の前に呼ばれる
	_setup_chase()
	# 投票は、投票の場面(C)だけ。ほかの場面で勝敗が出ても(ボットの追いかけっこなど)、投票は始めない
	# (吹き出しと投票の文字が重なってしまうので)
	if s.phase == GameState.Phase.RESULT and not (_step in ["chase", "vote", "vote_now", "revealed"]):
		s.vote_wait = maxf(s.vote_wait, 999.0)
		s.voting_open = false
	match _step:
		"bot_pick":
			# 教えてもらったボットが拾う(鬼が1席先まで歩いて止まってから。すぐ拾うと、拾った瞬間にタッチになるので)
			if not _flag and _t >= 1.0 and s.oni_pause_left > 100.0 and s.phase == GameState.Phase.DROPPED:
				_flag = true
				s.pick_up(PICK_BOT)
				_setup_chase()
			if s.phase == GameState.Phase.CHASE and _t >= 1.0:
				_go("banana")
		"banana":
			if s.phase == GameState.Phase.RESULT:
				_go("look_rule")
		"out":
			if not _flag and _t >= 3.4:
				_flag = true
				_say(tr("お手つき!真ん中で体育座り。\nこのラウンドはお休み(0点)"), true)
		"wait_words":
			if s.phase == GameState.Phase.DROPPED:
				# 落とされた: 言葉が届く(本当のこと → ウソ)。鬼は1席ぶん先まで歩いてから止まって待つ
				# (すぐ止めると、拾った瞬間にタッチになってしまうので)
				if not _flag:
					_flag = true
					_t = 0.0
				if _t >= STAMP_DELAYS[0] and not (_me() in s.get_actor(HONEST_ID).stamped_targets):
					s.send_stamp(HONEST_ID, _me(), Stamps.DROPPED)
				if _t >= STAMP_DELAYS[1] and not (_me() in s.get_actor(MINION_ID).stamped_targets):
					s.send_stamp(MINION_ID, _me(), Stamps.SAFE)
				if _t >= STAMP_DELAYS[1] + 0.8 and s.oni_pause_left > 100.0:
					_go("minion")
		"minion", "pick":
			# (読んでいる間に言葉が消えないように、鬼は1席先で止めたまま。拾えば走り出す。
			#  言葉は時間ではなく、鬼が歩いた分で消える)
			pass
		"chase":
			# 長くなりすぎたら、追いついたことにする(チュートリアルは短く)
			if s.phase == GameState.Phase.CHASE and _t >= CHASE_LIMIT:
				s._finish(_me(), s.oni_id, "touched")
		"vote":
			if s.voting_open:
				# ボットは手下に投票(手下は投票しない)
				for a in s.actors:
					var id: int = a.id
					if id != _me() and s.can_vote(id) and not s.votes.has(id):
						s.cast_vote(id, MINION_ID)
				_go("vote_now")
		"vote_now":
			if not s.voting_open and s.reveal_left >= 0.0:
				_my_vote_was_right = int(s.votes.get(_me(), -1)) == MINION_ID
				_flag = true
			if _flag and s.can_go_next():
				_go("revealed")


func _setup_chase() -> void:
	var s := _state()
	if s.phase == GameState.Phase.CHASE and not _chase_ready:
		_chase_ready = true
		if s.chaser_id != _me():
			# ボットが追いかけるとき(バナナの説明)は、障害物なし
			s.obstacles = []
			return
		# バケツは、追いかける人と鬼のあいだ(鬼の足もとに置くと、鬼が転んでしまうので)
		var chaser := s.get_actor(s.chaser_id)
		var gap := fposmod(s.runner_angle(s.get_actor(s.oni_id)) - s.runner_angle(chaser), TAU)
		var ahead := minf(DEMO_OBSTACLE_AHEAD, gap * 0.5 * float(GameConfig.LANE_RADII[chaser.lane]))
		_demo_obstacle = s.script_obstacle(s.chaser_id, ahead, "bucket", true)
		# 鬼の前にもバケツ(鬼が転ぶので、追いつきやすい。追いかけっこを短くする)
		s.script_obstacle(s.oni_id, ONI_TRIP_AHEAD, "bucket", false)


## ゲームのお知らせ(main から)
func on_event(e: Dictionary) -> void:
	var t: String = e.get("type", "")
	match _step:
		"oni_walk":
			if t == "dropped":
				_go("see_back")
		"teach":
			if t == "stamp" and e.get("sender", -1) == _me() and e.get("target", -1) == PICK_BOT:
				_taught_right = Stamps.says_look(str(e.get("kind", "")))
				_go("bot_pick")
		"bot_pick", "banana":
			if t == "banana" and e.get("sender", -1) == _me():
				_go("banana_done")
		"try_look":
			if t == "otetsuki" and e.get("actor", -1) == _me():
				_go("out")
		"words", "wait_words", "minion", "pick":
			# (言われる前に振り向いて拾えたら、そのまま追いかけっこへ)
			if t == "picked_up" and e.get("actor", -1) == _me():
				_go("chase")
		"chase":
			if t == "result":
				_go("vote")
		"fake":
			if t == "rustle":
				_go("oni_stamp")
			elif t == "dropped":
				_state().oni_pause_left = 999.0
				_go("oni_done")
		"oni_stamp":
			if t == "stamp" and e.get("sender", -1) == _me():
				_go("eraser")
			elif t == "dropped":
				_state().oni_pause_left = 999.0
				_go("oni_done")
		"eraser":
			if t == "milk" and e.get("sender", -1) == _me():
				_go("drop")
			elif t == "dropped":
				_state().oni_pause_left = 999.0
				_go("oni_done")
		"drop":
			if t == "dropped":
				_state().oni_pause_left = 999.0
				_go("oni_done")


## 場面を作り直す(試合を新しく)
func _scene(player_oni: bool) -> void:
	_main.tutorial_scene(player_oni)
	_chase_ready = false


func _show_end() -> void:
	_bubble.visible = false
	_skip.visible = false
	_arrow_target = Callable()
	_end_card = PanelContainer.new()
	var st := UiStyle.box(GameConfig.COLOR_PAPER, true, 28, 5)
	st.shadow_offset = Vector2(6, 8)
	st.set_content_margin_all(36)
	_end_card.add_theme_stylebox_override("panel", st)
	add_child(_end_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_end_card.add_child(col)
	var t := UiStyle.label(tr("準備OK!"), 56, GameConfig.COLOR_ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", GameConfig.COLOR_INK)
	t.add_theme_constant_override("outline_size", 10)
	col.add_child(t)
	var sub := UiStyle.label(tr("オンラインで遊ぼう"), 30, GameConfig.COLOR_INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var b := Button.new()
	b.text = tr("ロビーへ ▶")
	b.custom_minimum_size = Vector2(360, 70)
	b.focus_mode = Control.FOCUS_NONE
	UiStyle.button(b, true, 28)
	b.pressed.connect(func() -> void:
		AudioDirector.click()
		_end(true))
	col.add_child(b)
	_end_button = b
	UiStyle.center(_end_card)
	AudioDirector.sfx("jajaan", -4.0)
	_main.hud.confetti()


func _end(completed: bool) -> void:
	finished.emit(completed)


## スマホの指: 「次へ」「スキップ」「ロビーへ」を押す
func _input(event: InputEvent) -> void:
	UiStyle.tap_buttons(event, [_end_button, _next, _skip])


## 教える場面で押す言葉(自分の画面の「落ちてる」の言葉)
func _teach_word() -> String:
	return HeadOverlay.stamp_text(_state(), _me(), Stamps.DROPPED)


## チュートリアル中に、この人へ言葉を送る相手として選べるか(教える場面の、落ちている人だけ)
func allows_stamp_target(id: int) -> bool:
	return (_step == "teach" and id == PICK_BOT) or _step == "oni_stamp"


## この言葉を送れるか(教える場面の「落ちてる」だけ)。送れないときは、押す言葉を案内する
func allows_stamp_kind(kind: String) -> bool:
	if (_step == "teach" and kind == Stamps.DROPPED) or _step == "oni_stamp":
		return true
	if _step == "teach":
		_main.hud.show_message(tr("「%s」を押してね") % _teach_word(), Color(0.3, 0.3, 0.3), 1.2)
	return false


## 黒板消しを使えるか(鬼の場面の、黒板消しの説明のときだけ)
func allows_milk() -> bool:
	return _step == "eraser"


## 今の段階(テスト用)
func step() -> String:
	return _step
