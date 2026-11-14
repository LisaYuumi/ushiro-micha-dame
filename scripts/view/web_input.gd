class_name WebInput
extends Node
## ブラウザ版の入力欄: ゲームの画面の上に、HTML の入力の窓を重ねる(名前・スタンプの言葉・カラーコード)。
## ブラウザの入力ダイアログ(prompt)は、出ている間ページの動きを全部止める(音も止まる)ので使わない。
## この窓はページを止めないので、入力している間も音は鳴り続ける。スマホのキーボードもふつうに出る。

var _cb: JavaScriptObject
var _on_done: Callable

const JS := """
(function(q, v, m, okText, cancelText){
  var old = document.getElementById('godot-input'); if (old) old.remove();
  var d = document.createElement('div'); d.id = 'godot-input';
  d.style.cssText = 'position:fixed;left:0;top:0;right:0;bottom:0;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;z-index:9999;';
  var box = document.createElement('div');
  box.style.cssText = 'background:#FBF8EF;border:4px solid #1E1B18;border-radius:20px;padding:20px;width:min(90vw,460px);box-sizing:border-box;font-family:sans-serif;box-shadow:6px 8px 0 #1E1B18;';
  var title = document.createElement('div'); title.textContent = q;
  title.style.cssText = 'font-size:20px;font-weight:bold;margin-bottom:12px;color:#1E1B18;';
  var input = document.createElement('input'); input.value = v; if (m > 0) input.maxLength = m;
  input.style.cssText = 'width:100%;box-sizing:border-box;font-size:22px;padding:10px;border:3px solid #1E1B18;border-radius:12px;';
  var row = document.createElement('div'); row.style.cssText = 'display:flex;gap:12px;margin-top:14px;';
  var mk = function(text, bg, fg){ var b = document.createElement('button'); b.textContent = text;
    b.style.cssText = 'flex:1;font-size:20px;padding:10px;border:3px solid #1E1B18;border-radius:12px;background:' + bg + ';color:' + fg + ';'; return b; };
  var cancel = mk(cancelText, '#FFFFFF', '#1E1B18'); var ok = mk(okText, '#EE6A4D', '#FFFFFF');
  row.appendChild(cancel); row.appendChild(ok);
  box.appendChild(title); box.appendChild(input); box.appendChild(row); d.appendChild(box);
  document.body.appendChild(d);
  var done = false;
  var fin = function(accept){ if (done) return; done = true; var t = input.value; d.remove();
    if (window.godotInputDone) window.godotInputDone(accept ? t : null); };
  ok.onclick = function(){ fin(true); };
  cancel.onclick = function(){ fin(false); };
  input.addEventListener('keydown', function(e){ e.stopPropagation(); if (e.key === 'Enter') fin(true); else if (e.key === 'Escape') fin(false); });
  input.addEventListener('keyup', function(e){ e.stopPropagation(); });
  setTimeout(function(){ input.focus(); input.select(); }, 50);
})(%s, %s, %d, %s, %s)
"""


func _ready() -> void:
	if OS.has_feature("web"):
		_cb = JavaScriptBridge.create_callback(_done)
		JavaScriptBridge.get_interface("window").godotInputDone = _cb


## 入力の窓を出す。OK なら on_done(入力した文字)、キャンセルなら何もしない
func ask(question: String, current: String, max_len: int, on_done: Callable) -> void:
	if not OS.has_feature("web"):
		return
	_on_done = on_done
	JavaScriptBridge.eval(JS % [JSON.stringify(question), JSON.stringify(current), max_len,
			JSON.stringify(tr("OK")), JSON.stringify(tr("キャンセル"))])


func _done(args: Array) -> void:
	if args.is_empty() or args[0] == null:
		return
	if _on_done.is_valid():
		_on_done.call(str(args[0]))
