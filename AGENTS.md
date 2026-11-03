# Repository agent instructions

## 外部向け日本語のtextlint

- Xのプロフィールや投稿、App Storeの説明とリリースノート、Webサイトの公開文、公開ドキュメント、サポート文など、外部から見える日本語は公開前に必ずtextlintで検査する。
- 日本語ルールには、一般文書向けの`textlint-rule-preset-japanese`を使用する。技術文書向けの`textlint-rule-preset-ja-technical-writing`へ置き換えない。
- Markdownやテキストファイルは、リポジトリのルートから`npm --prefix docs run lint:text:external -- <対象ファイル>`を実行する。対象ファイルには、`docs`ディレクトリから解決できる相対パスか絶対パスを渡す。
- Swift、TypeScript、HTMLなどへ埋め込む公開文は、変更した日本語だけを一時的なMarkdownファイルへまとめ、同じコマンドで検査してから実装へ反映する。
- Xなどへ実際に投稿する文面は、ブラウザへ入力する前に検査を完了する。
- textlintのエラーを0件にしてから公開する。ルールを無言で無効化せず、例外が必要な場合は理由を示してユーザーと相談する。
- textlint通過後も、人が意味、事実関係、文脈、読みやすさを最終確認する。
- 引用する第三者の原文は変更対象に含めず、こちらが新しく書く部分を検査する。
