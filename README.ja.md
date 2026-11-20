# River Raid：現代の ZX Spectrum へ

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | 日本語

River Raid（Activision、Atari 8 ビット、1983、作者 Carol Shaw）を今日の ZX Spectrum マシンで：**ZX Spectrum Next** と **TS-Conf**（ZX Evolution / Pentevo）。どちらも [djdron/river_raid](https://github.com/djdron/river_raid) の C++ 移植をもとにしています。C++ 移植はオリジナルがすべてをどう行っているかを解き明かし、オリジナルとフレームごとに照合されています。ゲームのロジックはオリジナルどおり、フレームごとに同じで、同じ RAM の同じアドレスを使います。表示はそれぞれのマシンが自分のハードウェアで行います。

学習目的の非公式なファンプロジェクトで、Activision や Microsoft とは関係ありません。ゲーム自体は含まれていません。プログラムは実行時にあなた自身のカートリッジイメージを読み込みます。

## 移植

| | [ZX Spectrum Next](NEXT.ja.md) | [TS-Conf](tsconf/README.ja.md)（ZX Evolution / Pentevo） |
|---|---|---|
| ファイル | `river_raid.nex`（Browser で開く） | `river_raid.spg`（Wild Commander から起動） |
| ROM | `River_Raid.rom` を .nex と同じフォルダーに | `River_Raid.rom` を SD カードのどこにでも（FAT16/32） |
| 川 | Layer 2、岸の色はラインごとに Copper が設定 | 16 色モード、ハードウェアスクロール、岸の色はラインごとにフレーム割り込みが設定（色ごとにパレット 1 つ） |
| 敵、飛行機、ミサイル | スプライト | スプライト |
| パネル、スクロール文字 | タイルマップ | 川の下で切り替わる専用の画面、タイル、スプライト |
| サウンド | プログラムが POKEY をエミュレートして DAC へ（zxnDMA）、純音は AY | すべて General Sound で（カード自身の Z80 が POKEY をエミュレート、モノラル）。カードがなければ純音を TurboSound の AY で |
| CPU | 28 MHz（14 MHz でも間に合う） | 14 MHz（7 MHz でも間に合う） |
| テレビ方式 | PAL 50 Hz または NTSC 60 Hz（CAPS + 1） | PAL 50 Hz |
| 詳細 | [NEXT.ja.md](NEXT.ja.md) | [tsconf/README.ja.md](tsconf/README.ja.md) |

どちらでもゲームは完成しています：アトラクトモード、ゲーム 1-8（橋 1、5、20、50 から開始、1 人または 2 人交代）、飛行機、燃料と補給基地、敵、戦車、ヘリコプターのミサイル、橋、得点、残機、ハイスコア、ポーズ、パネル、虹色のロゴ付きのスクロール文字。実機ではまだ動かしていません。どちらもエミュレーター [Xpeccy+](https://github.com/dotkoval/xpeccy-plus)（その Next コアと TSConf コア）で照合しています。

## 入手方法

プログラムは push のたびに GitHub でビルドされます：[Actions](https://github.com/djdron/river_raid_zx/actions) のワークフロー `build`（.nex）または `tsconf`（.spg）のアーティファクト。自分の `River_Raid.rom` が必要です：カートリッジイメージ、8192 バイト、ヘッダーなし（C++ 移植が使うものと同じ）。ないとボーダーが赤くなります。

## 操作

| | キーボード | ジョイスティック |
|---|---|---|
| 飛行 | Q A O P | Kempston |
| 発射 | スペースまたは M | 発射 |
| START | Enter | （Next：メガドライブパッドの START） |
| SELECT（ゲーム 1-8） | G | （Next：メガドライブパッドの A） |
| ポーズ | H | |

Next にはさらにいくつかのキーがあります（PAL/NTSC、サウンド、CPU 速度、フレームの処理時間のボーダー表示）：[NEXT.ja.md](NEXT.ja.md)。

## 照合の方法

ゲームの動作を変えるものは、まず C++ 移植で行い、次に Next、次に TS-Conf 移植にある同じコードのコピーへ反映します。各移植には照合ツールがあり、プログラムをウィンドウなしで Xpeccy+ のコア上で動かし、同じ入力と同じ POKEY カウンターで C++ 移植を横で動かして、フレームごとに比較します：ゲームの状態、川のジェネレーター、パネル、そして画面をピクセル単位で（`make check`、`make -C tsconf check`。架空のプレイヤーが数十万フレームをプレイ）。Next のプログラムは、libatari800 上で動かしたオリジナルのカートリッジそのものとも比較しています（`make check-original`）。

## ビルド

```
make deps          # sjasmplus、C++ 移植、Xpeccy+ を deps/ へ（git、C/C++ コンパイラー、make、cmake、zlib が必要）
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

ビルドに必要なのは sjasmplus だけです。照合にはそれ以外のものと、`rom/River_Raid.rom` に置いたあなたの ROM が必要です。

## リポジトリ

| パス | 内容 |
|---|---|
| `src/`、`tools/`、`Makefile` | ZX Spectrum Next 用のプログラムとその照合（[NEXT.ja.md](NEXT.ja.md)） |
| `tsconf/` | TS-Conf 移植：独自のプロジェクトとビルド、ゲームのコードは `src/` からコピー（[tsconf/README.ja.md](tsconf/README.ja.md)） |
| [docs/HOW_IT_WORKS.ja.md](docs/HOW_IT_WORKS.ja.md) | Atari の画面、衝突、音が Next と TS-Conf でどう作られているか、誰にでもわかるように |
| [docs/NOTES.ja.md](docs/NOTES.ja.md) | Next のプログラムをどう作ったか、何がわかったか、数字付き |
| [tsconf/NOTES.ja.md](tsconf/NOTES.ja.md) | TS-Conf 移植独自のもの：ボード、割り込み、General Sound、起動、数字付き |
| [docs/CODE.md](docs/CODE.md) | Next のアセンブリソース、ルーチンごと（英語とロシア語） |
| [tsconf/CODE.md](tsconf/CODE.md) | TS-Conf のアセンブリソース、ルーチンごと、そして 2 つのマシンの違い（英語とロシア語） |
| [HANDOFF.ja.md](HANDOFF.ja.md) | 作業を引き継ぐためのプロジェクトの状態 |

## ライセンス

このプロジェクト自身のコードとドキュメントは MIT ライセンスです。[LICENSE](LICENSE) を参照してください。`src/palette.inc` と `tsconf/src/palette_ts.inc` は C++ 移植のパレットモデル（MIT）から生成しています。`src/font.inc` と `tsconf/src/font.inc` は AltirraOS のフォントです（Copyright (C) 2008-2018 Avery Lee。告知を残せば自由に複製・配布でき、ファイルはその告知を保持しています）。C++ 移植と同じく、Atari OS の ROM はカートリッジに含まれません。照合には [Xpeccy+](https://github.com/dotkoval/xpeccy-plus)（MIT）とアセンブラー [sjasmplus](https://github.com/z00m128/sjasmplus)（BSD-3）を使います。どちらも同梱しておらず、`make deps` が取得します。River Raid そのもの（ROM、そのコード、グラフィック、サウンド）は権利者に帰属し、このライセンスの対象ではありません。
