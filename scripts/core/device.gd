class_name Device
extends RefCounted
## 遊んでいる端末のこと(ブラウザが GPU を使えているか・スマホか)。
## GPU を使わずに CPU だけで絵を描くブラウザ(SwiftShader など。会社の PC の設定などで起きる)では、
## とても重くて音もとぎれるので、自動で「軽い動き」にする(コマ数の上限・3D を粗く・音は「なめらか」)。

static var _checked := false
static var _gpu := ""


## ブラウザが絵を描くのに使っている部品の名前(Web 以外・わからないときは "")
static func gpu_name() -> String:
	if not _checked:
		_checked = true
		if OS.has_feature("web"):
			var js := "(function(){try{var c=document.createElement('canvas');var g=c.getContext('webgl2')||c.getContext('webgl');if(!g)return 'none';var e=g.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER);}catch(x){return 'error';}})()"
			_gpu = str(JavaScriptBridge.eval(js))
	return _gpu


## GPU を使わず、CPU だけで絵を描いているか
static func software_render() -> bool:
	var g := gpu_name().to_lower()
	return g.contains("swiftshader") or g.contains("software") or g.contains("llvmpipe") or g.contains("basic render")


static func is_mobile() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


## 画面の細かさ(1 = ふつう。スマホは 2〜3 で、そのぶん描く点が多い)
static func pixel_ratio() -> float:
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		if v is float or v is int:
			return float(v)
	return DisplayServer.screen_get_scale()


## 軽い動きにするか(GPU を使えていない PC のブラウザ)
static func light_mode() -> bool:
	return software_render()
