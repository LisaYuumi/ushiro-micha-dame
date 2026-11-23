# 翻訳が必要な文字の一覧

画面に出る文字は、すべて `assets/i18n/texts.csv`(Godot の翻訳ファイル)にまとめてある。
このファイルは `tools/i18n/make_translations.py` で作る(手で書きかえず、スクリプトの辞書を直して作り直す)。

## しくみ
- キーは日本語の元の文。`Label` や `Button` に入れた文字は、Godot が自動で今の言語に置きかえる。
- 名前や数字が入る文は、`tr("…%s…") % 値`(static な関数の中は `Locale.t(…)`)で先に置きかえる。`%s` `%d` の数と順番は変えない。
- `\n` は改行。英語は長くなりやすいので短めに訳す(ボタンは文字が小さくなって収まるが、読みにくくなる)。
- 言語は最初は端末の言語に合わせ(日本語なら日本語、それ以外は英語)、ロビーの 🌐 ボタンか ⚙メニューで切りかえられる。
- スタンプは種類(落ちてる・平気・信じて)で送り、受け取った人の言語で出す。自作の言葉は、受け取った人と言語がちがうときは、受け取った人の言語の初期の言葉で出す。

## 言語を足すとき
1. `tools/i18n/make_translations.py` の `LANGS` に言語のコード(例: `ko`)を足し、`EN` と同じ形の辞書を書く。
2. スクリプトを動かして `texts.csv` を作り直す。Godot が `texts.ko.translation` を作る。
3. `project.godot` の `internationalization/locale/translations` と、`scripts/core/locale.gd` の `SUPPORTED`・`NAMES`・`FILES` に足す。

訳さないもの: 人の名前の例(あおい)、書道の字の飾り(友・夢・花)、絵文字。

## 一覧(443)

| キー(日本語の元の文) | 英語 |
|---|---|
| ハンカチ | Handkerchief |
| 上履き | Indoor shoe |
| ランドセル | School bag |
| 机 | Desk |
| 教卓 | Teacher's desk |
| 日本語 | 日本語 |
| ボット | Bot |
| ボット%d | Bot %d |
| (%s) |  (%s) |
| プレイヤー | Player |
| プレイヤー%d | Player %d |
| (ボット) |  (bot) |
| せっかち | hasty |
| 慎重 | careful |
| うたがい屋 | doubter |
| おしゃべり | chatty |
| あなた | You |
| あなた! | You! |
| 鬼 | Oni |
| 追う人 | chaser |
| 落ちてる | Behind you! |
| 平気 | You're safe |
| 信じて | Trust me |
| 送る相手 | Send to |
| %sに送る | Send to %s |
| スタンプの言葉を変える  😨 👍 🥺 | Change stamp words  😨 👍 🥺 |
| スタンプの言葉(%d文字まで。絵文字は変わりません) | Stamp words (up to %d characters. Emoji stay the same) |
| 初期の言葉に戻す | Reset to default |
| %s の言葉(%d文字まで) | Words for %s (up to %d characters) |
| 初期の言葉に戻しました | Reset to the default words |
| %s(タップで変える) | %s (tap to change) |
| ほかの人の自作の言葉: %s | Others' custom words: %s |
| 表示しない(初期の言葉で表示) | Hide (show defaults) |
| 表示する | Show |
| 落とす | Drop |
| 牛乳 | Milk |
| フェイク | Fake |
| 鬼にバナナ | Banana the oni |
| 追う人にバナナ | Banana the chaser |
| 振り向く | Look back |
| からっぽ | Empty |
| えいっ | Splash! |
| メニュー | Menu |
| やり直し | Restart |
| 役を変えて新しい試合 | New match, other role |
| 上から見る(確認用) | Top view (test) |
| あそびかた | How to play |
| 撮影モード(開発用) | Photo mode (dev) |
| とじる | Close |
| ボットの性格を表示: %s | Show bot personality: %s |
| オン | On |
| オフ | Off |
| HOW_TO_PLAY(あそびかたの長い文。日本語は texts.csv の ja 列) | (texts.csv の en 列) |
| つながりました! ホストがスタートするのを待っています | Connected! Waiting for the host to start |
| (作成中) | (creating) |
| 部屋 %s をさがしています… | Looking for room %s… |
| %s が抜けたのでボットが代わります | %s left. A bot takes over |
| スタート! | Start! |
| つながりました! いまは試合中です。<br>次の試合から参加できます(ホストが新しい試合を始めるまで待ってください) | Connected! A match is in progress.<br>You can join from the next match (wait for the host to start a new one) |
| つながりました! いま %d人。ホストがスタートするのを待っています | Connected! %d players now. Waiting for the host to start |
| ホストとの通信が切れました<br>ページを読み込み直してください | Lost connection to the host<br>Please reload the page |
| 部屋を作っています… | Creating a room… |
| ホストとつながりました | Connected to the host |
| ホストとの通信が切れました | Lost connection to the host |
| 仲介サーバーにつなげません(%d) | Can't reach the relay server (%d) |
| 直接つながりませんでした。<br>全員が同じ Wi-Fi につないで(携帯回線は切って)、ページを読み込み直してもう一度試してください | Couldn't connect directly.<br>Put everyone on the same Wi-Fi (turn off mobile data), reload the page and try again |
| 仲介サーバーから切れました。ページを読み込み直してください | Disconnected from the relay server. Please reload the page |
| 部屋ができました。合言葉: %s | Room created. Code: %s |
| 仲介サーバーにつながりました。部屋 %s に申し込んでいます… | Connected to the relay server. Joining room %s… |
| 仲介サーバーに送れませんでした(%d/%d)。少し待ってもう一度試してください | Couldn't send to the relay server (%d/%d). Wait a moment and try again |
| だれかが入ろうとしています… | Someone is joining… |
| ホストから返事が来ました。直接つないでいます… | The host answered. Connecting directly… |
| お手つきでお休み中(このラウンド0点) | Out after a wrong look (0 pts this round) |
| あなたは鬼の手下 | You are the oni's helper |
| あなたは鬼の手下! | You're the oni's helper! |
| だまして +1点 | Fool someone +1 |
| 鬼が勝てば +2点 | Oni wins +2 |
| ほかの人にはないしょだよ | Keep it secret! |
| 次へ進むのはホストです | The host moves on |
| オンラインでは、鬼は負けた人がやります | Online, the loser becomes the oni |
| あなたが鬼で新しい試合 | New match: you are the oni |
| 座る側で新しい試合 | New match: you sit |
| 撮影モードは、ひとりで遊ぶときだけ | Photo mode is only for solo play |
| かける人をタップ! | Tap someone to splash! |
| かける人をタップしてね | Tap someone to splash |
| 教えた! +%d点<br>(%s を助けた) | Helped! +%d<br>(you helped %s) |
| だました! +%d点<br>(%s が引っかかった) | Fooled! +%d<br>(%s fell for it) |
| となりの人には送れない | You can't send to a neighbor |
| この人には、このラウンドもう送った | Already sent to them this round |
| この人はスタンプがいっぱい(%d つ)<br>鬼が進むと空く。また送れるよ | Their stamps are full (%d)<br>A slot opens as the oni moves on |
| いまは送れない | Can't send now |
| 本物 | real |
| ニセ | fake |
| %s が %s にバナナ! | %s threw a banana at %s! |
| つるっ! %s が転んだ | Whoops! %s fell |
| もう振り向けない!<br>(1ラウンド%d回まで) | No more looks!<br>(%d per round) |
| 空いた席には落とせない | Can't drop behind an empty seat |
| 席の後ろで押してね | Press it behind a seat |
| 牛乳かけられた! | You got milk! |
| %s に牛乳! | Milk on %s! |
| お手つき!<br>真ん中でお休み(このラウンド0点) | Wrong look!<br>Rest in the middle (0 pts this round) |
| 4周したので<br>次の席で自動で落とす | 4 laps done<br>Dropping at the next seat |
| あった! | Found it! |
| 追いかけろ!<br>スティックを左右に倒してよける | Chase!<br>Push the stick left/right to dodge |
| 気づかれた! 逃げろ!<br>スティックを左右に倒してよける | Spotted! Run!<br>Push the stick left/right to dodge |
| %s が追いかけた! | %s gives chase! |
| 鬼 %d周目(%d周で自動で落とす) | Oni lap %d (auto-drop at %d) |
| 鬼が座るまで あと%d周 | Oni sits in %d lap(s) |
| あなたは鬼 | You are the oni |
| ラウンド %d/%d | Round %d/%d |
| いまの落とし物:%s | Item: %s |
| あなた %d点 | You %d pts |
| ラウンド 1/5 | Round 1/5 |
| いまの落とし物:ハンカチ | Item: Handkerchief |
| 見えるまで | Clears in |
| タッチ成功! | Touched! |
| 鬼をつかまえた! やったね | You caught the oni! |
| つかまっちゃった… | Caught… |
| %s にタッチされた | %s touched you |
| タッチ! | Touch! |
| %s が鬼をつかまえた! | %s caught the oni! |
| セーフ! | Safe! |
| 空いた席にすわれた〜! | You made it to the seat! |
| すわられちゃった… | They took your seat… |
| あとちょっとだったのに! | So close! |
| 鬼のかち! | Oni wins! |
| %s の席にすわった! | Sat in %s's seat! |
| 気づかなかった〜! | You didn't notice! |
| うしろに落ちてたよ… | It was right behind you… |
| 気づかれなかった! | Nobody noticed! |
| %s はぜんぜん気づかなかった | %s never noticed |
| %s が気づかなかった! | %s didn't notice! |
| 全員お手つき! | Everyone looked wrong! |
| だれも残らなかった〜! | Nobody was left! |
| 全員お手つき… | Everyone looked wrong… |
| 鬼のかち! みんな振り向きすぎ! | Oni wins! Too much looking back! |
| さいごの結果へ | Final results |
| 次のラウンド(%s)へ | Next round (%s) |
| ホストが「次へ」を押すと | When the host presses Next:  |
| 次へ ▶  | Next ▶  |
| ラウンド %d: %s | Round %d: %s |
| %d位 | #%d |
| ゆうしょう! | Champion! |
| 試合おわり! | Match over! |
| あなたがいちばん! | You're number one! |
| いちばんは %s! | %s is number one! |
| ホストが「次へ」を押すと新しい試合 | A new match starts when the host presses Next |
| 新しい試合へ ▶ | New match ▶ |
| 手下はだれ? | Who's the helper? |
| タップでめくってね | Tap to flip |
| 鬼の手下は… | The oni's helper was… |
| だったよ! |   |
| 鬼がかって +%d点 | Oni won +%d |
| 今回の手下は%d人(だれかはひみつ) | Minions this round: %d (who is secret) |
| 今回は手下が2人!<br>(だれかはひみつ) | Two minions this round!<br>(who is secret) |
| 手下を当てた! +%d点 | You found the minion! +%d |
| 2人だったよ! | were the minions! |
| 手下だと思う人の札をタップ!<br>当たれば +%d点 | Tap who you think is the minion!<br>Correct: +%d |
| 投票した!<br>みんなを待っています | Voted!<br>Waiting for everyone |
| みんなが手下を<br>当てています… | Everyone is guessing<br>the minion… |
| 投票 | Vote |
| 当たり +%d | Correct +%d |
| 教室 | Classroom |
| 海辺 | Beach |
| 夜の教室 | Night Classroom |
| 懐中電灯 | Flashlight |
| メトロノーム | Metronome |
| モナリザ | Mona Lisa |
| ガイコツ | Skeleton |
| フィルム切れ | Out of film |
| フラッシュでまぶしい! | Blinded by the flash! |
| %s をパシャッ! | Snap! Flashed %s! |
| パシャッ! | Snap! |
| カミナリ! | Thunder! |
| 貝殻 | Seashell |
| ビーチボール | Beach ball |
| 浮き輪 | Swim ring |
| 砂の城 | Sandcastle |
| バナナボート | Banana boat |
| 水鉄砲 | Squirt |
| 水鉄砲でかけられた! | You got squirted! |
| %s に水鉄砲! | Squirted %s! |
| 舞台: %s ▶ | Stage: %s ▶ |
| 人数: %d人 | Players: %d |
| きせかえ ▶ | Dress up ▶ |
| 帽子 | Hat |
| メガネ | Glasses |
| リボン | Ribbon |
| 豚の鼻 | Pig nose |
| キャップ | Cap |
| ニット帽 | Beanie |
| シルクハット | Top hat |
| 丸メガネ | Round |
| 四角メガネ | Square |
| つける | Wear |
| なし | None |
| キャンセル | Cancel |
| 黒板消し | Eraser |
| 黒板消しでポンポンされた! | Chalk dust in your face! |
| %s を黒板消しでポンポン! | Chalk dust on %s! |
| ポンポン! | Pat pat! |
| あったー!! | Found it!! |
| うしろ!うしろ! | Right behind! |
| 来てるよ! | Look out! |
| あるある! | It's there! |
| スタンプ:セーフ! | All clear |
| まだまだ | Not yet |
| なんもないよ | Nothing there |
| マジだって! | For real! |
| ぜったいホント | I swear! |
| うそじゃない | No lie! |
| シャッフル | Shuffle |
| スタンプの言葉を自分で作る ▶ | Make my own words ▶ |
| 表示しない(シャッフルの言葉で表示) | Hide (show shuffled words) |
| ガーン! | Oh no! |
| 画面のゆれ: %s | Screen shake: %s |
| だれか | Someone |
| ウソ | Lie |
| ウソ: %s | Lied: %s |
| トントン | Tap tap |
| 鬼の手下は誰? | Who is the Oni's helper? |
| ボットの名前(宣伝用) ▶ | Bot names (promo) ▶ |
| UIを全部消す(撮影用・長押しで戻る) | Hide all UI (for capture; long-press to show) |
| 輪の全体 | Whole circle |
| 教室の全体 | Whole room |
| キャラの寄り | Close-up |
| 鬼の後ろ | Behind the Oni |
| 自由 | Free |
| 歩く | Walk |
| ひざ崩れ | Collapse |
| 驚く | Surprised |
| ガーン | Shocked |
| 勝ち | Win |
| 負け | Lose |
| ニヤニヤ | Smirk |
| 気まずい | Awkward |
| お手つき | Oops |
| 必死 | Panic |
| 手に持つ | In hand |
| 背中の後ろ | Behind back |
| 保存しています… | Saving… |
| ダウンロードしました:  | Downloaded:  |
| 保存しました:  | Saved:  |
| 保存できませんでした(%d) | Could not save (%d) |
| 場面 | Scene |
| キャラ | Character |
| 全員に | Apply to all |
| 落とし物 | Item |
| 種類 ▶ | Kind ▶ |
| 背景 | Background |
| キャラだけ | Characters only |
| 動き | Motion |
| うごく | Move |
| 止める | Freeze |
| UIを消す(H) | Hide UI (H) |
| 4Kで保存 | Save 4K |
| (鬼) |  (Oni) |
| (自分) |  (you) |
| 場面: | Scene: |
| 落とし物: | Item: |
| 背景: | Background: |
| 称号 | Awards |
| 称号: | Awards: |
| 表示 | Show |
| 演出 | Animate |
| 選び直す | Reroll |
| 動き: | Motion: |
| ボットの名前(宣伝用・開発用。空ならふつうの名前。次の試合から) | Bot names (promo / dev only. Empty = default name. From the next match) |
| 全部ふつうの名前にもどす | Reset all to default names |
| ボット%dの名前(空ならふつうの名前) | Name for Bot %d (empty = default) |
| %d/%d人 投票済み | %d/%d voted |
| 発表へ ▶ | Reveal ▶ |
| 次へ ▶ | Next ▶ |
| ルーム主が「次へ」を押すのを待っています | Waiting for the host to press Next |
| あやしい人をタップして投票! | Tap a suspect to vote! |
| あなたは手下。バレないように! | You are the helper. Don't get caught! |
| %s に投票した(入れ直せる) | Voted for %s (you can change it) |
| あなたの票 | Your vote |
| 手下! | Helper! |
| 手下 | Helper |
| バレバレ! | Busted! |
| だましきった! | Fooled them all! |
| チュートリアル(遊び方の練習) | Tutorial (learn to play) |
| チュートリアルは、ひとりのときに遊べます | The tutorial is only available offline |
| はじめて遊ぶ? | First time playing? |
| チュートリアルで遊び方を見る?(3分くらい) | Learn how to play in a quick tutorial? (about 3 min) |
| あとで | Later |
| 見る! | Let's go! |
| スキップ | Skip |
| ようこそ!遊びながら覚えよう(3分くらい) | Welcome! Let's learn by playing (about 3 min) |
| 鬼がみんなのうしろを歩いて、<br>だれかのうしろに落とし物を落とすよ | The oni walks behind everyone<br>and drops an item behind someone |
| 自分と両どなりのうしろは見えないけど、<br>ほかの人のうしろは見える。ほら、落ちてる! | You can't see behind yourself or your neighbors,<br>but you can see behind the others. Look, it's there! |
| 振り向くのは、ここぞという1回だけ。<br>何もないのに振り向くと「お手つき」! | Only look back when it counts.<br>Look back at nothing and it's a wrong look! |
| 本当のことを教えたね!<br>ウソを送って、だますこともできるよ | You told the truth!<br>You could also send a lie to trick them |
| ウソでだまそうとしたね!<br>本当のことを教えるのも、だますのも作戦 | You tried to trick them with a lie!<br>Telling the truth and lying are both strategies |
| 鬼が自分のうしろを通ったら、<br>まわりが言葉で教えてくれるよ | When the oni passes behind you,<br>others will send you messages |
| 教えてあげよう!落ちている人をクリックして、<br>「%s」を送ろう(ウソをつくこともできるよ) | Let's tell them! Click the one with the item behind them<br>and send "%s" (you could also lie) |
| 教えてあげよう!落ちている人をタップして、<br>「%s」を送ろう(ウソをつくこともできるよ) | Let's tell them! Tap the one with the item behind them<br>and send "%s" (you could also lie) |
| 「%s」を押してね | Press "%s" |
| 教えてもらって気づいた!<br>拾って鬼を追いかけるよ | They got the hint!<br>They grab it and chase the oni |
| 座っている人は、バナナを投げてじゃまできる!<br>Bキーで鬼にバナナを投げてみよう | Seated players can throw bananas to get in the way!<br>Press B to throw one at the oni |
| 座っている人は、バナナを投げてじゃまできる!<br>「鬼にバナナ」を押してみよう | Seated players can throw bananas to get in the way!<br>Tap "Banana the oni" |
| ナイス!踏むと転ぶよ。<br>追いかける人に投げることもできる | Nice! Step on one and you fall.<br>You can throw at the chaser too |
| 鬼も言葉を送れるよ。座っている人をクリックして送ろう<br>(ウソでだますのもアリ) | The oni can send messages too. Click a seated player<br>(lying to trick them is fine) |
| 鬼も言葉を送れるよ。座っている人をタップして送ろう<br>(ウソでだますのもアリ) | The oni can send messages too. Tap a seated player<br>(lying to trick them is fine) |
| 黒板消しで画面を白くして、うしろを見えなくできる!<br>Mキーを押して、座っている人をクリック | The eraser whites out a screen so they can't see behind!<br>Press M, then click a seated player |
| 黒板消しで画面を白くして、うしろを見えなくできる!<br>「黒板消し」を押して、座っている人をタップ | The eraser whites out a screen so they can't see behind!<br>Tap Eraser, then tap a seated player |
| まだだよ!みんなの言葉を待とう | Not yet! Wait for the messages |
| スペースキーで振り向いてみよう(いまは何もないよ) | Press Space to look back (nothing's there right now) |
| 「振り向く」ボタンで振り向いてみよう(いまは何もないよ) | Tap the Look back button (nothing's there right now) |
| 鬼がうしろを通るよ… | The oni is passing behind you… |
| でも、ウソをつく「鬼の手下」がまぎれている!<br>だれが何と言ったか、覚えておこう | But a lying "minion" is hiding among them!<br>Remember who said what |
| じつは本当に落ちてるよ!<br>スペースキーで振り向いて拾おう | It really is behind you!<br>Press Space to look back and grab it |
| じつは本当に落ちてるよ!<br>「振り向く」ボタンで拾おう | It really is behind you!<br>Tap Look back to grab it |
| 鬼を追いかけてタッチ!<br>A・Dキーで障害物をよける | Chase the oni and tag them!<br>Use A/D to dodge obstacles |
| 鬼を追いかけてタッチ!<br>スティックを左右に倒して障害物をよける | Chase the oni and tag them!<br>Push the stick left/right to dodge |
| さいごに、ウソをついた手下はだれか、みんなで投票しよう | Finally, everyone votes on who the lying minion was |
| 「落ちてないよ」とウソをついた人をクリックして投票! | Click the one who lied "nothing's there" to vote! |
| 「落ちてないよ」とウソをついた人をタップして投票! | Tap the one who lied "nothing's there" to vote! |
| 当たり!手下は %s だった。<br>当てると点がもらえるよ | Correct! The minion was %s.<br>Guessing right earns points |
| 手下は %s だった。<br>当てると点がもらえるよ | The minion was %s.<br>Guessing right earns points |
| こんどは鬼をやってみよう!<br>鬼は自動で歩くよ | Now try being the oni!<br>The oni walks on its own |
| Fキーで「フェイク」。<br>落とす音だけ出して、だまそう | Press F to fake:<br>make just the drop sound to trick them |
| 「フェイク」ボタンで、<br>落とす音だけ出して、だまそう | Tap Fake to make<br>just the drop sound and trick them |
| Eキーで、本当に落とそう | Press E to really drop it |
| 「落とす」ボタンで、本当に落とそう | Tap Drop to really drop it |
| ナイス!気づかれずに1周すれば鬼の勝ち。<br>気づかれたら追いかけっこ! | Nice! Go a full lap unnoticed and the oni wins.<br>If they notice, it's a chase! |
| お手つき!真ん中で体育座り(このラウンドは0点)。<br>お休み中も、みんなに言葉は送れるよ | Wrong look! You sit out in the middle (no points this round).<br>You can still send messages while sitting out |
| 準備OK! | You're ready! |
| オンラインで遊ぼう | Let's play online |
| ロビーへ ▶ | To the lobby ▶ |
| 称号発表! | Awards! |
| みんながだまされる中、手下を %d回見抜いた | Saw through the minion while others were fooled: %d |
| 鬼で %d回 逃げ切った | Got away as the oni: %d |
| %s ・ %s | %s · %s |
| 記念写真 | Group Photo |
| 手下ハンター | Minion Hunter |
| 手下を %d回当てた | Minions caught: %d |
| 信じられる人 | Most Trustworthy |
| 本当の言葉を %d回送った | True messages: %d |
| おしゃべりさん | Chatterbox |
| 言葉を %d回送った | Messages sent: %d |
| 鬼の常連 | Oni Regular |
| 鬼を %d回やった | Rounds as the oni: %d |
| 道連れ名人 | Taking You With Me |
| お手つきのあと %d人を道連れ | Dragged down after going out: %d |
| ウソつき大賞 | Grand Liar Award |
| 手下として %d人をだました | People fooled as a minion: %d |
| 気づかな賞 | Totally Oblivious |
| 一周まわっても気づかず %d回 | Missed it for a full lap: %d |
| バナナの被害者 | Banana Victim |
| バナナで %d回転んだ | Banana slips: %d |
| だまされ王 | Most Gullible |
| ウソを信じて %d回失敗 | Fell for lies: %d |
| 暗やみパニック賞 | Panic in the Dark |
| 暗やみでお手つき %d回 | Wrong looks in the dark: %d |
| カミナリの目撃者 | Lightning Witness |
| カミナリの光で %d回見つけた | Spotted in a lightning flash: %d |
| お手つき王 | King of Wrong Looks |
| お手つき %d回 | Wrong looks: %d |
| 粉まみれ賞 | Chalk Dust Award |
| 黒板消しを %d回くらった | Eraser hits taken: %d |
| びしょぬれ賞 | Soaking Wet Award |
| 水鉄砲を %d回くらった | Water gun hits taken: %d |
| まぶしかった賞 | Dazzled Award |
| フラッシュを %d回くらった | Flash hits taken: %d |
| 逃げ足No.1 | Fastest Feet |
| 名探偵 | Great Detective |
| 振り向き名人 | Eagle Eye |
| 振り向いて %d回見つけた | Found by looking back: %d |
| タッチの達人 | Touch Master |
| 鬼に %d回タッチした | Tagged the oni: %d |
| チーン… | Ding… |
| 音がガタガタ割れるときは「なめらか」を試してね | If the sound crackles, try "Smooth" |
| 音の鳴らし方: %s ▶ | Sound mode: %s ▶ |
| なめらか(お試し) | Smooth (beta) |
| このブラウザは GPU を使っていないので重くなります(軽い動きにしています)。<br>Chrome の設定 → システム →「グラフィック アクセラレーションが使用可能な場合は使用する」をオンにすると軽くなります | This browser is not using the GPU, so the game is slow (light mode is on).<br>In Chrome: Settings > System > turn on "Use graphics acceleration when available". |
| %d点 | %d pts |
| ゴシゴシ! | Wipe wipe! |
| 停電! | Blackout! |
| 次のラウンドは停電 | Next round: blackout |
| 次のラウンドを停電にする(開発用) | Blackout next round (dev) |
| 🎧 イヤホン推奨 | 🎧 Headphones recommended |
| 🔊 音の大きさ | 🔊 Volume |
| 全体 | Master |
| 効果音 | Effects |
| うしろ見ちゃダメ! | Don't Look Back! |
| ひとりで遊ぶ | Play solo |
| 部屋を作る<br>(ホスト) | Make a room<br>(host) |
| 部屋に入る<br>(合言葉) | Join a room<br>(code) |
| 合言葉: ____ | Code: ____ |
| けす | Del |
| 入る | Join |
| もどる | Back |
| スタート | Start |
| なまえ | name |
| 名前(%d文字まで) | Name (up to %d characters) |
| カラーコード(例: #4D96FF) | Color code (e.g. #4D96FF) |
| カラーコードが読めませんでした(例: #4D96FF) | Couldn't read that color code (e.g. #4D96FF) |
| %s(タップで名前を変える) | %s (tap to rename) |
| 人数: %d人<br>(タップで変える) | Players: %d<br>(tap to change) |
| 合言葉: %s<br>入っている人: %d人(あなたをふくむ) / %d人で遊ぶ<br>足りない席はボットが座ります | Code: %s<br>Joined: %d (including you) / playing with %d<br>Bots fill the empty seats |
| ホストの画面に出ている4桁の数字を入れてください | Enter the 4-digit code shown on the host's screen |
| 4桁入れてください | Enter 4 digits |
| 合言葉: %s | Code: %s |
| 正面 | Front |
| 横 | Side |
| 後ろ | Back |
| 斜め前 | 3/4 |
| ふつう | Normal |
| 困り眉 | Worried |
| 汗だく | Sweaty |
| 放心 | Dazed |
| 座る | Sit |
| 体育座り | Hug knees |
| 立つ | Stand |
| 走る | Run |
| 転ぶ | Fall |
| 向き | Facing |
| 表情 | Face |
| ポーズ | Pose |
| 色 | Color |
| カメラ | Camera |
| 近く | Near |
| 遠く | Far |
| 背景の色 | Background |
| 輪の場面 | Ring scene |
| UIを消す | Hide UI |
| お手つき! | Oops! |
| ばしゃっ | Splash |
| ぽいっ | Toss |
| 日 | Sun |
| 月 | Mon |
| 火 | Tue |
| 水 | Wed |
| 木 | Thu |
| 金 | Fri |
| 土 | Sat |
| %d月%d日(%s) | %d/%d (%s) |
| 日直 %s | On duty: %s |
| なかよく げんきに がんばろう | Be kind, be happy, do your best |
| きょうの めあて | Today's goal |
| わすれものを しない | Don't forget your things |
