#!/usr/bin/env python3
"""翻訳ファイルを作る。

- assets/i18n/texts.csv(Godot の翻訳ファイル。列: keys, ja, en)
- docs/TRANSLATIONS.md(翻訳が必要な文字の一覧)

キーは日本語の元の文(スクリプトの中の文字そのまま)。英語は下の EN に書く。
言語を足すときは、LANGS に言語のコードを足し、その言語の辞書(EN と同じ形)を書いて、もう一度このスクリプトを動かす。
`--check` をつけると、スクリプトの中の日本語の文で、まだ翻訳がないものを書き出す。

使い方: python3 tools/i18n/make_translations.py [--check]
"""
import csv
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV_PATH = os.path.join(ROOT, "assets", "i18n", "texts.csv")
DOC_PATH = os.path.join(ROOT, "docs", "TRANSLATIONS.md")
LANGS = ["ja", "en"]

HOW_TO_PLAY_JA = """・振り向く(長押し): 押している間だけ後ろを見る。落ちていたら、そのまま拾って走る
・お手つき(なにもないのに振り向く): 輪から抜けて真ん中で休む。そのラウンドは0点。全員の後ろが見えて、だれにでもスタンプを送れる
・人をタップ: 画面の下に3つの言葉のボタンが出るので、選んで送る(同じ人には1ラウンド1回)
・鬼: 自動で前に歩く。スティックを歩く向きに倒すと速く、反対に倒すと止まり、倒し続けると少し戻れる(3歩分まで)。落とす・フェイク(落とす音だけ)・牛乳(牛乳ボタン→「えいっ」になったら、座っている人をタップしてかける。もう一度押すとやめる。画面が半周のあいだ白くなる。1ラウンド1回)
・追いかけっこ: 鬼が輪の外側を2周して空いた席に座れば鬼の勝ち、それまでにタッチすれば追いかけた人の勝ち。走るのは自動(2人とも同じ速さ)。スティックを左右に倒すと、内側・外側へ動く。バケツ・椅子・机・バナナは、左右に動いてよける(ジャンプはない)。ぶつかると転ぶ。座っている人はバナナを投げられる
キーボード: スペース=振り向く 1〜3=スタンプ M=牛乳 Z X C=鬼のスタンプ 走るとき: A/D=左右によける 鬼が歩くとき: A/D=速く/止まる・戻る
 E=落とす F=フェイク B/N=バナナ R=やり直し O=役を変える F1=上から見る K=転ぶ L=牛乳をかぶる G=次のラウンドを停電に(確認用) Tab=メニュー"""

HOW_TO_PLAY_EN = """- Look back (hold): look behind you while held. If something was dropped there, you pick it up and run
- Wrong look (nothing behind you): you leave the ring and rest in the middle. 0 points this round. You can see behind everyone and send stamps to anyone
- Tap a person: three word buttons appear at the bottom. Pick one to send (once per person per round)
- Oni: walks forward on its own. Push the stick the way you walk to go faster, the other way to stop, and keep holding to step back (up to 3 steps). Drop / Fake (only the drop sound) / Milk (press Milk, then when it says "Splash!" tap a seated person. Press again to cancel. Their screen goes white for half a lap. Once per round)
- Chase: the oni wins by running 2 laps outside the ring and sitting in the empty seat; the chaser wins by touching the oni first. Running is automatic (both run at the same speed). Push the stick left/right to move inward/outward. Dodge buckets, chairs, desks and bananas by moving sideways (no jumping). Bumping into one makes you fall. Seated players can throw bananas
Keyboard: Space=look back 1-3=stamps M=milk Z X C=oni stamps  While running: A/D=dodge left/right  Oni walking: A/D=faster/stop & step back
 E=drop F=fake B/N=banana R=restart O=switch role F1=top view K=fall L=get milk G=blackout next round (test) Tab=menu"""

# 日本語の元の文 -> 英語。言葉が長くなりすぎないように(ボタンや吹き出しに収まるように)短めにする
EN = {
    # 落とし物・性格・名前
    "ハンカチ": "Handkerchief",
    "上履き": "Indoor shoe",
    "ランドセル": "School bag",
    "机": "Desk",
    "教卓": "Teacher's desk",
    "日本語": "日本語",
    "ボット": "Bot",
    "ボット%d": "Bot %d",
    "(%s)": " (%s)",
    "プレイヤー": "Player",
    "プレイヤー%d": "Player %d",
    "(ボット)": " (bot)",
    "せっかち": "hasty",
    "慎重": "careful",
    "うたがい屋": "doubter",
    "おしゃべり": "chatty",
    "あなた": "You",
    "あなた!": "You!",
    "鬼": "Oni",
    "追う人": "chaser",
    # スタンプ
    "落ちてる": "Behind you!",
    "平気": "You're safe",
    "信じて": "Trust me",
    "送る相手": "Send to",
    "%sに送る": "Send to %s",
    "スタンプの言葉を変える  😨 👍 🥺": "Change stamp words  😨 👍 🥺",
    "スタンプの言葉(%d文字まで。絵文字は変わりません)": "Stamp words (up to %d characters. Emoji stay the same)",
    "初期の言葉に戻す": "Reset to default",
    "%s の言葉(%d文字まで)": "Words for %s (up to %d characters)",
    "初期の言葉に戻しました": "Reset to the default words",
    "%s(タップで変える)": "%s (tap to change)",
    "ほかの人の自作の言葉: %s": "Others' custom words: %s",
    "表示しない(初期の言葉で表示)": "Hide (show defaults)",
    "表示する": "Show",
    # ボタン
    "落とす": "Drop",
    "牛乳": "Milk",
    "フェイク": "Fake",
    "鬼にバナナ": "Banana the oni",
    "追う人にバナナ": "Banana the chaser",
    "振り向く": "Look back",
    "からっぽ": "Empty",
    "えいっ": "Splash!",
    "メニュー": "Menu",
    "やり直し": "Restart",
    "役を変えて新しい試合": "New match, other role",
    "上から見る(確認用)": "Top view (test)",
    "あそびかた": "How to play",
    "撮影モード(開発用)": "Photo mode (dev)",
    "とじる": "Close",
    "ボットの性格を表示: %s": "Show bot personality: %s",
    "オン": "On",
    "オフ": "Off",
    "HOW_TO_PLAY": HOW_TO_PLAY_EN,
    # 通信
    "つながりました! ホストがスタートするのを待っています": "Connected! Waiting for the host to start",
    "(作成中)": "(creating)",
    "部屋 %s をさがしています…": "Looking for room %s…",
    "%s が抜けたのでボットが代わります": "%s left. A bot takes over",
    "スタート!": "Start!",
    "つながりました! いまは試合中です。\n次の試合から参加できます(ホストが新しい試合を始めるまで待ってください)":
        "Connected! A match is in progress.\nYou can join from the next match (wait for the host to start a new one)",
    "つながりました! いま %d人。ホストがスタートするのを待っています": "Connected! %d players now. Waiting for the host to start",
    "ホストとの通信が切れました\nページを読み込み直してください": "Lost connection to the host\nPlease reload the page",
    "部屋を作っています…": "Creating a room…",
    "ホストとつながりました": "Connected to the host",
    "ホストとの通信が切れました": "Lost connection to the host",
    "仲介サーバーにつなげません(%d)": "Can't reach the relay server (%d)",
    "直接つながりませんでした。\n全員が同じ Wi-Fi につないで(携帯回線は切って)、ページを読み込み直してもう一度試してください":
        "Couldn't connect directly.\nPut everyone on the same Wi-Fi (turn off mobile data), reload the page and try again",
    "仲介サーバーから切れました。ページを読み込み直してください": "Disconnected from the relay server. Please reload the page",
    "部屋ができました。合言葉: %s": "Room created. Code: %s",
    "仲介サーバーにつながりました。部屋 %s に申し込んでいます…": "Connected to the relay server. Joining room %s…",
    "仲介サーバーに送れませんでした(%d/%d)。少し待ってもう一度試してください": "Couldn't send to the relay server (%d/%d). Wait a moment and try again",
    "だれかが入ろうとしています…": "Someone is joining…",
    "ホストから返事が来ました。直接つないでいます…": "The host answered. Connecting directly…",
    # 試合中の札・お知らせ
    "お手つきでお休み中(このラウンド0点)": "Out after a wrong look (0 pts this round)",
    "あなたは鬼の手下": "You are the oni's helper",
    "あなたは鬼の手下!": "You're the oni's helper!",
    "だまして +1点": "Fool someone +1",
    "鬼が勝てば +2点": "Oni wins +2",
    "ほかの人にはないしょだよ": "Keep it secret!",
    "次へ進むのはホストです": "The host moves on",
    "オンラインでは、鬼は負けた人がやります": "Online, the loser becomes the oni",
    "あなたが鬼で新しい試合": "New match: you are the oni",
    "座る側で新しい試合": "New match: you sit",
    "撮影モードは、ひとりで遊ぶときだけ": "Photo mode is only for solo play",
    "かける人をタップ!": "Tap someone to splash!",
    "かける人をタップしてね": "Tap someone to splash",
    "教えた! +%d点\n(%s を助けた)": "Helped! +%d\n(you helped %s)",
    "だました! +%d点\n(%s が引っかかった)": "Fooled! +%d\n(%s fell for it)",
    "となりの人には送れない": "You can't send to a neighbor",
    "この人には、このラウンドもう送った": "Already sent to them this round",
    "この人はスタンプがいっぱい(%d つ)\n鬼が進むと空く。また送れるよ": "Their stamps are full (%d)\nA slot opens as the oni moves on",
    "いまは送れない": "Can't send now",
    "本物": "real",
    "ニセ": "fake",
    "%s が %s にバナナ!": "%s threw a banana at %s!",
    "つるっ! %s が転んだ": "Whoops! %s fell",
    "もう振り向けない!\n(1ラウンド%d回まで)": "No more looks!\n(%d per round)",
    "空いた席には落とせない": "Can't drop behind an empty seat",
    "席の後ろで押してね": "Press it behind a seat",
    "牛乳かけられた!": "You got milk!",
    "%s に牛乳!": "Milk on %s!",
    "お手つき!\n真ん中でお休み(このラウンド0点)": "Wrong look!\nRest in the middle (0 pts this round)",
    "4周したので\n次の席で自動で落とす": "4 laps done\nDropping at the next seat",
    "あった!": "Found it!",
    "追いかけろ!\nスティックを左右に倒してよける": "Chase!\nPush the stick left/right to dodge",
    "気づかれた! 逃げろ!\nスティックを左右に倒してよける": "Spotted! Run!\nPush the stick left/right to dodge",
    "%s が追いかけた!": "%s gives chase!",
    "鬼 %d周目(%d周で自動で落とす)": "Oni lap %d (auto-drop at %d)",
    "鬼が座るまで あと%d周": "Oni sits in %d lap(s)",
    "あなたは鬼": "You are the oni",
    "ラウンド %d/%d": "Round %d/%d",
    "いまの落とし物:%s": "Item: %s",
    "あなた %d点": "You %d pts",
    "ラウンド 1/5": "Round 1/5",
    "いまの落とし物:ハンカチ": "Item: Handkerchief",
    "見えるまで": "Clears in",
    # 結果
    "タッチ成功!": "Touched!",
    "鬼をつかまえた! やったね": "You caught the oni!",
    "つかまっちゃった…": "Caught…",
    "%s にタッチされた": "%s touched you",
    "タッチ!": "Touch!",
    "%s が鬼をつかまえた!": "%s caught the oni!",
    "セーフ!": "Safe!",
    "空いた席にすわれた〜!": "You made it to the seat!",
    "すわられちゃった…": "They took your seat…",
    "あとちょっとだったのに!": "So close!",
    "鬼のかち!": "Oni wins!",
    "%s の席にすわった!": "Sat in %s's seat!",
    "気づかなかった〜!": "You didn't notice!",
    "うしろに落ちてたよ…": "It was right behind you…",
    "気づかれなかった!": "Nobody noticed!",
    "%s はぜんぜん気づかなかった": "%s never noticed",
    "%s が気づかなかった!": "%s didn't notice!",
    "全員お手つき!": "Everyone looked wrong!",
    "だれも残らなかった〜!": "Nobody was left!",
    "全員お手つき…": "Everyone looked wrong…",
    "鬼のかち! みんな振り向きすぎ!": "Oni wins! Too much looking back!",
    "さいごの結果へ": "Final results",
    "次のラウンド(%s)へ": "Next round (%s)",
    "ホストが「次へ」を押すと": "When the host presses Next: ",
    "次へ ▶ ": "Next ▶ ",
    "ラウンド %d: %s": "Round %d: %s",
    "%d位": "#%d",
    "ゆうしょう!": "Champion!",
    "試合おわり!": "Match over!",
    "あなたがいちばん!": "You're number one!",
    "いちばんは %s!": "%s is number one!",
    "ホストが「次へ」を押すと新しい試合": "A new match starts when the host presses Next",
    "新しい試合へ ▶": "New match ▶",
    "手下はだれ?": "Who's the helper?",
    "タップでめくってね": "Tap to flip",
    "鬼の手下は…": "The oni's helper was…",
    "だったよ!": " ",
    "鬼がかって +%d点": "Oni won +%d",
    "今回の手下は%d人(だれかはひみつ)": "Minions this round: %d (who is secret)",
    "今回は手下が2人!\n(だれかはひみつ)": "Two minions this round!\n(who is secret)",
    "手下を当てた! +%d点": "You found the minion! +%d",
    "2人だったよ!": "were the minions!",
    "手下だと思う人の札をタップ!\n当たれば +%d点": "Tap who you think is the minion!\nCorrect: +%d",
    "投票した!\nみんなを待っています": "Voted!\nWaiting for everyone",
    "みんなが手下を\n当てています…": "Everyone is guessing\nthe minion…",
    "投票": "Vote",
    "当たり +%d": "Correct +%d",
    "教室": "Classroom",
    "海辺": "Beach",
    "夜の教室": "Night Classroom",
    "懐中電灯": "Flashlight",
    "メトロノーム": "Metronome",
    "モナリザ": "Mona Lisa",
    "ガイコツ": "Skeleton",
    "フィルム切れ": "Out of film",
    "フラッシュでまぶしい!": "Blinded by the flash!",
    "%s をパシャッ!": "Snap! Flashed %s!",
    "パシャッ!": "Snap!",
    "カミナリ!": "Thunder!",
    "貝殻": "Seashell",
    "ビーチボール": "Beach ball",
    "浮き輪": "Swim ring",
    "砂の城": "Sandcastle",
    "バナナボート": "Banana boat",
    "水鉄砲": "Squirt",
    "水鉄砲でかけられた!": "You got squirted!",
    "%s に水鉄砲!": "Squirted %s!",
    "舞台: %s ▶": "Stage: %s ▶",
    "人数: %d人": "Players: %d",
    "きせかえ ▶": "Dress up ▶",
    "帽子": "Hat",
    "メガネ": "Glasses",
    "リボン": "Ribbon",
    "豚の鼻": "Pig nose",
    "キャップ": "Cap",
    "ニット帽": "Beanie",
    "シルクハット": "Top hat",
    "丸メガネ": "Round",
    "四角メガネ": "Square",
    "つける": "Wear",
    "なし": "None",
    "キャンセル": "Cancel",
    "黒板消し": "Eraser",
    "黒板消しでポンポンされた!": "Chalk dust in your face!",
    "%s を黒板消しでポンポン!": "Chalk dust on %s!",
    "ポンポン!": "Pat pat!",
    "あったー!!": "Found it!!",
    "うしろ!うしろ!": "Right behind!",
    "来てるよ!": "Look out!",
    "あるある!": "It's there!",
    "スタンプ:セーフ!": "All clear",
    "まだまだ": "Not yet",
    "なんもないよ": "Nothing there",
    "マジだって!": "For real!",
    "ぜったいホント": "I swear!",
    "うそじゃない": "No lie!",
    "シャッフル": "Shuffle",
    "スタンプの言葉を自分で作る ▶": "Make my own words ▶",
    "表示しない(シャッフルの言葉で表示)": "Hide (show shuffled words)",
    "ガーン!": "Oh no!",
    "画面のゆれ: %s": "Screen shake: %s",
    "だれか": "Someone",
    "ウソ": "Lie",
    "ウソ: %s": "Lied: %s",
    "トントン": "Tap tap",
    "鬼の手下は誰?": "Who is the Oni's helper?",
    "ボットの名前(宣伝用) ▶": "Bot names (promo) ▶",
    "UIを全部消す(撮影用・長押しで戻る)": "Hide all UI (for capture; long-press to show)",
    "輪の全体": "Whole circle",
    "教室の全体": "Whole room",
    "キャラの寄り": "Close-up",
    "鬼の後ろ": "Behind the Oni",
    "自由": "Free",
    "歩く": "Walk",
    "ひざ崩れ": "Collapse",
    "驚く": "Surprised",
    "ガーン": "Shocked",
    "勝ち": "Win",
    "負け": "Lose",
    "ニヤニヤ": "Smirk",
    "気まずい": "Awkward",
    "お手つき": "Oops",
    "必死": "Panic",
    "手に持つ": "In hand",
    "背中の後ろ": "Behind back",
    "保存しています…": "Saving…",
    "ダウンロードしました: ": "Downloaded: ",
    "保存しました: ": "Saved: ",
    "保存できませんでした(%d)": "Could not save (%d)",
    "場面": "Scene",
    "キャラ": "Character",
    "全員に": "Apply to all",
    "落とし物": "Item",
    "種類 ▶": "Kind ▶",
    "背景": "Background",
    "キャラだけ": "Characters only",
    "動き": "Motion",
    "うごく": "Move",
    "止める": "Freeze",
    "UIを消す(H)": "Hide UI (H)",
    "4Kで保存": "Save 4K",
    "(鬼)": " (Oni)",
    "(自分)": " (you)",
    "場面:": "Scene:",
    "落とし物:": "Item:",
    "背景:": "Background:",
    "称号": "Awards",
    "称号:": "Awards:",
    "表示": "Show",
    "演出": "Animate",
    "選び直す": "Reroll",
    "動き:": "Motion:",
    "ボットの名前(宣伝用・開発用。空ならふつうの名前。次の試合から)": "Bot names (promo / dev only. Empty = default name. From the next match)",
    "全部ふつうの名前にもどす": "Reset all to default names",
    "ボット%dの名前(空ならふつうの名前)": "Name for Bot %d (empty = default)",
    "ボット%d": "Bot %d",
    "%d/%d人 投票済み": "%d/%d voted",
    "発表へ ▶": "Reveal ▶",
    "次へ ▶": "Next ▶",
    "ルーム主が「次へ」を押すのを待っています": "Waiting for the host to press Next",
    "あやしい人をタップして投票!": "Tap a suspect to vote!",
    "あなたは手下。バレないように!": "You are the helper. Don't get caught!",
    "%s に投票した(入れ直せる)": "Voted for %s (you can change it)",
    "あなたの票": "Your vote",
    "手下!": "Helper!",
    "手下": "Helper",
    "バレバレ!": "Busted!",
    "だましきった!": "Fooled them all!",
    # 試合の最後の称号(Titles)
    # チュートリアル(Tutorial)
    "チュートリアル(遊び方の練習)": "Tutorial (learn to play)",
    "チュートリアルは、ひとりのときに遊べます": "The tutorial is only available offline",
    "はじめて遊ぶ?": "First time playing?",
    "チュートリアルで遊び方を見る?(3分くらい)": "Learn how to play in a quick tutorial? (about 3 min)",
    "あとで": "Later",
    "見る!": "Let's go!",
    "スキップ": "Skip",
    "ようこそ!遊びながら覚えよう(3分くらい)": "Welcome! Let's learn by playing (about 3 min)",
    "鬼がみんなのうしろを歩いて、\nだれかのうしろに落とし物を落とすよ": "The oni walks behind everyone\nand drops an item behind someone",
    "自分と両どなりのうしろは見えないけど、\nほかの人のうしろは見える。ほら、落ちてる!": "You can't see behind yourself or your neighbors,\nbut you can see behind the others. Look, it's there!",
    "振り向くのは、ここぞという1回だけ。\n何もないのに振り向くと「お手つき」!": "Only look back when it counts.\nLook back at nothing and it's a wrong look!",
    "本当のことを教えたね!\nウソを送って、だますこともできるよ": "You told the truth!\nYou could also send a lie to trick them",
    "ウソでだまそうとしたね!\n本当のことを教えるのも、だますのも作戦": "You tried to trick them with a lie!\nTelling the truth and lying are both strategies",
    "鬼が自分のうしろを通ったら、\nまわりが言葉で教えてくれるよ": "When the oni passes behind you,\nothers will send you messages",
    "教えてあげよう!落ちている人をクリックして、\n「%s」を送ろう(ウソをつくこともできるよ)": "Let's tell them! Click the one with the item behind them\nand send \"%s\" (you could also lie)",
    "教えてあげよう!落ちている人をタップして、\n「%s」を送ろう(ウソをつくこともできるよ)": "Let's tell them! Tap the one with the item behind them\nand send \"%s\" (you could also lie)",
    "「%s」を押してね": "Press \"%s\"",
    "教えてもらって気づいた!\n拾って鬼を追いかけるよ": "They got the hint!\nThey grab it and chase the oni",
    "座っている人は、バナナを投げてじゃまできる!\nBキーで鬼にバナナを投げてみよう": "Seated players can throw bananas to get in the way!\nPress B to throw one at the oni",
    "座っている人は、バナナを投げてじゃまできる!\n「鬼にバナナ」を押してみよう": "Seated players can throw bananas to get in the way!\nTap \"Banana the oni\"",
    "ナイス!踏むと転ぶよ。\n追いかける人に投げることもできる": "Nice! Step on one and you fall.\nYou can throw at the chaser too",
    "鬼も言葉を送れるよ。座っている人をクリックして送ろう\n(ウソでだますのもアリ)": "The oni can send messages too. Click a seated player\n(lying to trick them is fine)",
    "鬼も言葉を送れるよ。座っている人をタップして送ろう\n(ウソでだますのもアリ)": "The oni can send messages too. Tap a seated player\n(lying to trick them is fine)",
    "黒板消しで画面を白くして、うしろを見えなくできる!\nMキーを押して、座っている人をクリック": "The eraser whites out a screen so they can't see behind!\nPress M, then click a seated player",
    "黒板消しで画面を白くして、うしろを見えなくできる!\n「黒板消し」を押して、座っている人をタップ": "The eraser whites out a screen so they can't see behind!\nTap Eraser, then tap a seated player",
    "まだだよ!みんなの言葉を待とう": "Not yet! Wait for the messages",
    "スペースキーで振り向いてみよう(いまは何もないよ)": "Press Space to look back (nothing's there right now)",
    "「振り向く」ボタンで振り向いてみよう(いまは何もないよ)": "Tap the Look back button (nothing's there right now)",
    "鬼がうしろを通るよ…": "The oni is passing behind you…",
    "でも、ウソをつく「鬼の手下」がまぎれている!\nだれが何と言ったか、覚えておこう": "But a lying \"minion\" is hiding among them!\nRemember who said what",
    "じつは本当に落ちてるよ!\nスペースキーで振り向いて拾おう": "It really is behind you!\nPress Space to look back and grab it",
    "じつは本当に落ちてるよ!\n「振り向く」ボタンで拾おう": "It really is behind you!\nTap Look back to grab it",
    "鬼を追いかけてタッチ!\nA・Dキーで障害物をよける": "Chase the oni and tag them!\nUse A/D to dodge obstacles",
    "鬼を追いかけてタッチ!\nスティックを左右に倒して障害物をよける": "Chase the oni and tag them!\nPush the stick left/right to dodge",
    "さいごに、ウソをついた手下はだれか、みんなで投票しよう": "Finally, everyone votes on who the lying minion was",
    "「落ちてないよ」とウソをついた人をクリックして投票!": "Click the one who lied \"nothing's there\" to vote!",
    "「落ちてないよ」とウソをついた人をタップして投票!": "Tap the one who lied \"nothing's there\" to vote!",
    "当たり!手下は %s だった。\n当てると点がもらえるよ": "Correct! The minion was %s.\nGuessing right earns points",
    "手下は %s だった。\n当てると点がもらえるよ": "The minion was %s.\nGuessing right earns points",
    "こんどは鬼をやってみよう!\n鬼は自動で歩くよ": "Now try being the oni!\nThe oni walks on its own",
    "Fキーで「フェイク」。\n落とす音だけ出して、だまそう": "Press F to fake:\nmake just the drop sound to trick them",
    "「フェイク」ボタンで、\n落とす音だけ出して、だまそう": "Tap Fake to make\njust the drop sound and trick them",
    "Eキーで、本当に落とそう": "Press E to really drop it",
    "「落とす」ボタンで、本当に落とそう": "Tap Drop to really drop it",
    "ナイス!気づかれずに1周すれば鬼の勝ち。\n気づかれたら追いかけっこ!": "Nice! Go a full lap unnoticed and the oni wins.\nIf they notice, it's a chase!",
    "お手つき!真ん中で体育座り(このラウンドは0点)。\nお休み中も、みんなに言葉は送れるよ": "Wrong look! You sit out in the middle (no points this round).\nYou can still send messages while sitting out",
    "準備OK!": "You're ready!",
    "オンラインで遊ぼう": "Let's play online",
    "ロビーへ ▶": "To the lobby ▶",
    "称号発表!": "Awards!",
    "道連れ名人": "Taking You With Me",
    "お手つきのあと %d人を道連れ": "Dragged down after going out: %d",
    "ウソつき大賞": "Grand Liar Award",
    "手下として %d人をだました": "People fooled as a minion: %d",
    "気づかな賞": "Totally Oblivious",
    "一周まわっても気づかず %d回": "Missed it for a full lap: %d",
    "バナナの被害者": "Banana Victim",
    "バナナで %d回転んだ": "Banana slips: %d",
    "だまされ王": "Most Gullible",
    "ウソを信じて %d回失敗": "Fell for lies: %d",
    "暗やみパニック賞": "Panic in the Dark",
    "暗やみでお手つき %d回": "Wrong looks in the dark: %d",
    "カミナリの目撃者": "Lightning Witness",
    "カミナリの光で %d回見つけた": "Spotted in a lightning flash: %d",
    "ガイコツのお友だち": "Skeleton's Buddy",
    "ガイコツをかかえて %d回走った": "Runs with the skeleton: %d",
    "お手つき王": "King of Wrong Looks",
    "お手つき %d回": "Wrong looks: %d",
    "粉まみれ賞": "Chalk Dust Award",
    "黒板消しを %d回くらった": "Eraser hits taken: %d",
    "びしょぬれ賞": "Soaking Wet Award",
    "水鉄砲を %d回くらった": "Water gun hits taken: %d",
    "まぶしかった賞": "Dazzled Award",
    "フラッシュを %d回くらった": "Flash hits taken: %d",
    "逃げ足No.1": "Fastest Feet",
    "%d回 逃げ切った": "Getaways: %d",
    "名探偵": "Great Detective",
    "手下を %d回当てた": "Minions caught: %d",
    "振り向き名人": "Eagle Eye",
    "振り向いて %d回見つけた": "Found by looking back: %d",
    "信じられる人": "Most Trustworthy",
    "本当の言葉を %d回送った": "True messages: %d",
    "おしゃべりさん": "Chatterbox",
    "言葉を %d回送った": "Messages sent: %d",
    "無口な人": "The Silent Type",
    "言葉は %d回だけ": "Messages sent: only %d",
    "言葉を送らなかった": "Sent no messages",
    "マイペースで賞": "Own Pace Award",
    "平和の使者": "Peacekeeper",
    "事件にまきこまれなかった": "Stayed out of trouble",
    "縁の下の力持ち": "Unsung Hero",
    "そっと輪を支えた": "Quietly held the circle together",
    "安定感No.1": "Steady as a Rock",
    "ずっと落ち着いていた": "Kept calm the whole time",
    "タッチの達人": "Touch Master",
    "鬼に %d回タッチした": "Tagged the oni: %d",
    "鬼の常連": "Oni Regular",
    "鬼を %d回やった": "Rounds as the oni: %d",
    "のんびり楽しんだ": "Just enjoyed the ride",
    "チーン…": "Ding…",
    "音がガタガタ割れるときは「なめらか」を試してね": "If the sound crackles, try \"Smooth\"",
    "音の鳴らし方: %s ▶": "Sound mode: %s ▶",
    "なめらか(お試し)": "Smooth (beta)",
    "このブラウザは GPU を使っていないので重くなります(軽い動きにしています)。\nChrome の設定 → システム →「グラフィック アクセラレーションが使用可能な場合は使用する」をオンにすると軽くなります": "This browser is not using the GPU, so the game is slow (light mode is on).\nIn Chrome: Settings > System > turn on \"Use graphics acceleration when available\".",
    "%d点": "%d pts",
    "ゴシゴシ!": "Wipe wipe!",
    # 停電イベント
    "停電!": "Blackout!",
    "次のラウンドは停電": "Next round: blackout",
    "次のラウンドを停電にする(開発用)": "Blackout next round (dev)",
    # 音
    "🎧 イヤホン推奨": "🎧 Headphones recommended",
    "🔊 音の大きさ": "🔊 Volume",
    "全体": "Master",
    "効果音": "Effects",
    # ロビー
    "うしろ見ちゃダメ!": "Don't Look Back!",
    "ひとりで遊ぶ": "Play solo",
    "部屋を作る\n(ホスト)": "Make a room\n(host)",
    "部屋に入る\n(合言葉)": "Join a room\n(code)",
    "合言葉: ____": "Code: ____",
    "けす": "Del",
    "入る": "Join",
    "もどる": "Back",
    "スタート": "Start",
    "なまえ": "name",
    "名前(%d文字まで)": "Name (up to %d characters)",
    "カラーコード(例: #4D96FF)": "Color code (e.g. #4D96FF)",
    "カラーコードが読めませんでした(例: #4D96FF)": "Couldn't read that color code (e.g. #4D96FF)",
    "%s(タップで名前を変える)": "%s (tap to rename)",
    "人数: %d人\n(タップで変える)": "Players: %d\n(tap to change)",
    "合言葉: %s\n入っている人: %d人(あなたをふくむ) / %d人で遊ぶ\n足りない席はボットが座ります":
        "Code: %s\nJoined: %d (including you) / playing with %d\nBots fill the empty seats",
    "ホストの画面に出ている4桁の数字を入れてください": "Enter the 4-digit code shown on the host's screen",
    "4桁入れてください": "Enter 4 digits",
    "合言葉: %s": "Code: %s",
    # 撮影モード(開発用)
    "正面": "Front",
    "横": "Side",
    "後ろ": "Back",
    "斜め前": "3/4",
    "ふつう": "Normal",
    "困り眉": "Worried",
    "汗だく": "Sweaty",
    "放心": "Dazed",
    "座る": "Sit",
    "体育座り": "Hug knees",
    "立つ": "Stand",
    "走る": "Run",
    "転ぶ": "Fall",
    "向き": "Facing",
    "表情": "Face",
    "ポーズ": "Pose",
    "色": "Color",
    "カメラ": "Camera",
    "近く": "Near",
    "遠く": "Far",
    "背景の色": "Background",
    "輪の場面": "Ring scene",
    "UIを消す": "Hide UI",
    # 教室の飾り・ポン
    "お手つき!": "Oops!",
    "ばしゃっ": "Splash",
    "ぽいっ": "Toss",
    "日": "Sun",
    "月": "Mon",
    "火": "Tue",
    "水": "Wed",
    "木": "Thu",
    "金": "Fri",
    "土": "Sat",
    "%d月%d日(%s)": "%d/%d (%s)",
    "日直 %s": "On duty: %s",
    "なかよく げんきに がんばろう": "Be kind, be happy, do your best",
    "きょうの めあて": "Today's goal",
    "わすれものを しない": "Don't forget your things",
}
# 訳さない(元の文のまま出す)もの: 人の名前の例、書道の字(絵として飾る)、内部で使う目印
KEEP = {"あおい", "友", "夢", "花", "向き:", "表情:", "ポーズ:", "カメラ:"}

JA_OVERRIDE = {"HOW_TO_PLAY": HOW_TO_PLAY_JA, "スタンプ:セーフ!": "セーフ!"}

JP = re.compile(r"[\u3040-\u30ff\u4e00-\u9fff]")
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
SKIP_FILES = ("word_filter.gd", "profile.gd", "game_state.gd")


def code_keys():
    """スクリプトの中の日本語の文(画面に出るもの)を集める"""
    found = []
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True)):
        if path.endswith(SKIP_FILES):
            continue
        for line in open(path, encoding="utf-8"):
            if line.strip().startswith("#"):
                continue
            for m in LIT.finditer(line.split(" # ")[0]):
                v = m.group(1).encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
                if JP.search(v) and v not in found:
                    found.append(v)
    return found


def main():
    keys = list(EN.keys())
    missing = [k for k in code_keys() if k not in EN and k not in KEEP]
    if missing:
        print("翻訳がない文:", file=sys.stderr)
        for k in missing:
            print("  " + repr(k), file=sys.stderr)
        if "--check" in sys.argv:
            sys.exit(1)
    if "--check" in sys.argv:
        print("すべての文に翻訳があります(%d)" % len(keys))
        return
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        w.writerow(["keys"] + LANGS)
        for k in keys:
            w.writerow([k, JA_OVERRIDE.get(k, k), EN[k]])
    with open(DOC_PATH, "w", encoding="utf-8") as f:
        f.write("# 翻訳が必要な文字の一覧\n\n")
        f.write("画面に出る文字は、すべて `assets/i18n/texts.csv`(Godot の翻訳ファイル)にまとめてある。\n")
        f.write("このファイルは `tools/i18n/make_translations.py` で作る(手で書きかえず、スクリプトの辞書を直して作り直す)。\n\n")
        f.write("## しくみ\n")
        f.write("- キーは日本語の元の文。`Label` や `Button` に入れた文字は、Godot が自動で今の言語に置きかえる。\n")
        f.write("- 名前や数字が入る文は、`tr(\"…%s…\") % 値`(static な関数の中は `Locale.t(…)`)で先に置きかえる。`%s` `%d` の数と順番は変えない。\n")
        f.write("- `\\n` は改行。英語は長くなりやすいので短めに訳す(ボタンは文字が小さくなって収まるが、読みにくくなる)。\n")
        f.write("- 言語は最初は端末の言語に合わせ(日本語なら日本語、それ以外は英語)、ロビーの 🌐 ボタンか ⚙メニューで切りかえられる。\n")
        f.write("- スタンプは種類(落ちてる・平気・信じて)で送り、受け取った人の言語で出す。自作の言葉は、受け取った人と言語がちがうときは、受け取った人の言語の初期の言葉で出す。\n\n")
        f.write("## 言語を足すとき\n")
        f.write("1. `tools/i18n/make_translations.py` の `LANGS` に言語のコード(例: `ko`)を足し、`EN` と同じ形の辞書を書く。\n")
        f.write("2. スクリプトを動かして `texts.csv` を作り直す。Godot が `texts.ko.translation` を作る。\n")
        f.write("3. `project.godot` の `internationalization/locale/translations` と、`scripts/core/locale.gd` の `SUPPORTED`・`NAMES`・`FILES` に足す。\n\n")
        f.write("訳さないもの: 人の名前の例(あおい)、書道の字の飾り(友・夢・花)、絵文字。\n\n")
        f.write("## 一覧(%d)\n\n" % len(keys))
        f.write("| キー(日本語の元の文) | 英語 |\n|---|---|\n")
        for k in keys:
            if k == "HOW_TO_PLAY":
                f.write("| HOW_TO_PLAY(あそびかたの長い文。日本語は texts.csv の ja 列) | (texts.csv の en 列) |\n")
                continue
            esc = lambda s: s.replace("|", "\\|").replace("\n", "<br>")
            f.write("| %s | %s |\n" % (esc(k), esc(EN[k])))
    print("wrote", CSV_PATH, DOC_PATH, len(keys))


if __name__ == "__main__":
    main()
