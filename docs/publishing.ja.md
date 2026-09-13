[English](publishing.md)

# 0.5.0 公開手順（公開担当者向け）

初回公開バージョンは0.5.0です。GitHub Releasesのv0.5.0に次の3アセットを配置します。

1. `y8960-tech-demo-0.5.0.zip`：利用者が取得するパッケージ。ルートのsetupとlaunchのBAT 2本、デモROM・ソース・説明書。
2. `openmsx-y8960-78469c4-windows-x64.zip`：setupが取得する固定コミットのエミュレーター、C-BIOS、設定、ライセンス表示。
3. `openmsx-y8960-78469c4-source.zip`：対応するエミュレーターソース、依存ソース・パッチ・ビルド手順。

## 配布物の準備

取得先は `config/versions.json` に固定しています。URLを設定したことは、アセットを公開・ダウンロード検証したことを意味しません。公開操作と公開URLでの取得試験は別途行います。

音色データは作者名・出典・原典のCC BY-SA表記を保持し、バージョンを推定しません。作者への問い合わせは公開準備の前提としません。フォークの音色テーブルは変更せず、バイナリと対応ソースの両ZIPへOPLL-NOTICE.txtを追加します。CC BY-SAのバージョンと、実行ファイルへの組み込みに関する互換性は、この表示だけで確定するものではありません。[第三者コンポーネント](licenses.ja.md)を参照してください。

対応ソースZIPは元のソースアーカイブ、依存ソース、パッチを含むビルド資料を保持しています。今回エミュレーター実行ファイルは再ビルドせず、表示文書のみを追加しています。ソースZIPからの独立した再ビルド試験は未実施です。

## 公開手順

1. 配布する3アセットの名前・内容・SHA-256を確認する。ハッシュはconfig/versions.jsonとリリース作業記録を使用する。
2. 日英README、ライセンス表示、対応ソースを確認する。
3. 公開担当者の承認後にcommit・push・v0.5.0タグとReleaseを作成し、3アセットを添付する。準備段階では実行しない。
4. 公開ページから各アセットを再取得し、SHA-256を照合する。
5. runtime・cacheのないローカルフォルダへアプリZIPを展開し、setup-y8960.bat、launch-y8960-tech-demo.batの順に実行する。
6. 起動・操作・音声を確認し、公開URLでの検証結果を記録する。事前のローカルZIPによる試験と区別する。

## アプリZIPの検証・再生成

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

前者は公開一覧、Gitから見えるファイル、ROMハッシュ、BATの数、PowerShell構文、文書リンクを検査します。後者は一覧のファイルだけをdistのZIPへ収録し、全ファイルをハッシュで照合します。既存ZIPは上書きしません。ライセンスの法的評価や公開ダウンロード成功を判定するコマンドではありません。

## ビルドと出典

エミュレーターの対応ソースZIP内README.txtとbuild-local.ps1に従います。C++23対応Visual Studio、Windows SDK、Pythonを使い、依存ライブラリとopenMSXをRelease/x64でビルドします。原文ライセンスはエミュレーターZIPのdocに保持しています。

- [採用フォーク](https://github.com/madscient/openMSX_Y8960/tree/78469c4a0c2010f3252f1c55267f4036ccf8fd74)
- [GPL v2 第3条](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
- [フォント条件](../third-party/fonts/README.ja.md)

確認日：2026-09-13。

## 技術解説資料

日本語・英語とも各30ページです。

- 日本語: [PDF](technical/Y8960-TECH-DEMO-technical.ja.pdf)
- 英語: [PDF](technical/Y8960-TECH-DEMO-technical.en.pdf)

導入済み環境のハッシュが一致しない場合は、最新の配布ZIPを別のローカルフォルダに展開し、setup後に検証してください。既存runtimeを改変して検査を回避しないでください。
