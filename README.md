# うしろ見ちゃダメ!

だまし合いのオンライン・ハンカチ落とし。企画書は [SPEC.md](SPEC.md)。

## スマホ・ブラウザで遊ぶ

https://lisayuumi.github.io/ushiro-micha-dame/ (横向き推奨。音は最初に画面をタップすると鳴る)

push するたびに GitHub Actions(`.github/workflows/web.yml`)が自動チェックを行い、
Web版を `gh-pages` ブランチに書き出す。

## 動かし方(Windows)

1. Godot 4.5.1 を入れる
   - https://godotengine.org/download/windows/ から **Godot Engine(標準版。.NET 版ではない方)** をダウンロード
   - zip を展開し、`Godot_v4.5.1-stable_win64.exe` を起動(インストール不要)
2. このリポジトリを手元に置く
   - GitHub の「Code」→「Download ZIP」で取得して展開
3. Godot のプロジェクト一覧で「インポート」→ 展開したフォルダの `project.godot` を選ぶ →「インポートして編集」
4. 右上の ▶(または F5)で実行

## 作りの方針

| フォルダ | 役割 |
|---|---|
| `scripts/core/` | ゲームの状態とルール。画面・入力・音にはさわらない(将来ホストが動かす部分) |
| `scripts/input/` | キー入力を命令に変える |
| `scripts/view/` | 状態を読んで 3D・文字・音を出す |
| `scripts/main.gd` | 上の3つをつなぐ |

調整したい数値は `scripts/core/game_config.gd` にまとめる。
