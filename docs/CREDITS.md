# 使っている素材と、そのライセンス

## フォント
- **M PLUS Rounded 1c(Bold)**
  - 作者: Coji Morishita, M+ Fonts Project(Copyright 2016 The Rounded M+ Project Authors.)
  - 出どころ: Google Fonts(https://github.com/google/fonts/tree/main/ofl/mplusrounded1c)
  - ライセンス: SIL Open Font License 1.1。商用利用・ゲームへの同梱・配布ができる(フォントだけを売るのは不可)
  - ファイル: `assets/fonts/MPLUSRounded1c-Bold.ttf`、ライセンス全文: `assets/fonts/OFL.txt`

## キャラクターの骨組みと動き
- **Universal Animation Library(Standard / 無料版)**
  - 作者: Quaternius(https://quaternius.com)
  - 出どころ: https://quaternius.itch.io/universal-animation-library(itch.io 版の glTF を GitHub に置いたもの: https://github.com/J-Ponzo/gltf-universal-animation-library 、コミット e24c23c)
  - ライセンス: CC0 1.0(パブリックドメイン。商用利用可・クレジット不要。ここでは感謝のために記録)
  - 使い方: 人型の骨組みと動き(椅子に座る・立ち上がる・走る・歩く・立っている)だけを使う。付属の人形(皮膚のメッシュ)は表示せず、骨にA案の体(丸い頭・カプセルの胴・短い手足)をくっつけている
  - ファイル: `assets/characters/ual/`(ライセンス全文: `assets/characters/ual/LICENSE.txt`)
- **Yusei Magic**(黒板の手書き文字)
  - 作者: Tanukizamurai(Copyright 2020 The Yusei Magic Project Authors, https://github.com/tanukifont/YuseiMagic)
  - 出どころ: Google Fonts(https://github.com/google/fonts/tree/main/ofl/yuseimagic)
  - ライセンス: SIL Open Font License 1.1(商用利用・同梱できる。フォントだけを売るのは不可)
  - ファイル: `assets/fonts/YuseiMagic-Regular.ttf`、ライセンス全文: `assets/fonts/OFL-YuseiMagic.txt`
- **牛乳の絵**(牛乳をかけられたときの白い画面)
  - 作者: このプロジェクト(コードで SVG を作った自作の絵。たれる蜂蜜のイラストの雰囲気を参考にしたが、外の素材・画像は使っていない)
  - ファイル: `scripts/view/milk_art.gd`(SVG を作るコード)
- **Noto Color Emoji**(スタンプの絵文字 😨👍🥺)
  - 作者: Google(Copyright 2021 Google Inc.)
  - 出どころ: npm の @fontsource/noto-color-emoji 5.3.2(元は https://github.com/googlefonts/noto-emoji)
  - ライセンス: SIL Open Font License 1.1(商用利用・同梱できる。フォントだけを売るのは不可)
  - 使い方: スタンプで使う3つの絵文字(U+1F628・U+1F44D・U+1F97A)と、言語ボタンの 🌐(U+1F310)だけを切り出して小さくした(色は SVG のデータを使う)。切り出したものも同じライセンス
  - ファイル: `assets/fonts/NotoColorEmoji-stamps.ttf`、ライセンス全文: `assets/fonts/OFL-NotoColorEmoji.txt`
- **ゲームの音・BGM**(落とし物の音・足音・振り向き・スタンプの声・チャイム・ジングル・BGM・環境音など、`assets/sounds/` の全部)
  - 作者: このプロジェクト。録音や既存の曲・音素材は使っていない。音の並び(チャイム・曲のメロディ)もオリジナル
  - 作り方: `tools/audio/make_sounds.py`(Python と numpy で波形を合成し、ffmpeg で OGG Vorbis にした)
  - **AI で生成した素材**: このスクリプトは AI(Anthropic の Claude)が書いたもので、音と曲はそのプログラムで作った。**Steam に出すときは「AI で生成したコンテンツ」として申告する**(ストアの「AI 生成コンテンツの開示」で、事前に生成した素材として音と BGM を書く)
  - 差しかえ: 同じ名前のファイル(`.ogg` / `.wav` / `.mp3`)を `assets/sounds/` に置けば、ゲームはその音を使う。Kenney の CC0 素材などに差しかえたら、ここに出どころとライセンスを書き、AI の申告から外す

