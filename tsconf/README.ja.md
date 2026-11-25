# River Raid：TS-Conf 移植

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | 日本語

TS-Conf（ZX Evolution / Pentevo）への移植：ZX Spectrum Next 版とは別の、独自のビルドを持つ独立したプロジェクトです（[NEXT.ja.md](../NEXT.ja.md)。両方について：[メインページ](../README.ja.md)）。共有しているのは `../deps` だけです（sjasmplus、C++ 移植、Xpeccy+：ルートで `make deps`）。

ゲームは Next と同じように動き（同じゲームロジック、display、川のジェネレーターを `src/` にコピー）、表示は TS-Conf のやり方で行います。50 Hz（PAL）のみ：ボードのフレームです。

両方のマシンでどう動いているか（誰にでもわかるように）：[../docs/HOW_IT_WORKS.ja.md](../docs/HOW_IT_WORKS.ja.md)。

このボードでどう作ったか、何がわかったか、数字付き：[NOTES.ja.md](NOTES.ja.md)。

ルーチンごとのソース、Next と共有するコードへの変更、2 つのマシンの違いの表：[CODE.ja.md](CODE.ja.md)。

- 川：16 色モード、320x240、画面の 1 ラインは 256 バイト（先頭 160 バイト）、512 ラインのリングをハードウェアでスクロール（GYOFFS）。川の新しいラインはその行に直接書き込み（`render.asm`）、コピーはしません。
- ラインごとの岸の色：1 つのパレット（PALSEL 0）が岸の色、つまり 2 つの緑と橋のそばの道路の色を持ちます（1 番と 9-15 番、起動時に一度だけ設定）。2 と 3 は縁と水です。新しいラインの岸の点はその色の番号で描くので（`line_bank`、計算は橋のところだけ。ラインごとに切り替えるものはない）、色はラインと一緒に動きます：変化ごとの割り込みも、画像の表示中に設定することもありません。
- 物体、飛行機、弾、戦車、ミサイル：スプライト（`sprites.asm`）。画像は起動時にカートリッジの形状から作り、物体ごとに 16、32、64 ドット幅の 3 種類を用意します（スプライトには拡大がありません）。
- パネルとスクロール文字（`panel_ts.asm`）：184-239 行目は専用の画面から来ます。フレーム割り込みが 184 行目でそれを切り替え（VPAGE、GYOFFS）、256 色モードでビットマップをタイルとスプライトの上に置きます（GFXOVR）。タイルレイヤー 0 は文字の下の灰色です（そこでは川のスプライトも隠します）。燃料計の針とロゴはその上のスプライトです。文字は起動時に一度描き、DMA でコピーします。スクロール文字は画面の 512 ドットにわたる 32 文字のリングで、GXOFFS で表示します。
- タイルレイヤー 0 は川の上の黒でもあります。
- 操作：Q A O P、スペースまたは M で発射、Enter で START、G で SELECT、H でポーズ、T でフレームの処理をボーダーに表示（部分ごとの色、Next と同じ）、CAPS + 3 で CPU の速さ：14、7、3.5 MHz を順に。Kempston。
- サウンド：General Sound（オリジナルのカードまたは NeoGS）があれば、すべてそれで鳴らします。カード自身の Z80 が Next の DAC と同じように POKEY を鳴らします（`gs/`：Next の `pokey_frame` とそのパルス。17 ビットカウンターのビットはカードがその漸化式から自分で作ります）。モノラル（同じサンプルを 4 つのチャンネルすべてへ：1 と 2 が左、3 と 4 が右）、毎秒 15 820 サンプル（カードの割り込みは毎秒 37 500 回で、256 回中 108 回でサンプルを取ります）。起動時にファームウェア経由でプログラムをカードに入れ（`gs_load.asm`。もう一度起動すると、プログラムがまだそこにあるのを見つけます）、その後 apply が毎フレーム POKEY のレジスターを送ります（`sound_gs.asm`）。カードがない（または応答しない）場合：純音だけ（エンジン、ビープ音、発射、ボーナス、砲弾の笛の音）を TurboSound の 2 つの AY で、Next と同じように鳴らします（`sound_ay.asm`）：POKEY のチャンネル 1 と 2 は 2 つ目のチップの A と B、3 と 4 は 1 つ目のチップの B と C。Xpeccy では General Sound をオンにしてください（AY には TurboSound NedoPC も）。

14 MHz では、1 フレームの処理はアトラクトモードで平均約 64 000 クロック、橋 80 から全速で撃ち続けると（-stress）約 106 000、最大約 167 000 で、1 フレームは約 287 000 です。7 MHz でもぎりぎり間に合います（-stress で最大約 122 000、1 フレーム約 143 400。遅れるフレームはなし）。3.5 MHz では間に合いません。

メモリー（16K ウィンドウ）：$0000 は Atari の RAM（ページ 1。起動中は起動処理のあるページ 3）、$4000 はラインのランとバッファー、$7D00 から OS フォント（ページ 5。`render_line` は描画中ここに画面のページを置きます）、$8000 はプログラムと $A000 からのカートリッジ（ページ 2）、$C000 はプログラム、バッファー、スタック（ページ 6）。川の画面はページ 32 から、パネルの画面はページ 64 から、タイルマップはページ 7、タイルのドットはページ 8、スプライトのドットはページ 24 から。

    make          build/river_raid.spg：Wild Commander 用のプログラム（SPG 1.0）。River_Raid.rom は
                  自分で SD カード上から探します（下記）
    make sna      build/river_raid.sna：あなたの ROM を入れた 128K スナップショット（../rom/River_Raid.rom）
    make check    テストビルドを Xpeccy+ の TSConf コアで動かし、C++ 移植とフレームごとに比較：
                  状態と毎フレームの画面（FRAMES=... フレーム数、既定は 3000）。General Sound
                  （Xpeccy+ のもの、ファームウェア gs105b.rom）があれば、カードが受け取るレジスターも
    make palette  src/palette_ts.inc を作り直す（C++ 移植の色をボードのレベルで）

`build/tools/tscheck` は自分でプレイもできます：`-bot N`（nxcheck の架空のプレイヤー）、`-stress`、`-start N`。TSBRIDGE、TSGHOST、NXGAME は nxcheck と同じ。TSSPEED=1 で 7 MHz。TSBORDER=1 で T をオン（TSFULL=1 と TSSHOT=k：ボーダー付きのフレーム）。TSGS=neo で NeoGS、TSGS=0 でカードなし（AY の純音を照合）。TSWAV=ファイル、TSWAVCPP=ファイル：カードのサンプルと、同じレートの C++ 移植の POKEY（聴くための WAV）。

.spg は GitHub でもビルドされます（ワークフロー `tsconf` のアーティファクト）。River_Raid.rom（カートリッジイメージ、8192 バイト）を SD カードのどこかに置いてください。プログラムは起動時にカードを探します（`load_rom.asm`：最初のパーティションまたはカード全体、FAT16 または FAT32、まずルート、次にそのフォルダー、8 階層まで。長い名前は大文字小文字を問わず、または短い名前 RIVER_~1.ROM）。見つからなければボーダーが赤くなります。起動処理の間、画面は黒です（`screen_black`：Wild Commander がどのモードを残していても CRAM 全体を一度に黒にします。その ZX 画面はページ 5 にあり、ちょうど起動処理がバッファーを書く場所です）。

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd フォルダー` はホストのフォルダーを SD カードとして .spg を動かします（`-img ファイル`：カードのイメージ）。`-sna build/river_raid.sna 600 out.ppm` はスナップショットを動かします。
