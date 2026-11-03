# App Store スクリーンショット制作パイプライン

- 調査日: 2026-09-13
- 対象: Treow iOS / iPadOS
- 状態: iPhone・iPad各7枚の生成・検証と、4種類の比較案を実装済み

## 結論

Treowでは、次の3段階を分離する。

1. **実画面の取得**: XCUITest + Simulator
2. **マーケティング画像への合成**: HTML/CSSテンプレート + Playwright
3. **検証・公開**: ローカル検証 + App Store Connect Preview / Product Page Optimization

Figmaは初期のアートディレクション確認に使ってよいが、最終成果物の正本にはしない。コピー、色、余白、入力画像、出力サイズをリポジトリ内のmanifestとテンプレートで管理し、同じコミットから同じ画像セットを再生成する。

```bash
cd scripts/ops
npm run marketing:render
npm run marketing:verify
npm run marketing:render:ipad
npm run marketing:verify:ipad
npm run marketing:proposals
npm run marketing:proposals:verify
```

生成先は`marketing/app-store/output/ja-JP/`。`iphone-6.9/`と`ipad-13/`へ、それぞれ7枚を生成する。比較案は`marketing/app-store/proposals/output/`へ出力する。

## 競合調査から確認できたこと

Day One、muute、Awarefy、Structuredなどは、次の表現を共通して採用している。

- 先頭3枚を「価値・信頼 → 体験 → 得られる変化」の順にする
- 1枚につき大見出し1つに絞る
- 実画面全体を縮小せず、重要部分を大きく見せる
- 背景色、書体、端末位置をセット全体で統一する
- 日本向け画像では日本語コピーを使う

公開されたApp Store画像から、各社がFigma、Photoshopなどのどの制作アプリを使ったかを確定することはできない。配信画像だけを根拠に特定ツール名を断定しない。

公開情報で確認できた制作プロセスは、次の範囲に限られる。

- Awarefyは組織としてFigmaとMiroを利用し、デザイナーが用意したFigmaテンプレートをマーケティング用モックやメディアのカバー制作にも使っている。ただし、これはApp Store掲載画像そのものをFigmaで制作した証拠ではない
- muuteはデザインを継続的に検証・改善している過程を公開しているが、App Store画像の制作ツール名は公開していない
- Structuredもプロダクトとブランドの反復的な改善を公開しているが、App Store画像の制作ツール名は公開していない

したがって、競合の非公開ワークフローを推測してコピーするのではなく、確認できた表現原則をTreow向けの再現可能な工程へ置き換える。

### Awarefyから取り入れる情報設計

2026-09-13時点のAwarefy日本向け画像は8枚である。「感情的な約束 → 実績・信頼 → AIの仕組み → 記録蓄積の価値 → 個別最適 → 学習 → 専門性 → 目指す状態」の順に展開している。見た目から確認・計測できる特徴は次のとおり。

- 1枚につき1メッセージ、見出しはおおむね18〜27字・2行
- 左右6〜9%を安全域とし、上端12〜14%付近から見出しを置く
- 主ビジュアルは上端34〜51%付近から始め、下端まで大胆にブリードさせる
- 白〜淡色の余白を広く使い、ブランド色の大きな曲面で視線を誘導する
- 中央の実画面は横幅70〜85%程度。複数画面では重なりと小さな傾きを付ける
- 実績値・専門家監修は独立した画像で信頼材料として見せる

Treowではこの情報設計だけを採用し、シアン、キャラクター、コピーは模倣しない。ベージュ、ブラウン、樹木・年輪へ置き換える。現在は公開可能なダウンロード数やNo.1根拠がないため、Awarefyの2枚目に相当する社会的証明は作らず、「日記・AIコーチ・タスクがつながる」という製品構造を見せる。

## ツール比較

| ツール | 得意領域 | 再現性 | Treowでの扱い |
|---|---|---:|---|
| XCUITest / `xcodebuild` | 固定データで実画面を自動撮影 | 高 | 採用。既存資産を拡張する |
| Playwright + HTML/CSS | コピー、背景、端末枠、配置をコードからPNG化 | 高 | 最終画像の生成に採用 |
| Figma | レイアウトの初期検討、共同レビュー | 中 | 任意。探索用で、正本にはしない |
| fastlane `snapshot` | 複数端末・言語のXCUITest撮影 | 高 | 多言語化時の候補。現時点では既存スクリプトを優先 |
| fastlane `frameit` | 端末枠、背景、見出しの一括合成 | 中〜高 | 導入依存が増えるため第2候補 |
| AppScreens | 端末サイズ、言語、PPO案をGUIで一括生成 | 中 | 素早い試作向け。クラウドプロジェクトを正本にしない |
| Rotato | 3D端末モック、動画、立体的な静止画 | 中 | App PreviewやSNS動画を作る段階で検討 |
| StoreScreens | 1つのYAMLから撮影、合成、翻訳、提出を扱うSwift CLI / MCP | 高 | 有力な比較対象。ただし新しい外部依存なので、PoCで出力品質と保守性を確認してから採用判断 |

AppleはFigma、Photoshop、Pixelmator、Sketch向けテンプレートを提供しているが、特定の制作アプリを必須にはしていない。Appleの要件は、実際のアプリ体験を正確に見せ、短く読みやすいコピーを使い、必要なサイズ・形式へ出力することである。

現在のTreow開発環境には`xcodebuild`、Node.js、既存のPlaywright依存があり、XCUITest撮影スクリプトも存在する。一方、fastlane、ImageMagick、`pngcheck`は未導入である。このため、最初の実装は既存資産を利用できるXCUITest + Playwrightとし、新しいランタイムを増やさない。

## Treowの制作仕様

### 先頭3枚

| 順番 | 大見出し | 補足 | 主役となる実画面 |
|---:|---|---|---|
| 1 | 日記が、次の一歩になる。 | 書く・話す・動くを、ひとつの循環に | ジャーナル + 循環が分かる構成 |
| 2 | 答えではなく、問いを返す。 | あなたの言葉を深めるAIコーチ | コーチ会話 |
| 3 | 小さな行動へ、つなげていく。 | 意図と振り返りを残せるタスク | タスク / 事後振り返り |

### 4〜7枚目

4. ひとことから、気軽に書ける。
5. 必要な言葉に、すぐ戻れる。
6. 過去の自分と、対話する。
7. 一日の記録を、まとめて振り返る。

比較案のDは、Face IDアプリロックの実装後を想定した将来案である。現在の提出対象には含めない。

### ビジュアルトークン

- 背景: Treowの温かいベージュを基本にする
- 見出し: 濃いブラウン、高コントラスト、10〜16文字を目安にする
- 補足: 1〜2行、20〜30文字を目安にする
- 構成: 上部約35%をコピー、下部約65%を実画面に使う
- 装飾: 木、葉、年輪、循環を連想する線を控えめに使う
- 実画面: 内容を改変せず、必要箇所の拡大・切り抜きだけを行う
- 禁止: 根拠のないNo.1、利用者数、受賞、治療効果、「100%プライベート」など実装範囲を超える断定

## 想定ディレクトリ

現在の構成は次のとおり。

```text
marketing/app-store/
  manifest.json              # iPhoneの順番、コピー、入力画面、出力サイズ
  manifest-ipad.json         # iPad専用の入力・出力サイズ
  templates/
    screenshot.html
    screenshot.css
    screenshot-ipad.css
  output/
    ja-JP/iphone-6.9/
    ja-JP/ipad-13/
  proposals/                 # 比較案の定義と出力
scripts/ops/src/marketing/
  render-app-store-screenshots.mjs
  verify-app-store-screenshots.mjs
  render-app-store-ipad-screenshots.mjs
  verify-app-store-ipad-screenshots.mjs
  render-app-store-proposals.mjs
  verify-app-store-proposals.mjs
```

現在の未加工画面は`docs/public/screenshots/`を参照する。将来多言語へ拡張するときは、撮影済み素材を`marketing/app-store/raw/{locale}/{device}/`へ分離する。

生成物のファイル名は、並び順がそのまま分かるようにする。

```text
01-journal-to-action.png
02-questioning-coach.png
03-insight-to-task.png
```

## 再現可能な生成手順

### 1. 撮影状態を固定する

- `--uitesting`で通信を止め、固定ユーザーと固定データを使う
- 表示言語・地域を `ja-JP` に固定する
- 日付も起動引数から固定する。現在の`TestDataProvider`は`Date()`を使うため、レンダラー実装時にスクリーンショット専用の基準日を注入可能にする
- Simulatorの時刻を9:41、電池を100%、通信表示を固定する
- Reduce Motionまたはテスト用フラグでアニメーションを止める
- 既存の公開画像へ直接上書きせず、一時ディレクトリへ撮影してから検証済み画像だけを採用する

### 2. manifestから合成する

manifestに次を明示する。

- locale
- 出力端末とピクセル寸法
- 画像の順番
- 大見出し、補足文
- 入力するraw画像
- crop / scale / x / y
- 背景色、文字色、アクセント色
- テンプレートのバージョン

Playwrightで固定viewportのHTMLを表示し、1画像ずつPNGへ書き出す。人手でドラッグした座標を最終状態にしない。

### 3. 自動検証する

- iPhone 6.9インチ: `1290 x 2796` PNG
- iPad 13インチ: 出力は`2048 x 2732` PNG。入力素材は`2064 x 2752`を使用する
- アルファチャンネルなし
- 1〜10枚の範囲
- ファイル名とmanifestの順番が一致
- raw画像とコピーの参照切れがない
- 同じ入力を2回生成したときにハッシュが一致

最後に実寸とApp Store上の縮小表示の両方を目視し、コピーの改行、文字切れ、UIの可読性、最新UIとの一致を確認する。

## 公開と検証

- 生成とApp Store Connectへのアップロードは別コマンドにする
- アップロード前に差分一覧と縮小プレビューを確認する
- まず現行3枚をControl、新しい先頭3枚をTreatmentにした1対1のPPOを行う
- 小規模トラフィックでは複数Treatmentへ分散させず、最初は1変数だけを比較する
- 勝者確定後に通常の製品ページへ反映する

## 参照

- [Apple: Creating your product page](https://developer.apple.com/app-store/product-page/)
- [Apple: App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/)
- [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apple: Product Page Optimization](https://developer.apple.com/app-store/product-page-optimization/)
- [fastlane: Automating screenshots](https://docs.fastlane.tools/getting-started/ios/screenshots/)
- [fastlane: frameit](https://docs.fastlane.tools/actions/frameit/)
- [AppScreens](https://appscreens.com/)
- [Rotato: App Store screenshots](https://rotato.app/help/topic/app-store-screenshots)
- [StoreScreens](https://storescreens.app/)
- [Spectrum Tokyo: Awarefyの一人目デザイナーへのインタビュー](https://spectrumtokyo.com/jp/interviews/the-first-designer-of-awarefy/)
- [Cocoda: Awarefyブランドリニューアルの工程](https://cocoda.design/iktakahiro/p/pd1210f020ab2)
- [Awarefy: ブランドリニューアル発表](https://www.awarefy.com/news/press-release-20240509)
- [muute: デザインの裏側](https://note.com/muute_journaling/n/n31130b109404)
- [Structured: 2 Years of Structured](https://structured.app/blog/2-years)

## App Store Connectへの登録

運用スクリプトは通常、読み取り確認だけを行う。`APPLY=1`を指定すると登録内容を変更する。

- `asc:upload-screenshots`: 生成済み7枚を検証して登録する
- `asc:update-whats-new`: 更新内容を設定する
- `asc:update-review-details`: 審査情報を設定する
- `asc:attach-build`: 対象バージョンへビルドを紐付ける
- `asc:submit-app-version-review`: 必要な画像とビルドを確認して審査へ提出する

画像登録が対応する表示枠は、`APP_IPHONE_67`と`APP_IPAD_PRO_3GEN_129`である。既存画像を置き換える場合は、`REPLACE=1`も必要になる。

既存画像と新規画像の合計が10枚を超える場合、追加前に停止する。対象バージョンと表示枠を確認し、`asc:clear-screenshots`で既存画像を明示的に削除してから登録する。
