# TS-Conf 版のアセンブリソース、ファイルごとの解説

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | [Español](CODE.es.md) | [中文](CODE.zh.md) | 日本語

TS-Conf 版のコードを読みたい、あるいは速くしたい Z80 プログラマ向けです。ゲームそのもの（ロジック、川の生成器、
物体の配置と衝突）は Next のコードを `src/` にコピーしたものです。それらのルーチンは
[docs/CODE.ja.md](../docs/CODE.ja.md) が説明し、この文書はどう変えたかだけを書きます。TS-Conf 固有の部分（画面、
行ごとの岸の色、スプライト、パネル、General Sound での音、SD カードからの起動）はここでルーチンごとにコスト付きで
説明します。概要は [README.ja.md](README.ja.md) にあります。

## 2 つのマシンの比較

同じゲーム、2 通りの見せ方。何が違い、コードのどこに現れるか：

| | ZX Spectrum Next | TS-Conf（ZX Evolution） |
|---|---|---|
| プロセッサ | Z80N 28 MHz（3.5 / 7 / 14 / 28）、割り込み無効：ラスタ行のポーリングでフレームを刻む | Z80 14 MHz（3.5 / 7 / 14）、キャッシュ有効。フレーム割り込み IM 2 をイベントからイベントへフレームの下方へ動かす |
| Z80N 命令 | `nextreg`、`mul`、`bsla de,b`、`outinb` など | なし：レジスタは `ld bc,ポート / out (c),a`。`bsla de,b` はループ（`shl_de_b`、display_hits.asm）。`mul` は不要（AY の周期は足し算で） |
| メモリ | 8K スロット（MMU、NR $50–$57） | 16K の窓（PAGE0–PAGE3）。窓 0 は書き込み可能な RAM（MEMCONFIG）なので Atari の RAM は $0000 に置ける |
| 川 | Layer 2、320×256、8 ビット、列単位：1 行は列を下る 320 回の書き込み、10 ページを順に | 16 色、320×240、画像の 1 行 256 バイト（1 バイト 2 点）：1 行は行に沿った 160 バイト、1 ページ |
| スクロール | NR $17、256 行のリング | GYOFFS、512 行のリング（`scroll` 9 ビット） |
| 行ごとの岸の色 | Copper：WAIT/MOVE のリスト、変わったとき送る | 岸の色ごとにパレット（PALSEL 0–7、CRAM）。フレーム割り込みが変化の 1 行前に PALSEL を設定（`build_events`、`irq`） |
| スプライト | 16×16 のパターン 128 個、4 または 8 ビット、拡大 ×2 ×4。1 物体は 16 行ごとに 1 スプライト | 512×512、4 ビットの画像メモリ 1 枚（SGPAGE）、64×64 までの任意サイズ、拡大なし：各画像を幅 16、32、64 点の 3 通りで保持。1 物体は 1 スプライト |
| 色 | NR $41 など、9 ビット | $E000 の FM 窓経由の CRAM（`CRAM_SHADOW`）：色と $E200 のスプライトリスト（SFILE）は普通のメモリ書き込み |
| パネルとスクロールテキスト | 最前面の tilemap、Y と X のスクロールは Copper から。スクロールテキストはタイルのリング + 継ぎ目の 1 スプライト | 独自の画像（256 色、ページ 64–79）を 184 行目からフレーム割り込みが切り替える（VPAGE、GYOFFS、GFXOVR 付きの VCONFIG）。文字は一度描いて DMA でコピー。スクロールテキストは 512 点上の 32 文字のリングで、割り込みが GXOFFS を設定。タイルレイヤー 0 が文字の下の灰色と川の上下の黒 |
| 音 | POKEY の音をリングへ、zxnDMA で DAC へ（メインプロセッサで `pokey_frame`、28 MHz で 1 フレーム約 26 000–39 000 サイクル）。純音は 3 つの AY で | General Sound 自身の Z80 が POKEY 全体を鳴らす（`gs/`）。メインプロセッサは 1 フレーム 8 バイトを送るだけ（ドライバ込みで約 3 400）。カードがなければ：純音を TurboSound の 2 つの AY で |
| カートリッジ | esxDOS：プログラムのフォルダから River_Raid.rom | SD と FAT16/FAT32 の自前コード：カード全体を探す（Wild Commander はフォルダを渡さない） |
| TV | 50 または 60 Hz（CAPS + 1） | 50 Hz のみ：ボードのフレーム |
| 画面の消去 | PUSH、1 フレーム Layer 2 の 2 ページ | DMA の塗りつぶし、1 フレーム画面の半分 |
| ツール | `nxcheck`（Next コア）、`NXHISTALL` + `tools/prof.py` | `tscheck`（TSConf コア）、`TSHISTALL` + `../tools/prof.py` |

## 数値

時間は 14 MHz（プロセッサのクロック）の TSConf コアでのサイクル数で、1 フレームは約 286 800。tscheck の
ヒストグラム（`TSHISTALL=ファイル`、次に `python3 ../tools/prof.py build/test.sym ファイル 60`、フレーム数で割る）
から、検証ビルド（`-DTEST`：ゲームにはない Atari の画面メモリ付き。`line_done` と `draw_line` はゲームより約
1 000–2 000 重い）で取りました。General Sound ありなので、ノイズはメインプロセッサに何のコストもかけません。
2 回の実行：

- **A**：bot 1、開始から 3 000 フレーム：処理は平均 1 フレーム約 74 000、最大約 124 000。
- **B**：橋 80 からの `-stress`、6 000 フレーム（`TSBRIDGE=80 TSGHOST=1 NXGAME=1 … -bot 1 -stress`：全スロット使用、全速、撃ちっぱなし）：平均約 116 000、最大約 153 000。

処理は `apply_done` から `frame_done` まで（フレーム割り込みを待つ時間は数えない）。下の部分には `apply` と割り込み
（約 7 000）も含みます。

部分ごと（A / B）：

| 部分 | A | B |
|---|---|---|
| display：物体の配置と衝突（`display`、`ds_*`、`dh_*`、`sp_*`、`hit_*`） | 42 900 | 57 300 |
| 川の新しい行（`river_gen`、`render_line`、`span_line`、`line_done`、`push_line`） | 14 400 | 33 800 |
| スプライトと岸のイベント（`build_sprites`、`ob_*`、`pl_*`、`obj_lookup`、`sfile_put`、`build_events`、`pal_get`） | 10 700 | 16 000 |
| `apply`、パネル、割り込み（`apply`、`panel_frame`、`panel_draw`、`pc_*`、`pal_edges`、`irq`、パネル表示） | 7 300 | 7 000 |
| 音（`sound_driver`、`snd_*`、`gs_*`。カードなしなら `ay_*`：A で約 5 800） | 3 400 | 3 500 |
| ゲームロジックとその他（`move_objects`、`main_loop`、`random_step`、`vbi` など） | 7 000 | 9 100 |

最も重いルーチン（A / B）：

| ルーチン | A | B | ファイル |
|---|---|---|---|
| `display`（自身のコード） | 11 000 | 12 600 | display_simple |
| `render_line` | 4 400 | 10 200 | render |
| `span_line` | 3 900 | 9 400 | spans |
| `ds_edge_test` | 2 800 | 8 800 | display_simple |
| `dh_pf` | 7 100 | 8 300 | display_hits |
| `ds_obj` | 5 500 | 6 400 | display_objs |
| `dh_obj` | 4 500 | 5 900 | display_hits |
| `ob_attr` | 2 500 | 5 200 | sprites |
| `dh_bits` | 3 700 | 3 900 | display_hits |
| `move_objects` | 1 700 | 3 300 | game |
| `dl_fill` | 1 500 | 3 300 | river_gen |
| `hit_setup` | 2 100 | 3 300 | display_hits |
| `ob_list` | 2 400 | 3 100 | sprites |
| `line_done`（画面メモリへのコピー、検証ビルドのみ） | 1 100 | 2 500 | river_raid |
| `sfile_put` | 1 600 | 2 400 | river_raid |
| `dh_lists` | 2 000 | 2 000 | display_hits |
| `pl_keep` | 800 | 1 600 | sprites |
| `panel_frame` | 1 600 | 1 600 | panel_ts |
| `irq` | 1 400 | 1 400 | river_raid |
| `gs_send` + `gs_wait_c` + `gs_wait_d` | 2 400 | 2 400 | sound_gs |
| `apply`（自身のコード） | 1 200 | 1 200 | river_raid |
| `pal_edges` | 1 100 | 1 100 | river_raid |
| `build_events` | 1 000 | 1 000 | river_raid |

7 MHz（`TSSPEED=1`、1 フレーム約 143 400 サイクル）でも処理は同じ命令です：`-stress` で平均約 96 000、最大約
143 000、ぎりぎり収まります。3.5 MHz では足りません。`gs_send` はカードが各バイトを読むのを待ちます（14 MHz で
1 バイト約 300 サイクル）。

（`prof.py` はアドレスの下で最も近いグローバルラベルをルーチン名にします。$4000 未満のアドレスは INIT_PAGE での
起動処理なので除外してください。）

## コード実行中のメモリ

16K の窓とその中のページ（ボードの 16K ページ）：

| 窓 | アドレス | 通常 | 切り替える者 |
|---|---|---|---|
| 0 | $0000–$3FFF | 1（`ATARI_PAGE`）：元のアドレスに置いた Atari の RAM | 起動時：3（`INIT_PAGE`：`sprite_pics.asm`、`gs_load.asm`、`load_rom.asm` がそこで動く） |
| 1 | $4000–$7FFF | 5（`WORK_PAGE`）：$4000 から各行のラン（`SPANS`、32 バイト × 256 行）、$6000 からバッファ（`scan_*`、`edge_runs`、`ring_*`、`ds_objs`、`ov_exp2/4`、`eg_*`、`bg_*`、`line_*`、`edge_lo/hi`、`rnd_tab`）、$7D00 にシステムフォント | `render_line`：川の画像の 1 ページ（32–47）。`panel_draw`/`pc_*`：パネルの画像（64–79）。起動時にタイルマップ（7）、タイル（8）、スプライトの画像（24–31）。必ず 5 に戻す |
| 2 | $8000–$BFFF | 2（`CODE_PAGE`）：約 $9F71 までコード、$A000 からカートリッジ | — |
| 3 | $C000–$FFFF | 6（`HIGH_PAGE`）：約 $D60E までコード、次に $E000 に FM 窓（`CRAM_SHADOW`：CRAM $E000–$E1FF、SFILE $E200–$E3FF。書き込みは下の RAM にも行く）、約 $FD47 までテーブルと変数、スタック、$FE00 に IM 2 のベクタ | — |

画像：川はページ 32 から（`VID_PAGE`、16 ページ：512 バイトの 512 行、各行 320 点を表示）、パネルはページ 64 から
（`VPANEL`）、タイルマップはページ 7、タイルの点はページ 8、スプライトの 512×512 点はページ 24–31（`SGPAGE`）。
INIT_PAGE のコードは約 $11E5 で、作業ページのバッファは $7C00 で終わります。FM 窓は常に開いているので、
$E000–$E3FF は他に使えず、$E400–$E4FF はそのレジスタです（`palette_lo` はそこにあり、読み出し専用）。

## 1 フレーム

`main_frame`（river_raid.asm）、毎フレーム：

1. このフレームの画面に映るもの（`scroll`、岸の縁と水の色、プレイヤー）を記録、`read_input`。
2. 通常：`prepare` → `display` → `build_sprites` → `build_events` → `main_loop` → `vbi` → `snd_frame`。リセット中（`busy`）：`display` → `build_sprites` → `build_events` → `clear_layer2_page` →（最後のフレームで `finish_reset`）→ `vbi` → `snd_frame`。
3. `wait_frame`：フレーム割り込み（`frame_flag`）が来るまで HALT。パネルの下の `FRAME_LINE` で来る。
4. `apply`：作ったものを有効にする（スクロール、音、色、SFILE、上端の岸のパレット、次のフレームの割り込みイベント）。
5. `panel_draw`：パネルで変わった文字とスクロールテキストの新しい文字を、その画像へ（`apply` の後：時間がかかることがあり、パネルは 184 行目からしか見えない）。

画面を描いている間、割り込みは `apply` が設定したリストのイベントごとに来ます：EV_PAL（次の行からの川のパレット）、
EV_PANEL（184 行目からのパネルの画像）、EV_GX（スクロールテキストの X）、最後にフレームのもの。どれも 1 行前の右端
（HSINT = 208）で来て、PALSEL、VPAGE、GYOFFS は行末で取り込まれるので、プロセッサの速度や処理の進み具合に関係なく
切り替えは正確です。

---

## Next のファイル、ここでの姿

`../src` からコピーした同じコード：

- `river_gen.asm`、`display_objs.asm`、`panel.asm`、`vars.inc`、`font.inc`、`random.inc`：変更なし。
- `display.asm`、`display_simple.asm`、`spans.asm`：SPANS のページはマップしない（`nextreg $52,SPAN_PAGE` を削除：窓 1 は常に SPANS を持つ）。`spans.asm` には `rl_fill`/`rl_next`（Next での `render_line` の補助）がない。
- `display_hits.asm`：`bsla de,b`（Z80N）を `shl_de_b` に、0–7 回の `sla e / rl d` のループ（`hit_line` 内：1 回の判定で最大約 100 サイクル増、1 フレーム数百）。
- `game.asm`：`tm_colour` は何もしない（まだボーダーに T はない）。`push_line` は `scroll` を 512 行のリングで動かし（9 ビット）、画像の `scroll + RIVER_TOP` 行目に描く。
- `play.asm`：`clear_layer2_page` は TS-Conf のもの（river_raid.asm、DMA）。`read_input` には CAPS + 1（60 Hz なし）、CAPS + 2（音オフ）、CAPS + 3（速度）、T、2 つ目の Kempston、Mega Drive パッドがない。
- `sound.asm`：`sound_driver` と `sound_random` のみ：`pokey_frame` は General Sound 上で動く（`gs/`）。
- `render.asm`、`sprites.asm`、`sound_ay.asm`、`load_rom.asm`、`river_raid.asm`：TS-Conf 独自のもの（下記）。同じ仕事をするところは Next の名前を使う。

最初の 3 グループのルーチンは [docs/CODE.ja.md](../docs/CODE.ja.md) が説明し、ここでのコストは上の表にあります。

## river_raid.asm：フレーム、起動、割り込み、色

メインファイル：ボードのポート、メモリ、ページ、`include`、フレーム、割り込み、`apply`、川のパレット、変数と
バッファ。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `start` | ロード時 | 14 MHz とキャッシュ（SYSCONFIG $06）、窓 0 を RAM に（MEMCONFIG $0E）、ページ、`screen_black`、`load_rom`（SPG ビルド）、`init_tables`、`init_video`、スプライトの画像（`obj_pics`、`pl_pics`、`panel_pics`）、`gs_load`、次に Atari の RAM を窓 0 に、`panel_init`、`ay_quiet`、RANDOM の種、IM 2（ベクタは $FE00）、`restart`。 | 一度 |
| `restart` | `start` | `tv_setup`、画面のクリア（両半分とも DMA で、完了を待つ）、フレーム割り込みを `FRAME_LINE` に、`start_attract`、パネル全体を描き、そのまま `main_frame` へ。 | 一度 |
| `main_frame` | 毎フレーム | *1 フレーム* を参照。 | 340 / 340 |
| `wait_frame` | `main_frame` | `frame_flag` まで HALT：待ちであって仕事ではない。 | — |
| `irq` | 割り込み | `ev_ptr` のイベント：EV_PAL は PALSEL。EV_PANEL は VPAGE = `VPANEL`、GYOFFS = 0、VCONFIG $8A（256 色、ビットマップをタイルとスプライトの上に）。EV_GX は GXOFFS。フレームのもの（EV_END）は `frame_flag`。同じ行のイベントはまとめて処理し、次のイベントの行（`vsint_set`）かフレームの行に VSINT を設定。 | 1 400 / 1 400 |
| `vsint_set` | `irq`、`apply`、`restart` | VSINT = HL（9 ビット）、`ev_line` に保持。 | 340 / 330 |
| `apply` | `wait_frame` の後 | GYOFFS = `show_scroll`、VPAGE は川のもの、VCONFIG $81（16 色）、GXOFFS 0。`snd_out`（AY のレジスタまたはカードへのフレーム）。`panel_frame`。砲弾と飛行機の色を CRAM へ。`sfile_put`。リセット後に画面を消している間（2 フレーム目から）：川を黒に（色 0 のパレット、縁と水も 0、パネルのイベントだけ）。そうでなければ PALSEL に上端のパレット（`ev_built`）、`pal_edges`、パネルのイベントを岸のイベントの後へコピー（`ev_tail`）。割り込みを最初のイベントに設定（前後で DI）。`ev_show` = いま設定したリスト（`build_events` はもう一方に書く）。 | 1 200 / 1 200 |
| `pal_get` | `build_events`、`apply` | Atari の色 E の川のパレット（PALSEL 0–7）：岸の色ごとに専用のパレットを持ち、初めて現れたとき作る（`pal_of`、`pal_n`）：その色 1 がその色、CRAM へ。8 を超えたら最後のものを再利用（起きたことはない）。 | 110 / 110 |
| `pal_edges` | `apply` | これまで作ったすべてのパレットの色 2 と 3（縁、水）。 | 1 100 / 1 100 |
| `sfile_put` | `apply` | SFILE（FM 窓経由で $E200）：川のスプライト（`spr_list`、S0）、終端エントリ（LEAP）、パネルの 3 つ（針とロゴ、S1）、終わり。その後ろから前フレームの終わり（`sf_end`）までのエントリはゼロに。1 スプライト 6 バイトを LDIR で。 | 1 600 / 2 400 |
| `build_events` | `main_frame` | 行ごとの岸の色。Next の `build_copper` と同じく `ds_bank_ev` から：割り込みが読まない方のバッファ（`ev_a`/`ev_b`）に、川の上端のパレット、次に変化ごとに EV_PAL イベント 5 バイト（種類、パレット、検証用の色、1 行前の VSINT 行）。`ev_tail` は apply がパネルの 2 つを置く場所。 | 1 000 / 1 000 |
| `clear_layer2_page` | `busy` 中の `main_frame`、`restart` | 1 フレームに川の画像の半分（256 行 × 160 バイト、4 ページ）を DMA の塗りつぶしで（DMACTRL $14、`dma_zero` から 80 ワード × 256 行）。リセットの最初のフレームは何もしない（`l2_wait`）。DMA が使用中なら何もしない。プロセッサは設定するだけ（約 150 サイクル）。 | |
| `dma_wait` | `restart`、`init_video` | DMA が空くまで（DMACTRL ビット 7）。 | |
| `init_tables` | `start` | Next と同じもの（`edge_runs_init`、`ov_exp2/4`、`ring_*`、`span_class`、`edge_lo/hi`、`span_init`）、`pix_tab` は番号を両方のニブルに（16 色モードの 1 バイト 2 点）。 | 一度 |
| `init_video` | `start` | 川のモード（VPAGE 32、VCONFIG $81、PALSEL 0）。タイルマップ（ページ 7：行 0–23 はタイル 1 の黒、184 はタイル 3 で灰色の上の黒い線、185–223 はタイル 2 の灰色、224–239 は黒。川の行はなし）とタイルの点（ページ 8）。スプライトの 128K を DMA でクリア。TSCONFIG $A0（タイルレイヤー 0 とスプライトをオン）。FM 窓を永久にオンにし、CRAM と SFILE をゼロに。戦車の色。HSINT、フレーム割り込みのみ（INTMASK 1）。 | 一度 |
| `screen_black` | `start` の最初 | TSCONFIG 0、BORDER 0、FM 窓経由で CRAM と SFILE の 1K 全部をゼロに：Wild Commander がどのモードを残していても黒に（ページ 5 にある ZX の画面がちょうど起動時のバッファの場所）。 | 一度 |
| `tv_setup` | `restart` | PAL のみ：`init_line_tables`、RANDOM の PAL 列、`rnd_tables`。 | |
| `test_ghost` | テストビルド | tscheck の TSGHOST、Next と同じ。 | |

`span_rec`（HL = SPANS 内のある行のレコード）は Next と同じマクロで、$4000 にあります。

## render.asm：画像への 1 行

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `render_line` | `line_done` | 行のカラークロック 20–179 を画像の HL 行目（0–511）へ：ページ `VID_PAGE` + 行 / 64 を窓 1 に、行は $4000 + (行 & 63) × 256。`dl_seg` の部品から Next と同じく：同じ値の部品は元の 1 バイトにつき `pix_tab` のバイトを 4 回（`.fill`：`ld (hl),a / inc l`）、縁のバイト（ROM のテーブル）と装飾の 1 行は `pix_tab` 経由でそれぞれ出力 4 バイト。1 行につき行に沿って 160 回の書き込み（Next は列を下って 320 回、10 ページ）。最後に WORK_PAGE に戻す。 | 4 400 / 10 200 |

## sprites.asm：川のスプライト

TS-Conf のスプライトは拡大できないので、各画像を幅 16、32、64 点で保持します（Atari の 1 ピクセルは 2 点、player は
サイズ ×1、×2、×4 で 8 ピクセル）。1 物体は最大 24 行の 1 スプライトです（Next は 16 行ごとに 1 つ）。パレット：
物体 14 と 15（`OBJ_PAL_A`、`OBJ_PAL_B`、行の色を位置 1–15 に）、砲弾とミサイル 8、戦車 9、飛行機と弾 10。エントリ
（各 6 バイト、SFILE の形式：YS と ACT 付きの Y、XS と鏡像ビット付きの X、タイルとパレット）を `spr_list` へ入れ、
`apply` がコピーします。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`。次に飛行機、その弾、戦車、ヘリのミサイル、砲弾（`drawRiver` が描く順）を `pl_pattern` + `pl_sprite` で。`pl_keep`。リセット中は `pl_again`。 | 800 / 800 |
| `ob_list` | `build_sprites` | 行を持つ（`ds_objf`）`ds_objs` の各エントリ：最上行の形と色のアドレスで `obj_lookup`。見つからなければスプライトなし、最初の行が川より下ならなし、それ以外は `ob_attr`。 | 2 400 / 3 100 |
| `obj_lookup` | `ob_list` | $B900 + E の形のバイトと $B700 + D の色のバイトから画像：`obj_head`（形のバイトから）、次に `obj_e` のチェーン。A = 画像 + `OBJ_PAL_B` ならビット 7。 | 1 000 / 1 300 |
| `ob_attr` | `ob_list` | SFILE のエントリ：Y = `RIVER_TOP` + 川の中での行の位置（9 ビット）、`pic_h` からの YS と ACT 付き。X = 2 × (位置 − 52)（9 ビット）、サイズに応じて XS 1、3、7。適切な幅のタイル（`pic_tn16/32/64_lo/hi`）、パレット。 | 2 500 / 5 200 |
| `pl_pattern`、`pl_sprite` | `build_sprites` | テーブルからそのフレームの画像（$FF：なし）。幅 16 点のスプライトを D 行目（川より下ならなし）、位置 E、パレット C で。 | スプライトあたり約 100 |
| `pl_keep`、`pl_again` | `build_sprites` | player のエントリを保存。リセットのフレームはそれを再表示（Next と同じ）。 | 800 / 1 600 |
| `cram_set` | 起動時、`init_video` | CRAM エントリ A × 16 + B = Atari の色 E（`palette_lo`）。 | |

## sprite_pics.asm（INIT_PAGE、起動時）：スプライトの画像

512×512 点の画像メモリ（SGPAGE、1 点 4 ビット、1 行 256 バイト）に窓 1 経由で。画像のタイルは 8×8 で、番号は
(行 / 8) × 64 + x / 8。

| ルーチン | 呼び出し | 何をどうする |
|---|---|---|
| `gfx_alloc` | `pic_set`、`pl_pics`、`panel_pics` | 幅 BC 点、高さ A 行（8 の倍数）の画像の置き場所：行の帯に沿って入る限り横へ、入らなければ下の行へ（`gfx_cx`、`gfx_cy`、`gfx_rh`）。 |
| `gfx_tile` | | 点のタイル番号。 |
| `gfx_row` | | 画像の C 行目：バイト D の点（ビット 7 から）を色 E で 3 通りの幅（1 ビット 2、4、8 点）、または最初のものだけ（B 1）。 |
| `obj_pics` | `start` | Next の `obj_pics` と同じ：種類 7–15 について取りうる見た目の種類（自身、`ROM_NEXT_KIND` の $0C 未満、爆発）、それぞれ鏡像も、DLI が描く通り height + 1 行。各画像は（アドレスで）一度だけ 3 通りの幅で。点の値はその行の色のパレット 14 または 15 での位置（新しいときに設定：`cram_set`）。`obj_lookup` 用の `obj_head`/`obj_e`。 |
| `pic_set` | `obj_pics` | 画像 `op_p` の 3 つのタイル（gfx_x、+ 16、+ 48）とその YS。 |
| `pl_pics` | `start` | 飛行機の 10 フレーム、戦車の 8、砲弾の 7（ROM のポインタテーブルから、`prepare` がコピーする通りに）、弾とヘリのミサイル：幅 16 点、色 1。アドレスごとに 1 画像、空のフレームは $FF。 |
| `panel_pics` | `start` | 針（ミサイル 1：2 カラークロック、10 行）とロゴ：64 点の player 3（データ $FC）、行ごとに 1 クロックずつ左へずれる player 2（データ $FF）（32 点に 7 行）。 |

## panel_ts.asm：パネルとスクロールテキスト

パネルは独自の画像（ページ 64–79、256 色、1 行 512 バイト）で、画面の 184 行目から（フレーム割り込みの EV_PANEL）
タイルとスプライトの上のビットマップ（GFXOVR）として表示します。値 0 の点は穴で、タイルレイヤー 0（灰色、黒）と
パネルのスプライトが透けて見えます。色 4–7 はパネルの PF0–PF3、8 はスクロールテキストの色。スクロールテキストは
画像の 512 点上の 32 文字のリングで、GXOFFS で見せます（最初の行の EV_GX）。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `panel_init` | `start` | ゲームが作る場所に Atari の 2 つの文字セットを RAM 上に作る（A0FB–A143：スクロールテキスト用は $0600、パネル用は $0800）。色（CRAM：文字の色をパレット 0 のエントリ 4–8 に、針の色、$B48D からのロゴの各行、タイルの黒と灰色をパレット 3 のエントリ 14 と 15 に。川のパレットはエントリ 0–3 しか使わない）。文字を一度描いておく（`GLYPHS`：スクロールテキスト用と、パネル用を 4 色で）ので `pc_put` はそれをコピーする。パネルの画像をクリア。すべてを最初のフレームで書くよう印を付ける。 | 一度 |
| `panel_frame` | `apply` | スクロールテキストの X（`pf_gx` = 16 TEXT_LO + 38 − 2 FINE_SCROLL、9 ビット）を割り込みの EV_GX 用に。針（ミサイル 1 を fuel / 8 + $5C に）とロゴの 2 つのスプライトを `spr_s1` へ（`.spr`）。 | 1 600 / 1 600 |
| `panel_draw` | `apply` の後 | `panel_put` が列挙した文字（`pf_dirty`、コピー後は 60 全部）を `panel_frame.char` で。スクロールテキスト：TEXT_LO が 1 進んだら 24 文字先の文字、ジャンプしたら 25 全部（`panel_frame.text`：文字 t はリングの 16 t mod 512 点目）。 | 160 / 160（+ `pc_*`） |
| `pc_put` | `.char`、`.text` | 一度描いた場所（`pc_bank`）から DMA で 1 文字をパネルの画像の E 行目、HL 点目へコピー。DMA が使用中（リセット時の消去）なら `pc_draw` で描く。 | |
| `pc_draw` | `pc_put`、`panel_init` | 1 文字の 8 行を描く：点いている点は色 B、それ以外は 0（穴）。0 点目より左の点は描かない。 | A で 700 |
| `pc_bank`、`pc_adr`、`pc_reg` | | グリフを描いた場所。行のページとアドレス。アドレスを DMA のレジスタへ。 | |

## sound.asm、sound_gs.asm、gs_load.asm と gs/：General Sound での音

Next の `pokey_frame`（サンプル、パルス、17 ビットカウンタ）はカード自身の 12 MHz の Z80 で動きます。メイン
プロセッサは 1 フレームに一度 POKEY のレジスタを送ります。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | 元のドライバ（Next と同じ）。 | 840 / 1 000 |
| `snd_frame` | `main_frame` | カードがあれば何もしない。なければ `ay_frame`。 | |
| `snd_out` | `apply` | カードがあれば `gs_send`、なければ `ay_out`。 | |
| `gs_send` | `snd_out` | ポート $BB にコマンド `GS_FRAME`（$A5）、次に AUDF1–4 と AUDC1–4 を $B3 へ。それぞれカードが前のものを読んでから（`gs_wait_c`：$BB のビット 0 がクリア、`gs_wait_d`：ビット 7）。タイムアウト（約 0.2 秒）でカードを諦め（`gs_on` 0）、以後は AY。時間の大半はカード待ち。 | 2 400 / 2 400 |
| `gs_load` | `start`（INIT_PAGE） | コマンド $F0（ファームウェアの状態）：応答がなければカードなし。`GS_READY`（$5A）なら前回の実行のプログラムが残っているのでそのまま使う。そうでなければファームウェア経由で：#12 でページ 2 を $8000 に、#18 でアドレス、#19/#1B でプログラムのバイト（`gs_prog`：incbin した `build/gs_pokey.bin`）、#13 で `GS_ORG`（$8400）へジャンプ、そして `GS_READY` を待つ（プログラムはまずテーブルを作る）。`gs_on` = 1。 | 一度 |

カード上のプログラム `gs/gs_pokey.asm`（別に `build/gs_pokey.bin` としてビルド）：

| ルーチン | 何をどうする |
|---|---|
| `gs_start` | IM 2（全ベクタを `INT_AT` $4141 へ、ハンドラをそこへコピー）、変数をゼロに、$6000–$63FF の各バイトを自身の値に（$6000 + 256 (n − 1) + v を読むと v が DAC n にラッチされる）、4 つの音量を 63 に。`poly_make`、`tables_make`、リングを無音に、`GS_READY` を出力。 |
| `main` | コマンドを待つ：$F4（`GS_RESET`）は DI、IM 1、JP 0（ファームウェアへ戻る）。$F0（`GS_STATE`）は `GS_READY` で応答。それ以外は 8 データバイトを `pokey_audf`/`pokey_audc` へ読んで `pokey_frame`。 |
| `gs_int` | カードの割り込み、毎秒 37 500 回：DDA（`DDA_STEP` 108/256）が毎秒 15 820 回リングから 1 サンプルを取り、4 つの DAC 全部にラッチ（$6000、$6100、$6200、$6300 + レベルから `ld a,(hl)`）：1 と 2 が左、3 と 4 が右、各側は 2 つの和。 |
| `poly_make` | POKEY の 17 ビットカウンタのビットを $C000–$FFFF（16K）へ。漸化式 q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) と初期値から作る。Next は `poly17.bin` から読む（カードのプログラムに 16K を入れる余地はない）。 |
| `tables_make` | `snd_tables`、`snd_mod15/31`、`g4_tab`（Next の `sound_init7` と同じ）。 |
| `pokey_frame`、`snd_fill`、`snd_sum` | Next のものから AY、zxnDMA、時間制限を除き、音量 1 段あたり 8 ではなく 4 に：ここでは 4 チャンネルすべてを扱い（Next では音程は AY が受け持つ）、最大 60 × 4 = 240。8 だと爆発が重なったとき 255 を超えた（シャーという音）、そして片側 2 つの DAC で同じ音量になる。さらに：割り込みの位置（`rp`）より先のサンプルを `SND_LEAD` まで、最大 `SND_CAP`、それより先は最後のレベルを保持（`SND_HOLD`）。 |
| `gs_pulses.asm`、`gs_handlers.asm` | Next の `sound_pulses.asm`、`sound_handlers.asm`：17 ビットカウンタのポインタは $C0 で一周（16K は $C000）、`mul` なし。 |

そのメモリ：$4000 ベクタ、$4141 ハンドラ、$4200 から変数、$4300 に `snd_tables`、$4400/$4500 に
`snd_mod15/31`、$4800 で終わる `g4_tab`、$6000 の下にスタック。ページ 2 を $8000 に：リング $8000–$83FF、$8400
からプログラム。$C000 に 17 ビットカウンタのビット。

## sound_ay.asm：カードなしの純音

| ルーチン | 呼び出し | 何をどうする | A |
|---|---|---|---|
| `ay_frame` | `snd_frame` | Next と同じ：純音を鳴らす POKEY のチャンネルをそれぞれ AY のチャンネルへ（1 は 2 つ目のチップの A、2 はその B、3 は 1 つ目の B、4 はその C）、N = (AUDF + 1) × 3.454 を足し算で（`3a + round(a × 116 / 256)`、`mul` なし）、音量は `ay_vol` で。`ay_regs` へ。2 フレームの遅れはなし：合わせる DAC がないので `apply` はこのフレームのものを出す。 | 1 100 |
| `ay_out` | `snd_out` | 2 つのチップのレジスタ 0–10（ポート $FFFD がチップとレジスタを選び、$BFFD が値）。 | 2 100（+ 600 `ay_clear`） |
| `ay_quiet` | `start` | すべて無音。 | |

## load_rom.asm（INIT_PAGE、SPG ビルド）：SD カードからカートリッジ

Wild Commander は .spg をフォルダも DOS もなしで起動するので、プログラムは Z-controller を通じて自分でカードを
読みます（ポート $77 のビット 1 が /CS、ポート $57 で双方向に 1 バイト）。セクタバッファは SPANS（起動後に作り直す）。

| ルーチン | 何をどうする |
|---|---|
| `load_rom` | `sd_init`、MBR の最初のパーティション（パーティションテーブルがなければカードそのもの：`lr_bpb`）、FAT ボリュームの値、ルートから `lr_search`。ファイルのクラスタを $A000 へ読む（8192 バイト）。なければ `lr_fail`：CRAM のエントリ 1 を赤、BORDER 1、そして停止。 |
| `sd_init`、`sd_cmd`、`sd_read` | SPI モード（CMD0、CMD8、CMD55 + ACMD41、CMD58：SDHC のブロックアドレス、そうでなければ CMD16 512 とバイトアドレス、`lr_hc`）、512 バイトの 1 セクタ。 |
| `lr_bpb` | ブートセクタ：FAT16 か FAT32、クラスタあたりのセクタ数、FAT、ルート、データのアドレス。 |
| `lr_search`、`lr_get`、`lr_advance`、`lr_rewind` | フォルダのエントリを順に（FAT16 の固定ルートかクラスタチェーン）。先にファイル、次にフォルダ、深さ優先で 8 階層まで（`lr_save`/`lr_restore` が経路を保存）。 |
| `lr_lfn`、`lr_name`、`lr_upper` | LFN エントリ（各 13 文字）から長い名前を組み立て、大文字小文字を区別せず RIVER_RAID.ROM と比べる。そうでなければ短い名前 RIVER_~1.ROM。 |
| `lr_next`、`lr_clus_lba` | FAT からのクラスタチェーン（16 または 32 ビット）。クラスタの最初のセクタ。 |

## インクルードとツール

- `palette_ts.inc`：Atari の色 → CRAM のワード（成分あたり 5 ビット、レベル 0–24）、C++ 版の PAL の色（`make palette`：`tools/mkpalette_ts`）。
- `vars.inc`、`font.inc`、`random.inc`：Next のもの。
- `gs/poly.inc`：POKEY の 4 ビットと 5 ビットの系列（`tools/mkpoly`）。
- `tools/mkspg.py`：ページ（`spg_page2/6/5/3.bin`）から SPG 1.0 ファイルを作る：$8000–$9FFF、$C000–$FFFF、フォント、INIT_PAGE のコード。
- `tools/tscheck.cpp`：Xpeccy+ の TSConf コア（とその General Sound）を C++ 版と並べて毎フレーム比較。

## コードを変える前に知っておくこと

- **共通のコード**：ゲームへの変更（ロジック、生成器、display、衝突）は、まず C++ 版、次に Next の `src/`、最後にここのコピーへ（`diff ../src/X.asm src/X.asm` は上に挙げた変更だけを示す）。TS-Conf での見せ方に関する変更はここに留まる。
- **窓 1** は、`render_line`、`panel_draw`、起動コードが別のページをマップしている間を除いて WORK_PAGE です。どれも WORK_PAGE に戻します（SPANS とバッファがそこにある）。
- **$E000 の FM 窓**は常に開いています：$E000–$E3FF への書き込みは CRAM と SFILE へ行く（下の RAM にも行き、`apply` はそれで読み返す）。そこに他のものを置かないこと。
- **割り込みのイベント**は 2 つのバッファ（`ev_a`、`ev_b`）にあります：`build_events` は `ev_show` が指していない方に書き、`apply` が DI の下でそれを有効にする。
- **行末で取り込まれるレジスタ**（PALSEL、VPAGE、GYOFFS、GXOFFS）は、1 行前の割り込みで設定すること。割り込みは HSINT 208（右端）で来るので、3.5–14 MHz で時間は足ります。
- **DMA** は画面の消去（`clear_layer2_page`）とパネルの文字（`pc_put`）が共有します：DMA が使用中なら `pc_put` はプロセッサで描く。
- **検証**：`make check`（3 000 フレーム、`FRAMES=`）、さらに bot、`-stress`、TSBRIDGE、TSSPEED=1（7 MHz）、TSGS=neo または 0 で、[README.ja.md](README.ja.md) の通り。変更のたびに毎フレーム：状態、行ごとの岸の色（`ev_built`）、General Sound のレジスタ、マシンの画像をピクセル単位で。
- **計測**：`TSHISTALL=ファイル`（実行全体の各命令の時間、起動、割り込み、待ちを含む）、次に `python3 ../tools/prof.py build/test.sym ファイル 60`。処理の平均と最大は tscheck の最後の行にあります。`TSTIME=N` はフレーム N−2..N+2 の処理を表示。`TSVOL=1`：フレームごとの POKEY の音量の合計とカードの最高レベル（255 以下でなければならない）。
