[English](development.md)

# 開発手順

対象は `madscient/openMSX_Y8960` のコミット `78469c4a0c2010f3252f1c55267f4036ccf8fd74`、C-BIOS MSX2+（60 Hz）、Z80、通常のV9958です。カートリッジAに16 KiBのデモ、BにHRA_Y8960を配置します。この機種ではBが基本スロット2です。他のスロット構成や実機は、このデモの対応対象に含めていません。

## デモの再ビルド

z88dkとPython 3を用意し、リポジトリ直下で実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\build-demo.ps1 -Z88dk "path\to\z88dk"
```

`-Z88dk` 省略時はZ88DK、ZCCCFG、PATHの順に確認し、見つからなければフォルダ選択を表示します。明示したパスが不正な場合は停止します。環境変数は実行プロセス内だけで変更します。Pythonで音程表、オリジナルの旋律とADPCM打楽器を生成し、z88dkで `src/main.c` をコンパイルします。ROMサイズとBSS範囲を検査し、`demo/Y8960-DEMO.rom` と `config/versions.json` のROMハッシュを更新します。変更後は再検証してください。

楽譜ではなく音番号と長さで編集できます。`melody` と `bass_notes` が曲の素材です。描画中の経過時間もBIOSのJIFFYカウンターで数え、15ティックで1ステップ進み、60 Hzで128ステップ、約32秒になります。セクション切り替え時は直前の発音を止めます。画面はSCREEN 5で、メーターは音声測定値ではなく発音状況の表示です。

## 音源と機種の前提

- BIOSのWRTSLTでスロット2の0x7ff6、0x7fffを書き、音源I/Oを有効化します。
- SSGSはA0/A1、レジスタ群0x00/0x20、パンは0x10〜0x12です。
- OPLLは7C/7Dと7A/7B、OPL2/ADPCM-BはC0/C1とC2/C3です。
- 共有サンプルRAMの先頭に、各2 KiBの自作ADPCM音を置きます。2個目のOPL2はADPCM発音に使い、2本目のFMベースには使いません。
- フォーク標準のY8960出力を使い、本体側の音声はミックスしません。DCSG、SCC、ハードウェアタイマーによる再生は今回のデモに含めません。
- 1re1さんのMSX 8x8 fontと、C-BIOSのカートリッジ用BIOS呼び出しを使用します。MSX BASICやDisk BASICを使う構成ではありません。

## エミュレーターの配布

配布アセットの構成、ビルド、ソース提供、公開条件は[公開担当者向け手順](publishing.ja.md)を参照してください。

## パッケージ作成

`tests/validate-public.ps1` は公開対象一覧、ROMハッシュ、ルートのBAT、スクリプトの構文、文書内のローカルリンクを検査します。`scripts/package.ps1` は一覧に従ってZIPを作成し、既存ZIPは上書きしません。runtime、キャッシュ、ログ、コンパイラーの中間生成物は除外します。ソース・デモ用ZIPにはローカルのエミュレーターZIPを含めません。

## 参考資料とライセンス

確認日：2026-09-13

- [フォークのソースとビルド手順](https://github.com/madscient/openMSX_Y8960/tree/78469c4a0c2010f3252f1c55267f4036ccf8fd74)
- [現在の実装状況](https://github.com/madscient/openMSX_Y8960/blob/78469c4a0c2010f3252f1c55267f4036ccf8fd74/doc/fork/README.md)
- [カートリッジの接続設定](https://github.com/madscient/openMSX_Y8960/blob/78469c4a0c2010f3252f1c55267f4036ccf8fd74/share/extensions/HRA_Y8960.xml)
- [公式openMSX 21.0パッケージ](https://github.com/openMSX/openMSX/releases/tag/RELEASE_21_0)
- [z88dk](https://github.com/z88dk/z88dk)

デモと自作音声データには本リポジトリのMITライセンスを適用します。openMSXはGPLで、C-BIOSなどはそれぞれのライセンス原文と表示を維持します。FS-A1GTや商用BIOSは使用しません。

## 描画とメモリ

通常のV9958のSCREEN 5（256×212、16色）を使用します。背景は色4（RGB 1,2,3）、文字は色15（7,7,7）、影は色1（0,1,1）です。RGBの各成分は0〜7です。字形の右下1ピクセルに影を描き、前景を優先します。

可視ビットマップはVRAMのページ0、0〜27135バイトを使います。HMMVで背景・進行表示を塗り、CPUが文字の画像データを1行ずつ作り、画面用メモリ（VRAM）へ連続転送します。転送にはZ80のOTIR命令を使います。レジスタ14で16 KiB境界を扱い、コマンドのCE待ちではステータス2を読んだ後にステータス0へ戻してから割り込みを許可します。文字列1本は全幅×9行の領域を所有します。4ピクセル単位の合成表を生成して描画負荷を抑えています。

RAMはBSSを0xC100未満に制限し、0xC100〜0xC107をテスト用、0xC200〜0xC27Fを128バイトの走査線バッファとして予約しています。ヒープは使いません。演奏中は事前描画した文字をコピーし、発音を描画より先に処理します。時間進行にはJIFFYの差分を使い、厳密なサンプル同期は行いません。

[フォントの出典と利用条件](../third-party/fonts/README.ja.md)も参照してください。

## 音声優先の更新と自動テスト

メインループは、経過したJIFFYを反映して発音を処理した後に描画します。シーン切り替え時も `quiet → play → draw_slice` の順です。音声割り込み方式ではありません。

4シーンの見出しを起動時に影付きで描き、非表示のVRAMページ1（Y=256〜383）へ保存します。PLAYING/MUTED/PAUSEDはY=384、400、416です。演奏中はHMMMで画面へコピーし、転送完了をその場で待ちません。通常のシーン切り替えでは、準備済みの画像をコピーします。起動時に文字画像を準備します。

`draw_slice()` は1ループにつき1作業だけを実行します。見出し、状態表示、8本のバー、進行表示の順に処理し、バーは1本ずつ更新します。VDPが処理中、または次の発音まで1ティック以下の場合は描画を見送ります。進行表示の小さなHMMVは同期完了待ちを残しています。負荷が高いときは表示の追従が遅れることを許容します。

セットアップ済みのリポジトリ直下で、以下を実行します。開発テストにはPython 3が必要です。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-audio-timing.ps1
```

新しい `logs/timing-日時/` へ70秒分の音源I/O記録、PCM録音、ROMハッシュと判定結果を保存します。`-Work` で未作成の出力先も指定できます。画面に表示するFPSやROM自身が申告する遅延値ではなく、openMSXのI/OウォッチポイントでSSG主旋律の実際の書き込み時刻を測ります。

検査は、音程・音量の順序（抜け／重複）、発音間隔、累積ずれ、シーン境界、意図しない消音区間を対象とします。NTSCの15 VBlankを基準に、通常間隔と累積ずれは2 VBlank以内、境界は1 VBlank以内、quietから発音までは10ms以内とします。非休符で始まる各境界のPCMも調べ、RMS 1未満の区間が20ms以上連続すれば失敗します。失敗はPowerShellのエラーとして返します。

検出器自体の負例テスト：

```powershell
python tests\test-timing-analyzer.py logs\timing-日時
```

正常な記録のコピーから1音を削除、境界の発音を100ms遅延、PCMへ50msの無音を挿入し、それぞれ不合格になることを確認します。元の記録データ（CSV・WAV）は変更しません。解析結果JSONは再生成します。

SSGの時刻は伴奏更新の代表指標であり、全音源の全レジスタのタイミングを保証するものではありません。PC側の音声バッファの途切れ、全種類のクリックノイズ、実機や別CPUでの動作もこの試験の対象外です。固定フォーク・C-BIOS MSX2+・NTSC構成での回帰検査です。

B0h（MSX-TIMERのレジスタ）への0x55の書き込み・読み戻しでI/O経路を確認します。タイマー割り込みで演奏しているわけではありません。

## 一括テスト

セットアップ済みのリポジトリ直下で実行します。Python 3が必要です。新しいlogsフォルダへ記録し、既存の記録は上書きしません。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\run-all.ps1
```

起動・全操作・ループ・音声・文字と影・ADPCMのRAM一致と単独発音・時刻検査・負例検査・公開一覧を検査します。個別実行は `scripts/launch.ps1 -TestScript tests/adpcm-solo.tcl -Work <新しい出力先>`、解析は `python tests/analyze-adpcm.py <出力先>` です。音声・画面についてもrun-all.ps1内にコマンドをまとめています。

収録前に実行ファイルを検査し、そのSHA-256を現物から記録します。時刻解析は記録したハッシュを期待値と、ROM・音楽データを現物と照合します。コミット番号は設定上の識別子であり、実行ファイルから抽出するものではありません。PCMの最初の発音を独立に検出し、命令時刻との差が5ms以内か検査します。完全無音に加え、周辺の音量の10%未満が20ms続く区間も検査します。

導入済みエミュレーターは管理一覧外の追加ファイルも拒否します。ただしreceipt.json自体を改ざんする攻撃の完全な検証ではありません。セットアップ失敗時は作成した一時展開先のみを削除し、診断ログは保存します。既存runtimeは変更しません。

## スプライトによるバー表示

8本の発音イベント表示は、16×16スプライトを上下2枚ずつ、合計16枚で描きます。同じ水平走査線では8枚です。高さ別の17パターンを起動時に準備し、更新時は上下のパターン番号2バイトを書き換えます。バーの消去・塗りつぶしは行いません。更新順序と減衰速度は維持し、1ループに1本ずつ更新します。

VRAMは0x7400〜0x74FFが色、0x7600〜0x7640が属性と終端、0x7800〜0x7A1Fが高さパターンです。可視画面の後方、ページ1の文字キャッシュ0x8000以降より手前に配置します。追加スプライトを同じ高さに重ねる場合は横8枚の制限に注意してください。

## 技術解説資料

日本語・英語とも各30ページです。

- 日本語: [PDF](technical/Y8960-TECH-DEMO-technical.ja.pdf)
- 英語: [PDF](technical/Y8960-TECH-DEMO-technical.en.pdf)

## 技術解説PDFのページ別参照先

各ページの説明を確認するための実装箇所です。関数名はリポジトリ内の検索に使用できます。

| ページ | 内容 | 実装・参照先 |
|---|---|---|
| 1 | 表紙・デモ画面 | `src/main.c`、[フォント出典](../third-party/fonts/README.ja.md) |
| 2 | Y8960 TECH DEMOの楽しみ方 | src/main.c; README.ja.md |
| 3 | 起動方法と動作環境 | scripts/common.ps1; config/versions.json |
| 4 | Y8960とは何か | README.ja.md; pinned fork doc/fork/README.md |
| 5 | 音源ごとの音の作り方 | src/main.c; scripts/generate-assets.py |
| 6 | PSGとSSGの関係 | Yamaha SSG manual; https://note.com/thara1129/n/n231074ae4be5 |
| 7 | OPLLとOPL2の違い | https://map.grauw.nl/resources/sound/yamaha_ym2413.pdf; https://www.ardent-tool.com/datasheets/Yamaha_YM3812.pdf |
| 8 | なぜ複数の音源を組み合わせるのか | src/main.c: play() |
| 9 | フォークの実装とデモの利用を分ける | fork doc/fork/README.md; src/main.c |
| 10 | 4セクションで音の役割を分ける | src/main.c: play(), cache_captions() |
| 11 | 楽譜の代わりに、音番号を並べる | scripts/generate-assets.py; src/main.c |
| 12 | 演奏のタイミングを描画から分ける | src/main.c: ticks(), main() |
| 13 | ROMを保ったまま音源I/Oを有効化 | src/main.c: enable_y8960(), audio_init(); fork RomY8960.cc |
| 14 | 音源ごとにアドレスとデータを送る | src/main.c: ssg(), fm(), opl() |
| 15 | SSGS：音程・音量・左右の掛け合い | src/main.c; fork Y8960SSGS.cc, Y8960SsgCore.cc |
| 16 | OPLL：2系統で旋律と和音を重ねる | src/main.c: note_fm(), play(); scripts/generate-assets.py |
| 17 | OPL2：FMベースの音色を作る | src/main.c: audio_init(), play(); scripts/generate-assets.py |
| 18 | ADPCM素材はPythonで合成する | scripts/generate-assets.py: encode(), percussion generation |
| 19 | ADPCMの符号化と共有RAM | tests/adpcm-solo.tcl; tests/analyze-adpcm.py |
| 20 | ADPCMを2系統から発音する | src/main.c: drum(); fork Y8960Adpcm.cc |
| 21 | SCREEN 5で文字に3色を使う | src/main.c: text(), blitrow(); scripts/generate-assets.py; font source |
| 22 | 描画コマンドと割り込みの整合 | src/main.c: idle(), copy_band(), draw_slice(), ready() |
| 23 | 描画を小分けにする具体的な順序 | src/main.c: draw_slice(), main(), rect(); 9/59.923 = approximately 150ms |
| 24 | ROM・RAM・VRAMを混同しない | src/main.c; scripts/build-demo.ps1; tests/*.tcl |
| 25 | 入力と停止は用途を分ける | src/main.c: keyrow(), quiet(), main(); tests/audio-controls.tcl |
| 26 | セットアップと配布ファイル | docs/publishing.ja.md; scripts/setup.ps1; config/versions.json |
| 27 | 再ビルドと、公開対象の検査 | scripts/build-demo.ps1; tests/validate-public.ps1; scripts/package.ps1 |
| 28 | 自動テストで確認していること | docs/timing-results.json; docs/results.json; tests/analyze-timing.py |
| 29 | 音の途切れを検出する方法 | tests/test-audio-timing.ps1; tests/test-timing-analyzer.py |
| 30 | 出典・謝辞と、再現対象 | github.com/madscient/openMSX_Y8960; third-party/fonts/README.ja.md |
