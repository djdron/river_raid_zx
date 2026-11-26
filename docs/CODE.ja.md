# ZX Spectrum Next 版のアセンブリソース、ファイルごとの解説

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | [Español](CODE.es.md) | [中文](CODE.zh.md) | 日本語

コードを読みたい、あるいは速くしたい Z80 プログラマ向けです。各ファイルについて、何が入っているか、各ルーチンが
何をし、誰がいつ呼び、どう動き、どれだけかかるかを書きます。なぜそうしたかは [NOTES.ja.md](NOTES.ja.md) と
[HANDOFF.ja.md](../HANDOFF.ja.md) に、平易な言葉での全体像は [HOW_IT_WORKS.ja.md](HOW_IT_WORKS.ja.md) にあります。

これは Next のコード（`src/`）です。TS-Conf 版（[tsconf/CODE.ja.md](../tsconf/CODE.ja.md)）はゲーム部分のコピーを
使います。`play.asm`、`game.asm`、`river_gen.asm`、`spans.asm`、`display*.asm` の各ファイル、`panel.asm`、
`sound_driver` はここで両方の分をまとめて説明します（TS-Conf でのわずかな変更はあちらに列挙）。ここにある残り、
つまり画面、スプライト、Copper、パネル、DAC での音、起動は Next 固有です。2 つのマシンの違いの表は
tsconf/CODE.ja.md の冒頭にあります。このコードが使う Next 固有のハードウェア：Z80N 命令（`nextreg`、`mul`、
`bsla`）、8K スロット、列単位の Layer 2、Copper、tilemap、拡大できるスプライト、zxnDMA と DAC、3 つの AY、
50 Hz と 60 Hz。

## 数値

時間は 28 MHz の Next コアでの 1 フレームあたりのサイクル数（平均）で、nxcheck のヒストグラム
（`NXHISTALL=ファイル`、次に `python3 tools/prof.py build/test.sym ファイル 60`、フレーム数で割る）から取りました。
ゲームと同じく画面メモリなしの検証ビルド（`-DNOSCREEN`、`NXNOSCREEN=1`）です。2 回の実行：

- **A**：PAL、bot 1、開始から 3 000 フレーム（いつものゲーム序盤）：平均で 1 フレーム約 93 000、最大約 149 000。
- **B**：橋 80 からの `-stress`、PAL、6 000 フレーム（`NXBRIDGE=80 NXGHOST=1 NXGAME=1`：全スロット使用、全速、撃ちっぱなし）：平均約 149 000、最大約 193 000（NTSC 約 145 000 / 約 186 000、14 MHz NTSC では約 240 000 のうち約 131 000 / 約 165 000）。

1 フレームは PAL で約 567 000 サイクル、NTSC で約 481 000（14 MHz ではその半分）。`apply`（とその中の
`panel_frame`）は計測される処理の後（スクロールテキストの下）で動き、この数値には入りません：1 フレーム約 7 400。
ルーチンの時間はそのルーチン自身の命令だけで、呼び出したルーチンはそれぞれの名前で数えます。

部分ごと（A / B）：

| 部分 | A | B |
|---|---|---|
| display：物体の配置と衝突（`display_simple`、`display_objs`、`display_hits`、`sp_*`） | 31 700 | 45 600 |
| 音（`pokey_frame`、`snd_*`、`pk_*`、`ay_*`、`sound_driver`） | 26 900 | 39 300 |
| 川の新しい行（`river_gen`、`render_line`、`rl_fill`、`span_line`、`push_line`） | 19 500 | 45 400 |
| スプライトと Copper リスト（`build_sprites`、`ob_*`、`pl_*`、`build_copper`） | 9 900 | 15 000 |
| ゲームロジックとその他（`prepare`、`main_loop`、`move_objects`、`random_step`、パネル表示など） | 9 400 | 10 500 |

最も重いルーチン（A / B）：

| ルーチン | A | B | ファイル |
|---|---|---|---|
| `pk_g4` | 0 | 1 400 （ミサイルが鳴るフレームでは約 9 000） | sound_pulses |
| `display`（自身のコード） | 11 500 | 13 400 | display_simple |
| `pk_noise` | 4 600 | 12 900 | sound_pulses |
| `span_line` | 4 200 | 10 300 | spans |
| `ds_edge_test` | 3 200 | 10 200 | display_simple |
| `render_line` | 4 100 | 10 000 | render |
| `snd_sum` | 8 600 | 8 600 | sound |
| `rl_fill` | 3 800 | 8 300 | spans |
| `ds_obj` | 5 300 | 6 100 | display_objs |
| `dh_pf` | 4 400 | 6 000 | dh_pf |
| `ob_list` | 4 100 | 5 600 | sprites |
| `ob_attr` | 2 900 | 5 200 | sprites |
| `move_objects` | 2 000 | 3 900 | game |
| `dl_fill` | 1 600 | 3 700 | river_gen |
| `ay_out` | 3 400 | 3 400 | sound_ay_run |
| `snd_fill` | 2 800 | 2 800 | sound |
| `ay_frame` | 2 200 | 2 800 | sound_ay_run |
| `pk_channel` | 1 200 | 2 700 | sound_pulses |
| `pokey_frame`（自身のコード） | 2 500 | 2 700 | sound |
| `draw_line` | 900 | 2 300 | river_gen |
| `dh_obj` | 1 400 | 1 800 | display_hits |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `hit_setup` | 500 | 700 | display_hits |

B で最も重いフレーム（約 193 000）：音が最大約 60 000（DAC 上のノイズとミサイル、約 180 パルス）、配置と
岸の判定（`display`、`ds_obj`、`ds_edge_test`）約 30 000、衝突（`dh_pf`、`dh_bits`、`dh_obj`、`hit_*`）約
25 000、川の新しい行約 25 000。

（`prof.py` はアドレスの下で最も近いグローバルラベルをルーチン名にするので、コード直前のデータラベルがその時間を
取ってしまうことがあります。ページ 12 の $6000-$7FFF のシンボルは、同じアドレスにあるページ 7 の `panel_init`
のもので、起動時に一度だけ動きます。）

## コード実行中のメモリ

8K スロット（$0000、$2000、… $E000）とその中のページ：

| スロット | アドレス | 通常 | 切り替える者 |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31：元のアドレスに置いた Atari の RAM | `pokey_frame`：サンプル生成中は 14–15、POKEY の 17 ビットカウンタ（`poly17.bin`） |
| 2 | $4000–$5FFF | 不定：固定ページなし | `render_line`：18–27（Layer 2、32 列ごとに 1 ページ）；`display`、`span_line`、`spans_clear`：28（`SPAN_PAGE`、各行のラン）；`panel_frame`：11（tilemap のマップ）；`panel_init`：10、11。`pokey_frame` とその呼び出し先：13（`SOUND_PAGE`、音のコード。`ay_quiet` のため `sound_init` も） |
| 3 | $6000–$7FFF | 12：バッファ（`copper_list`、`ds_objs`、`sprite_list`、`ov_exp2`/`ov_exp4`（1 バイトの点を広げたもの、`dh_obj` 用）、岸の隙間 `eg_*`（`ds_edge_test` 用）、$7C00 の DAC リング）。`dh_pf` は $7A00（`P12_CODE`、起動時にページ 7 からコピー：ページ 6 に空きがない） | 起動時のみ：7（`panel_init`、`sound_init7`、`load_rom`）。**音が鳴っている間は絶対に切り替えない**：DMA がこのスロットを通してリングを読む |
| 4 | $8000–$9FFF | 4：コード | — |
| 5 | $A000–$BFFF | 5：River_Raid.rom から読んだカートリッジ | — |
| 6 | $C000–$DFFF | 6：コード | — |
| 7 | $E000–$FFFF | 1：変数、テーブル（岸の隙間 `bg_*` を含む）、スタック（$0000 から下へ、$FF00 の上まで） | — |

ページ 4 は約 $9E2C（上限 $A000）、6 は約 $DD53（上限 $E000）、7 は約 $6913 で終わります（ビルドが表示します）。
DLI のタイムテーブルを消したことで少し空きができました。以前はページ間でコードを動かして空きを作っていました
（`display_objs.asm` はページ 4 のパレット整列前の隙間にありましたが、今はページの末尾です）。

割り込みは常に無効です（起動時の `di`）。フレームはラスタ行のポーリング（`wait_frame`）、音は DMA、行ごとの色は
Copper が受け持ちます。

## 1 フレーム

`main_frame`（river_raid.asm）、毎フレーム：

1. このフレームの画面に映るもの（`scroll`、岸の縁と水の色、プレイヤー）を記録、`read_input`、CAPS + 1（もう一方の方式で `restart`）。
2. 通常：`prepare` → `display` → `build_sprites` → `main_loop` → `vbi`。リセット中（`busy`、元のゲームがメモリを消すフレーム：NTSC 13、PAL 8）：`display` → `build_sprites` → `clear_layer2_page` →（最後のフレームで `finish_reset`）→ `vbi`。
3. `pokey_frame`：フレーム分のサンプルを DAC リングへ、AY の音程も。
4. `wait_frame`：現在のビデオ行（NR $1E/$1F）を `wait_line`（NTSC 208、PAL 220）になるまでポーリング。スクロールテキストの下で、画面上は何も変わらない場所です。
5. `apply`：作ったものをまとめて有効にする（Layer 2 のスクロールと色、スプライト属性、パネルのタイル、Copper リスト）。

T をオン（`tm_show`）にすると、各部分はまずボーダーの色を設定します（`TM_COLOUR`：T がオンのときだけ `tm_colour` を呼ぶ。オフならパートごとに約 30 クロック）：オレンジ `apply`、灰 `prepare`（リセット中は `clear_layer2_page` も）、赤 `display`、黄 `build_sprites`、青 `main_loop`、マゼンタ `push_line`（川の新しい 1 行、`main_loop` の中）、白 `vbi`、シアン `pokey_frame`、黒が残り時間。`push_line` はマゼンタにしてから青に戻します。

順序が大事です。`display` は前のフレームの `main_loop` が残した状態を使い（Atari の DLI が前フレームの状態を映すのと
同じ）、`build_sprites` は `display` が残したものを使います。

---

## river_raid.asm：フレーム、起動、メモリ

メインファイル：メモリ配置、`include`、ページごとのアセンブル（`mmu`/`org`）、ページ 1 の変数とページ 12 の
バッファ、テストビルド用のフック。

| ルーチン | 呼び出し | 何をどうする |
|---|---|---|
| `start` | ロード時 | `load_rom`（テストビルドでは無し）、R から RANDOM の種、28 MHz、ページのマップ、`init_tables`、`init_video`、`panel_init`（ページ 7 をマップ）、そして `restart`。 |
| `restart` | `start`；CAPS + 1 | `tv_pal` の方式でマシンを「電源オン」：`tv_setup`、Layer 2 のクリア（10 ページ一度に）、`sound_init`、`start_attract`、そのまま `main_frame` へ。 |
| `main_frame` | 毎フレーム | *1 フレーム* を参照。自身約 340 サイクル。 |
| `wait_frame` | `main_frame` | NR $1F を `wait_line` と比べながらビジーウェイト。時間は待ちであって仕事ではない。 |
| `init_tables` | `start` | 一度だけ：テーブル。`ring_lo`/`ring_hi`（画面メモリ 160 行の順序）、`span_class`（4 ピクセルが同じバイトの色）、`span_init`（マスク）、空の Copper リスト。 |
| `tv_setup` | `restart` | 方式ごとの設定：NR $05 50/60 Hz、`init_line_tables`、`wait_line`、ランダムの写像、Copper のパネル部分（`copper_panel_ntsc`/`_pal` をコピーし灰色 `COPPER_GREY` を埋め込む）、tilemap の最初の Y スクロール、クリップ窓（Layer 2 はパネル最後の灰色の行まで、スプライト、tilemap）。 |
| `init_video` | `start` | 黒いボーダー、ULA なし、グローバル透明色 $E3、Layer 2 320×256×8 をバンク 9 に、レイヤー順（tilemap がスプライトの上、スプライトが Layer 2 の上）、パレット：Layer 2 の 4 エントリ、スプライトの 128–255 = Atari の色、NR $15 でスプライトのクリップをボーダー上モードに。 |
| `test_ghost` | テストビルド、`test_ghost_on` のとき `display` の後 | nxcheck の NXGHOST：飛行機の衝突と燃料を設定して墜落しないようにする。 |

ほかに：`span_rec`（マクロ：HL = SPAN_PAGE 内の川の A 行目の 32 バイトレコード）、`palette`（Atari の色 → Next の色、
256 バイト）と `random_columns`、`TEST` 変数（`start_bridges_hi`、`snd_passed`、`test_ghost_on`）。

## play.asm：メインループ（A197–A6EA）

元のゲームがメインループで実行するゲームロジック。C++ 版と同じです。状態は元の RAM のアドレスに置きます。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `main_loop` | `main_frame`（リセット中は呼ばない） | A197–A6EA：RANDOM を読む（`random_read`）、飛行機（`fly_plane`）または爆発/復帰（`respawn_or_game_over`）、`drive_tank`、`move_objects`、そして `main_loop_end`。リセットが始まると早めに戻る。 | 620 / 620 |
| `main_loop_end` | `main_loop`、`finish_reset` | A5B7–A6EA：ミサイルと戦車の砲弾（`move_missile`、`move_shell`）、`scroll_river`、START/SELECT。 | 180 / 170 |
| `scroll_river` | `main_loop_end` | A6FD：速度を 1 フレームに 2 回、小数部に足す。繰り上がりごとに `push_line`（川の新しい 1 行：重い部分、river_gen を参照）。 | 140 / 160 |
| `fly_plane` | `main_loop` | A3E9–A5B4：燃料、操縦（`steer`）、速度（`change_speed`）、発射、弾（`move_bullet`）、衝突の結果：`explode`（撃った、または体当たりした物体：得点）、`crash`。 | 290 / 480 |
| `steer`、`change_speed` | `fly_plane` | ピクセル未満の小数を持つ飛行機の X、速度 $40–$FE。 | |
| `explode` | `fly_plane` | A4E0–A589：スロットが爆発に変わる、得点（BCD）、橋のボーナス。 | |
| `crash` | `fly_plane`、`explode` | sub $B1C0：飛行機が墜落、イベント音付き；`section_checkpoint`。 | |
| `draw_bullet`、`move_bullet` | `fly_plane`、`crash` | 弾の 8 行をミサイル 2 のメモリへ（`-DBEAM` のみ。それ以外は `draw_bullet` がすぐ戻る）。 | 380 / 520 |
| `new_game`、`reset` | START、ゲームオーバー、復帰 | sub $B0F1：川と物体をゼロに（`restore_checkpoint`）、`clear_screen_memory`（画面メモリがあるときのみ：検証ビルドとビームビルド）、`busy` = 13 または 8 フレーム。 | |
| `clear_layer2_page` | `busy` 中の `main_frame`、`restart` | 1 フレームに Layer 2 の 10 ページのうち 2 ページを消す（`l2_clear` で数える）。リセットの最初のフレームは消さない（`l2_wait`：その画面がまだ表示中）。その間 `apply` が川の行を隠す（`l2_hidden`）。A で平均 1 フレーム約 1 100 だが、動くフレームでは 1 ページ 8 KB の書き込み。 | 1 100 / 570 |
| `finish_reset`、`finish_respawn`、`respawn_or_game_over` | | リセット後：川はチェックポイントから続く、次のプレイヤーかゲームオーバー。 | |
| `swap_players`、`update_high_score`、`set_up_game`、`select_game` | | 2 人プレイ、チェックバイト付きのハイスコア、ゲーム番号。 | |
| `show_lives`、`show_score`、`show_bridges` など | ループ、VBI | パネルの文字を Atari の RAM（$1000）へ。 | 620 / 720 |
| `print_bcd` | 各 `show_*` | B086：BCD バイトを数字に、先頭のゼロは空白。 | 1 200 / 1 400 |
| `read_input` | `main_frame`（テストビルドでは無し） | キーボード（Q A O P、スペース/M、Enter、G、H、CAPS + 1/2）、Kempston 1 と 2、Mega Drive パッドを Atari のジョイスティック、トリガ、コンソールのバイトへ。T（押した時）で `tm_show` を切り替え、オフ時の代替色は黒。 | — |

## game.asm：フレームごとのゲーム部分と VBI

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `random_read` | `main_loop`（A205） | POKEY の RANDOM：読み出し時点の 17 ビットカウンタ。検証はこの読み出しを数える。 | |
| `random_step` | `vbi` | カウンタを 1 フレーム進める：固定の線形写像（`random.inc` の 17 列、NTSC か PAL）を 4 ビットずつ。ビット 0–15 の 4 つのニブルそれぞれについて `rnd_tab`（ページ 1、256 バイト境界：64 k + 4 v）の 3 バイトエントリを XOR、ビット 16 が立っていればその列（`rnd_col16`）も。以前は 1 ビットずつで約 2 300。 | 560 / 560 |
| `rnd_tables` | `tv_setup` の最後 | 方式の列（`rnd_cols`）から `rnd_tab` と `rnd_col16` を作る：各エントリはその値に対応する列の XOR。 | |
| `bank_colour` | `vbi`、`start_attract` | sub $AFD0：岸の色合い（上から橋が入ってくる間に変わる）。 | 200 / 200 |
| `start_attract` | `restart` | デモモードの最初の行での状態（ゲーム 1、飛行機なし）。 | |
| `draw_logo_and_needle` | `reset`、`start_attract` | 虹と燃料の針を player-missile メモリへ、sub $B0F1 が残す通りに（`-DBEAM` のみ。Next ではスプライト）。 | |
| `push_line` | `scroll_river`、`start_attract` | 川の新しい 1 行：`next_line`（river_gen）がその部品を `dl_seg` に記録し、`line_done` で `render_line`（Layer 2）と `span_line`（衝突用のラン）がそこから描く。画面メモリがあるとき（検証ビルドとビームビルド、`SCREEN_MEMORY`）は行のバイトを `line_buf` 経由で画面メモリにも書く（LDI 48 回、最上行のアドレスを 1 行上へ）。 | |
| `prepare` | `main_frame` | フレーム開始時の AE99–AF38：画面下へ出た戦車と砲弾、砲弾の色、パネルの残機、橋の数、得点。player-missile メモリ（$0B00–$0FFF）への形のコピーはサイクルモデルのビルド（`-DBEAM`）のみ。Next のスプライトと衝突は ROM から直接取る。 | 約 2 000（コピー込みで 3 000） |
| `drive_tank` | `main_loop` | A21B：道路上の戦車が進み、川の縁で撃つ。 | |
| `move_objects` | `main_loop` | A26C–A2ED：スロットの物体がアニメーションし移動する（船とヘリは岸で向きを変える：スロットの岸フラグは display から）。 | 2 000 / 3 700 |
| `move_missile`、`move_shell` | `main_loop_end` | ヘリのミサイル、戦車の砲弾。 | |
| `vbi` | `main_frame` | B2A5–B43E：`sound_driver`、フレームカウンタ、次フレームの色（`bank_colour`）、`scroller_step`、`random_step`。PAL ではゲーム終了時に sub $B21A 以前の値をいくつか見る（`vbi_before`）。 | 420 / 430 |
| `scroller_step` | `vbi`、`start_attract` | B44B：デモモードではスクロールテキストが 1 フレーム 1 カラークロック動き、ゲーム中は止まる。 | |

## river_gen.asm：川の生成器（A711–AE93）

元のゲームと同じく 1 行ずつ生成します：24 ビット LFSR、セクションとブロック、岸と島の幅、装飾（家、山）、道路と橋、
16 行ごとに置かれる物体。結果は `dl_seg` 内のその行の部品（各 4 バイト：開始バイト、種類、データ。0 は縁で
$B800 のテーブル内での部品のオフセット、1 は同じ値のバイトでその値、2 は装飾の 1 行でそのビットマップのアドレス。
バイト 48 で終わる）とスロットです。ゲームには行バッファがありません：`line_buf`（48 バイト、2 ビットのカラー
クロック 192 個。事前に消さず、部品がバイト 0 から 48 まで順に続く）は画面メモリがあるときだけ書きます。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `next_line` | `push_line` | 1 行：`count_lines`、`move_bank`、`change_island`、`scroll_objects`、`place_object`、そして `draw_line`。 | 210 / 290 |
| `count_lines` | `next_line` | A711：行を数える。ブロックとセクションの始まりで次に来るものを準備（`choose_section_width`、`start_decoration`、チェックポイント）。 | 160 / 210 |
| `move_bank`（+ `bank_hit_setup`、`bank_hits_left/right`） | `next_line` | A826：この行の岸の位置。まだ入ってくる途中の物体にぶつからないように。 | 350 / 570 |
| `change_island`、`choose_section_width` | | 島を目標の幅へ。 | |
| `draw_line` | `next_line` | 行の部品：岸の塗り（`dl_fill`、`dl_fill_bank`）、縁（`dl_edge`、`dl_bank_edge`：$B800 からの 2 バイトの部品）、装飾の 1 行（`dl_deco_row`、ビットマップのアドレスを進める）、水。それぞれデータとともに `dl_seg` へ、DRAW_POS を進める。バイトを `line_buf` に書くのは画面メモリがあるときだけ。 | 900 / 2 300 |
| `dl_fill` | `draw_line` | DRAW_POS から値 C のバイトを B 個：種類 1 の部品（バイトそのものは画面メモリがあるときだけ）。 | 500 / 1 300 |
| `scroll_objects` | `next_line` | AB76：すべてを 1 行下へ。最下段のスロットが画面から出るとスロットがずれる。 | 560 / 820 |
| `place_object`、`choose_enemy`、`position_object`、`place_tank` | `next_line` | 16 行ごとに次の空きスロットへ新しい物体。ブロックの始まりでは道路に戦車を置くことも。 | |
| `step_lfsr` | 多数 | sub $B183：24 ビット LFSR。 | 140 / 200 |
| `section_checkpoint`、`restore_checkpoint`、`start_game` | | 再開地点。新しいゲームは橋 1 から（テストビルドでは `start_bridges_hi`）。 | |

生成器のコストは新しい行ごとです。速度は 1 フレームに 2 回小数部に足され、繰り上がるたびに 1 行なので、1 フレーム
0–2 行、飛行機が速いほど多くなります。

## render.asm：Layer 2 への 1 行

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `render_line` | `line_done` | まず `line_bank`。ラインのカラークロック 20–179（`WINDOW_FIRST`）を Layer 2 の行 A へ、`dl_seg` の断片から（ラインバッファーなし）。Layer 2 は列ごとに格納（バイト x·256 + y、8K ページに 32 列）なので、行は列を下へ書く（`inc h` = 次の列）。10 ページを順にスロット 2 へ（`rl_next`）。1 つの値の断片：その色を `rl_k1` から取り、`rl_fill`（1 バイト 8 列、ページごと；`rl_fill`、`rl_next` は 6 ページの spans.asm）；縁のバイト（ROM の表から）と装飾の 1 行（ROM のビットマップから）：1 バイトごとにラインの点のテーブル一式（`rl_set`：どちらかの緑）が 1 クロック 2 ドットを出し、それぞれ 2 回書く；道路のライン（`.table_k`）では最初の緑のテーブルで、岸の点を道路の番号に（`rl_sub`）；ウィンドウより前のバイトはデータ上で飛ばす。1 ラインに 320 回の書き込み。6 ページにある（場所のため 4 ページから移動）。 | 4 100 + 3 800 / 10 000 + 8 300 |
| `line_bank` | `render_line` | TS-Conf と同じ（tsconf/CODE.ja.md）：C++ 移植の `lineBankColour`、変わりうるとき、つまり橋のところでだけ計算（`road_row`、`place_object`、`restore_checkpoint`、`scroll_objects` が管理）；新しい色で `rl_k1` + $55、`rl_sub`、`rl_set`（`pix_set0` か `pix_set1`）、種類 0/2 の断片のジャンプ（`render_line.kind`：`.table` か `.table_k`）を設定。番号は 1、そして 4–10。bank_colours.asm（6 ページ）。 | 50（橋の後：30） |
| `bank_init`、`pix_sets` | `start`（7 ページ、`panel_init` の後） | 岸の色を 1 回ずつ：$D2、$D6、道路の 20 行の色（`bank_cols`、`bank_n`、最大 8）、Layer 2 の 1 番、そして 4–10 番（`bank_set`）；2 つの緑の点のテーブル、各 4 ページ（`pix_set0` は 1 ページの $F700、`pix_set1` は 12 ページの $6C00、スロット 2 を通して書く）：ページ k のバイト b は Layer 2 での b の k 番目の点（0、2、3 はそのまま、1 は緑の番号）；`rl_k1`（$6B00）：断片の値 0、$AA、$FF の色（$55 は `line_bank` が設定）。 | 1 回 |
| `bank_set` | `bank_init`、`apply` | Layer 2 の岸の番号：その色（E = 1）か黒（E = 0、色がオフ：`show_bank` が変わったとき `apply` から、`ap_bank_on`）。 | |

## spans.asm：playfield との衝突に使う行ごとのラン

川の各行は SPAN_PAGE（ページ 28、$4000）に 32 バイトのレコードを持ち、256 行のリングになっています。そこには岸の
ラン（色 1）と縁のラン（色 2）が始まり終わるカラークロックが入ります。衝突ではスプライトの各行をピクセルではなく
これらのランと比べます。同じリング番号で、隙間もあります。`eg_e1`–`eg_s2` と `eg_e3`–`eg_s4`（ページ 12）は縁の
ランの間の水（ランが 2 本ならその間、4 本なら 1 本目と 2 本目、3 本目と 4 本目の間、0 本なら行全体、それ以外は
なし：$FF）。`bg_e1`–`bg_s2`、`bg_e3`–`bg_s4`（ページ 1）は岸のランの間の最も広い 2 つの隙間（最初のランの前の
クロック 32 から最後のランの後の 224 まで）。隙間の中に収まる箱は、その行では何にも触れません。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `span_line` | `line_done` | 新しい行のレコードを `dl_seg` の部品から作る。ピクセルは一切見ない：同じ値の部品は全体が 1 色（`span_class`）、装飾の 1 行は岸の色（C++ 版の bankRuns と同じく、装飾なしの行）、縁のランはその部品に応じて `edge_runs` から既成のものを取る（部品内のクロックとその色、バイト 48 で切る）。色が変わるたびにランを閉じる（`.change`）。次に隙間（縁のランからの `.gaps`、岸のランからの `.bgaps`：最も広い 2 つを残す、`.gap`）。 | 4 200 / 10 300 |
| `edge_runs_init` | `init_tables`（起動時） | 生成器が使う縁の部品（$B800 のテーブルのオフセット 0–30）それぞれを `edge_runs`（ページ 12、部品あたり 16 バイト）へ：その 2 バイトのピクセル 0–7 について、最初と色が変わるごとに（ピクセル、その色）の組を記録（3、つまり水は 0 として扱う）、その後は $FF。 | 一度 |
| `spans_clear` | `start_attract` | どの行にもランなし（画面メモリはクリア済み）。隙間は残す：ランがなければ隙間が何であれ何にも触れず、新しい行がそれぞれ作り直す。 | |
| `span_init` | `init_tables` | マスク：1 バイトのビット i..j（`span_masks`）。 | |

## display_simple.asm：置かれた物体とその衝突

C++ 版の `displayGeometry`（`dli_removed` ブランチ）と同じく DLI はありません。各物体はそのスロットの y にあり、
川の範囲で切り取られ、衝突は単純な幾何です。残すもの：`ds_objs`（スプライト用の各物体の行：8 バイト、最初の行、
行数、形と色のポインタ、x、サイズ）、HIT の衝突結果、
スロットの岸フラグ。

`display`（自身約 11 800 / 13 500）：

1. SPAN_PAGE をマップ、`dh_lists`（他のスプライトの記述子）、B527–B55C と同じくレジスタをクリアして設定、`bm_hitclr`、`dh_sprites`（HIT = $FF、次に他のスプライトと岸、スプライト同士）。
2. `.slot`、FIRST_SLOT からの各スロット：IY をスロットの見た目の種類へ（ページ 5：種類、X、サイズは IY + 11、+ 22、+ 33 にあり、その場で読みコピーしない）、Y とフラグを保持（`ds_y`、`ds_flags`）、`ds_edge_kind`。開始 = max(y, $5D)、最初の行 = y + height[type] − 開始（≥ $80：上に消えた、次へ）、X = 開始 + 3（255 を超えたら終わり）、行数 = min(行 + 1, 256 − X)、`ds_rowp` は最初の行のバイト、`ds_obj`（行を `ds_objs` へ）。橋なら `.road` (`-DBEAM`)（各行の後の走査線からの道路の色、X − 69 + 1。最後の行の後は X が一周していなければセクションの岸の色、`ds_bank` 経由。行の色は上の行と違うときだけ記録）。形と色の最初の行はその場で計算する（DE、BC を `ds_obj` へ）。ROM のテーブル（高さ、形、色）は 8 ビットの加算で読む（`ROM_SHAPES` と `ROM_COLOURS` はページの先頭から始まる）。
3. 種類 8–$0D について縁（P3PF）を判定（`ds_edge_kind`：ヘリ、気球、船はそこで向きを変える）：`ds_edge_test`、次に `ds_set_flags`。
4. 弾、戦車の砲弾（橋は除く）、飛行機との判定：`dh_obj`。当たるとスロットを記録（HIT_BULLET_OBJECT、HIT_SHELL_OBJECT、HIT_PLANE_OBJECT）するので、画面を下へ見て最後のものが残る。
5. `.end`：`test_ghost`（テストビルド）。`ds_bank_fill` は `-DBEAM` のみ。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `ds_edge_test` | `display`、種類 8–$0D の物体ごと | ある行の範囲（最初の点から最後の点まで）がその走査行の縁のランと重なれば A = $02（C++ 版の `edgeTouches`）。物体の箱（X から X + 8、16、32 クロック。クロック 255 を超える分は無視）を行ごとにその行の水の隙間（`eg_*`、行のリング番号を 1 ずつ進める）と比べ、隙間の中なら次の行。そうでなければ行の最初と最後の点（サイズで拡大した `edge_lo`/`edge_hi`：`.s1`/`.s2`、X を足して `.ex1`/`.ex2`）をその行の縁のラン（レコード）と比べる：間にランがあれば接触、点ごとの判定はしない。 | 3 200 / 10 200 |
| `ds_set_flags` | `display` | 物体の岸ビットをスロットのフラグ（ビット 0）へ。 | 1 100 / 1 300 |
| `ds_bank` | `display` (`-DBEAM`) | 走査線 A からの岸の色の変化（橋の道路とその戻り）：`ds_bank_ev` へ。 | |
| `ds_bank_fill` | `display` の最後、`-DBEAM` のみ | `ds_bank_ev` から川の各行の `scan_bank`（読むのはビームの display だけ。ゲームでは岸の色はラインごと：`line_bank`）。 | |
| `ds_edge_only` | `display` | 岸ビットはそれを読む種類だけ。 | |

## display_objs.asm

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `ds_obj` | `display`、行を持つ物体ごと | スプライト用の物体の行：最初の走査線、行数、最初の行の形と色のアドレス（DE、IY）、x、サイズ。`ds_objs` に 8 バイト（`DS_OBJS` = 最大 16）。最初の行が 28 行目かそれより上（川の上端より上）の物体は形全体に広げる（k = 開始 − y 行を追加）。スプライトを丸ごと描き、スプライトのクリップ窓で切るため。ページ 4 の末尾。 | 5 300 / 6 100 |

## display_hits.asm：幾何としての衝突

衝突レジスタもその読み出しもありません。スプライトの行のどこかで重なれば衝突です。他の 5 つのスプライトは
`dh_desc` の 10 バイトの記述子で表します（変わらない部分は起動時に `dh_template` から一度コピー、`dh_init`。残りは `dh_lists` が毎フレーム埋める）：行のベース（下位）、マスク（すでに点の位置へ回してある）、行の終わり（最後の行の次の行。255 を超えたら 255）、x、サイズ、スプライト番号、最初の行、行数、クロック幅、ベース（上位）（`DH_SIZE` = 10、
`DH_SHELL`、`DH_TANK`、`DH_PLANE`、`DH_MISSILE`、`DH_BULLET`）。L 行目の行はベース + L のバイトです：そのフレーム
の形は ROM から直接（ベース = アドレス − 最初の行、`dh_shape`、`dh_base`）。ミサイルと弾の行は `dh_ones`（すべて
1）にそれぞれのマスクをかけたもの。マスクはテンプレートの時点で点の位置へ回してある（$03 を 6 回して $C0、弾のビット 5 を 2 回して $80）ので、行を回すことはない。リセット後（`pm_empty`、次の `prepare` まで）は行なし。

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `dh_lists` | `display` の最初 | 記述子の行数、位置、ベース。そのあと各々の終わり（フィールド 2）。 | 1 300 / 1 300 |
| `dh_sprites` | `display` | HIT = $FF、次に以下で HIT 0：戦車が縁に（P1PF）、飛行機が岸に（P2PF）、ミサイルと弾が岸か縁に（M0PF、M2PF）：`dh_pf`。飛行機と戦車の砲弾（P2PL ビット 0）、ミサイルと飛行機（M0PL）：`dh_pair`。 | |
| `dh_pf` | `dh_sprites` | ページ 12 にある（`dh_pf.asm`、TS-Conf と同じ）。まずスプライトの全ラインで一度に箱を隙間と比べる（`DH_GAP`）：どのラインでも内側なら何もなし。そうでなければライン順に、行のバイトは DE から、マスクは命令に書き込み。NZ：スプライト IX の行が playfield に触れる（DE：`sp_edge`、`sp_bank`、`sp_under`）。川の行ごとに、まずマスクをかけた行のバイト（点がなければ次の行）、次にその箱（X から X + クロック数）がその行の隙間に入るか（A：ビット 0 は縁の `eg_*`、ビット 1 は岸の `bg_*`）。入れば何もなし。そうでなければ行の両端をランと比べる（`sp_*` 関数）。最初の接触で止まる。 | 4 400 / 6 000 |
| `sp_edge`、`sp_bank`、`sp_under` | `dh_pf` | スプライトの 1 行をその走査行の縁（茶）、岸（緑）、または両方のランと比べる。C++ 版の `spanTouches` と同じ：最初と最後の点（`sp_ends`：`edge_lo`、`edge_hi`、サイズの幅、X を足す）をラン（`sp_runs`）と比べ、間にランがあれば接触。行のレコードは `sp_rec` で取る。 | |
| `dh_pair` | `dh_sprites` | NZ：2 つのスプライトの行が重なる：そのクロックで `hit_setup`、次に両方が持つ各行で、それぞれのビット（`dh_bits`、サイズに応じて `hit_wide`）を `hit_a`、`hit_b` へ入れて `hit_line`。 | |
| `dh_bits`、`dh_end` | `dh_pf`、`dh_pair`、`dh_obj` | A 行目でのスプライト IX のビット：マスクをかけた行のバイト、すでに上位にある（Z：なし）。最後の行の次の行（`dh_lists` がフレームに一度フィールド 2 に入れる）。 | 400 / 500 |
| `dh_obj` | `display`、物体ごと（弾、砲弾、飛行機） | NZ：スプライト IX が現在の物体の行に触れる（`ds_rowp`、X = `ds_counter` の行から `ds_rows` 行、スロットの X とサイズ：IY + 22、+ 33）。まず両方が持つ行（`display` の `ds_l1`、`ds_l2` とスプライトの終わり。たいていの物体は共通の行を持たない）、次に物体（8、16、32）とスプライトのクロックで `hit_setup`。行ごとに物体の行のバイト（ゼロなら次）とスプライトのビットを、それぞれ広げて（`hit_wide`）`hit_line`。 | 4 900 / 6 100 |
| `hit_setup` | `dh_obj`、`dh_pair` | Z：2 つの箱のクロック（B から C 幅、D から E 幅）が重ならない。そうでなければ両方が playfield のクロック（32–223、最大幅 8）にある窓：それぞれの点のどこから始まるか（`hit_ka`/`hit_sa`、`hit_kb`/`hit_sb`：バイト、ビット）とそのクロックのビット（`hit_w`）。 | 500 / 700 |
| `hit_wide` | `dh_obj`、`dh_pair` | バイト A の点を 1 ビット 1 クロックで DE 以降へ（サイズ C：1 点 1、2、4 クロック、`init_tables` が作るテーブル `ov_exp2`、`ov_exp4` から）、最後にゼロ。 | |
| `hit_line` | `dh_obj`、`dh_pair` | NZ：`hit_a` と `hit_b` の点が窓の中で重なる：それぞれの開始から 2 バイトを `bsla de,b`（Z80N、8 サイクル）でシフトし、互いに AND して `hit_w` とも AND。 | |

## display.asm：playfield の判定（と古いビームモデル）

このファイルの大部分は DLI の完全でサイクル正確なモデル（`op`、`bm_events`、`bm_draw`、`rec_set`、`p3_scan`、
`bm_wsync`、ビームの `collide` 本体など）で、参考として残し、`-DBEAM` のときだけアセンブルします。常にアセンブル
されるもの：

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `pf_under`、`pf_bank`、`pf_edge`、`pf_none` | ビームの display（`-DBEAM`） | スプライトの行（D のビットをビット 7 から、位置 E、サイズ A：1 ビット 1、2、4 クロック）が `bm_line` 行で岸、縁、またはそのどちらかに点ごとに重なるか。行のレコードを探し（`pf_line`）、そのランを順にたどる（`pf_size`）。ゲームではもう使わない。 | |
| `pf_line` | `pf_bank`、`pf_edge` | HL = `bm_line` 行のレコード（キャリー：川の行）。 | |
| `pf_size`、`pf_v1`、`pf_v2`、`pf_v4` | `pf_*` | スプライトの下のラン：スプライトのクロックと重なるランを `span_masks` でビットと比べる（D：マスクのページ）。サイズごとの変種（N 回のシフトでクロックのオフセットをビット番号に）。 | |
| `collide`（`.add`、`.pair`、`.overlap`、`.entry`） | ビームの display（`-DBEAM`） | ある行のスプライトのリスト（ビット、位置、サイズ）と、そのうち 2 つの重なりの点ごとの判定。ゲームではもう使わない。 | |
| `bm_hitclr` | `display` | HITCLR：衝突ビットをクリア。 | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | 走査線ごとに：開始時の ANTIC のサイクル（`line_start`）と描画後に残るサイクル（`line_after_draw`）。今は `-DBEAM` モデルだけが読む。 | |

## sprites.asm：スプライト、Copper、`apply`、パネル

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`（物体）。飛行機、その弾、戦車、ヘリのミサイル、砲弾（`drawRiver` が描く順、最後が一番上）：それぞれ起動時に作ったそのフレームのパターン（`pl_plane`、`pl_tank`、`pl_shell`、`pl_bullet`、`pl_missile`）をその位置に、`pl_sprite`。`pl_keep` が属性を保存し、リセット中（`busy`）のフレームはそれを再表示（`pl_again`）。`build_copper`。 | 1 000 / 1 100 |
| `pl_sprite` | `build_sprites` | パターン A（$FF：なし）を D 行目（川より下ならなし）、位置 E、パレットオフセット C で：5 バイトの属性を `sprite_list` へ（X = 2·(x − 52)、9 ビット、Y、オフセット、パターン、4 ビット、ハーフパターン）。 | スプライトあたり約 100 |
| `ob_list` | `build_sprites` | `ds_objs` の各エントリについて `ds_objf` からの行（全部）：起動時に作った画像を最上行の形と色のアドレスで見つけ（`obj_lookup`、見つからなければ `ob_miss` で描かない）、16 行ごとに 1 スプライト（`ob_attr`：X = 2·(x − 52)、Y、バンク、4 ビット、ハーフパターン、2 倍幅・4 倍幅の拡大）、最初の行が川より下の部分には作らない。 | 5 700 / 6 400 |
| `build_copper` | `build_sprites` | 方式が変わったとき（`cp_built` が 0、`tv_setup`）か色がオフ／オンになったとき（`colour_bank` が 0 かどうか、`cp_bank_on` と比べて）だけ：パネルの灰色の後に戻す岸の番号（`CP_RESTORE`：その色、色がオフの間は黒）、次に `copper_start` とパネルの部分（`copper_panel`）をリストへ、最後の WAIT。`cp_full` = 1。bank_colours.asm。 | 100 / 100 |
| `apply` | `wait_frame` の後 | Layer 2 のスクロール（NR $17）、スプライト属性（ポート $57、1 スプライト OTIR 5 バイト、前フレームより多い分は隠す）、砲弾、戦車、飛行機の色（スプライトのパレット）、Layer 2 の色 0、2、3、そのクリップ窓（リセット後に Layer 2 を消している間は 2 フレーム目から：パネルの行だけ、`l2_hidden`、`l2_clip_y2` は `tv_setup` が決める窓の最後の行）、`panel_frame`、Copper：止めて、`cp_full` ならリスト全体、そうでなければスクロールテキストの X スクロールのバイトだけを送り、再開（モード %11）。長く操作がないと画面を消す（IDLE_TIME）。上の数値には入らない。 | — |
| `panel_frame` | `apply` | パネル：`panel_put` が列挙した位置だけ（`pf_dirty`、`start_attract` のコピーと `tv_setup` の後は全部）、それぞれ `.cells`（左半分のセル。行の最初の文字は右半分だけ）から、タイル 2·コード + 半分の 2 セルと、パレットオフセットとしての色ビット。スクロールテキスト（半分 h は 8h − X0、X0 = 16·TEXT_LO + 38 − 2·FINE_SCROLL）：マップ 26 行目のリング（半分 h は h mod 40 列目。前フレームから新しい半分だけを書く `.ring_write`、ジャンプ後は 40 全部）、X スクロール X0 mod 320（9 ビット：`CP_XSCROLL_HI_BACK`、`CP_XSCROLL_BACK`）。tilemap のクリップ窓を右で S = X0 & 7 点短く（一周する列）。スプライト 70（パターン 20、パレットオフセット 6）を X 320 − S に半分 h0 + 40 で（変わったとき 64 バイトを書く：`.spr_pattern`）。針とロゴのスプライト。 | スクロールテキスト約 1 700、パネル約 200、針とロゴ約 1 400 |

データ：`copper_start`（Layer 2 のパレットのインデックス 1、NR $4A があった所（T の色）は NOP、タイルマップの Y と X スクロール 0：その行は画面の行で、パネル外の行には何もない）、`copper_panel_ntsc`/`_pal`（7 ページの copper_panels.asm：`tv_setup` がスロット 2 を通して一方を `copper_panel` にコピー。同じ配置なのでオフセットはどちらにも使える：200 行目：パネルの最初の行のタイルマップ Y スクロール（`CP_PANEL_Y`、`tv_setup` が書き込む）、Layer 2 の色 0–10 を黒（`CP_COLOURS`：岸の番号も。パネルの下の行には古い川のラインが見えるため）、スプライトのウィンドウを 215 行目から下へ（`OBJ_LAST` + 1、どの物体の行よりも下。針とロゴはもっと下）；201：灰色（`COPPER_GREY`、`tv_setup` が書き込む）；パネルの行ごとのタイルマップ Y スクロール；230 行目（PAL では 240）：色 0–10 を戻す（`CP_RESTORE`：岸は `build_copper`、縁と水は `apply`、`CP_EDGE_BACK`）；スクロール文字の Y と X スクロール（`CP_XSCROLL_HI_BACK`、`CP_XSCROLL_BACK`）；`wait_line` で：スプライトのウィンドウを再び川のものに）。リスト全体を送らないとき、`apply` は縁から X スクロールまでのバイトを送る（`.cp_send`）。

## panel.asm（ページ 6）：パネルの文字

| ルーチン | 呼び出し | 何をどうする |
|---|---|---|
| `panel_put`、`panel_put_de` | パネルに書く者 | HL（DE）のパネルに 1 文字：既にそれなら何もしない。そうでなければ書いて位置を `pf_dirty` に記録（60 以上なら全部）。 |
| `print_bcd` | `show_score`、`show_other_score`、`show_high_score`、`show_bridges`、ゲームオーバー | HL の B バイトの BCD を DE に数字として、'0' = C、先頭のゼロは空白。デモモードでは何もしない。場所ごと（得点、ハイスコアまたは相手の得点、橋の数、相手の橋の数）に数字のベースと表示したバイトを保持し（`pb_cache`）、同じならすぐ戻る。 |
| `show_lives` | `prepare` など | 残機の記号。数が前回表示と同じなら何もしない（`sl_last`）。 |
| `pb_forget` | `start_attract` | 前回表示した数を忘れる（全部表示し直す）。 |

重なる場所は他の場所の記録を無効にします：相手の残機と橋の数、残機の場所に出るゲームオーバーの文字。

## sound.asm：サウンドドライバと POKEY のサンプル

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | B2A5–B3D8：元のドライバ。チャンネル 1 は発進のビープ、イベント音、燃料低下のビープかエンジン。2 は爆発かミサイル。3 は発射か 1UP。4 は戦車の砲弾。POKEY の AUDF/AUDC（`pokey_audf`、`pokey_audc`）を書く。 | 770 / 930 |
| `sound_init` | `restart` | DAC をオン（NR $08）、リングとチャンネルを無音に、`sound_init7`（ページ 7：AY、POKEY のテーブル、DMA の設定）、ページ 12 を戻してから DMA を有効に（$87）。 | |
| `pokey_frame` | `main_frame` | `ay_frame`（純音を AY へ。4 つともそちらなら：リングを一度無音にして `snd_idle`、終わり）、次にサンプル数：`wait_line` までの残り行（NR $1E/$1F）、DMA の位置（アドレスを読み直す）、先行は最大 `SND_LEAD`（760）、最小 `SND_MIN_LEAD`（200）、最大 `SND_CAP`（700）。次に：`snd_fill`（区間を 0 に）、AY に乗らない各チャンネル：音量 × フレームのゲイン（`snd_gain_set`：8、音量の合計が 31 を超えると 7–4、`mul d,e`）を一定レベル（音量のみ、または AUDF ≤ 4：半分）として、または `pk_channel`（反転を + と − としてリングへ）。次に `snd_sum`（累積和がレベルになる）。その間ページ 14–15 を $0000 に（17 ビットカウンタ）。 | 2 400 / 2 500 |
| `snd_gain_set` | `pokey_frame` | `snd_gain`：音量 1 段あたり 8、または DAC 上のチャンネルの音量合計が 31 を超えるときはレベルを 255 以下に保つ最大値（36 まで 7、42 まで 6、51 まで 5、それ以上 4）。 | 約 150 |
| `snd_fill` | `pokey_frame` | HL からリングへ値 A のバイトを DE 個（一周するときは 2 区間）、それぞれ末尾から PUSH で下向きに（SP を保存）。 | 2 800 / 2 400 |
| `snd_sum` | `pokey_frame` | DE 個のサンプルの累積和：`add a,(hl) / ld (hl),a / inc l` を 8 回展開し、余りの分は適切な位置から入る（自己書き換えの `jp`）、リング内をページごとに。約 270 サンプルで約 8 400 サイクル：1 サンプル約 31。 | 8 600 / 7 300 |
| `sound_random` | `sound_driver` | ノイズの音程用の RANDOM（検証が数える `random_read` ではない）。 | |

リング：$7C00 の 1024 バイト（ページ 12）、1K 境界、zxnDMA がバーストモード・プリスケーラ 55（15 909 Hz）で
ポート $DF へ送り、終わると再開。レベル 0–240。

## sound_pulses.asm、sound_handlers.asm：1 チャンネルの反転

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `pk_channel` | `pokey_frame`、AUDF ≥ 5 のチャンネルごと | 準備：音量の部分値（4 分の 0–3、サンプル内での反転用）、4 ビットと 5 ビットのカウンタの周期の歩み（`snd_mod15/31`）、周期をサンプル数とサイクル × 64 にしてループへ埋め込む。最初のパルス（`CH_D`、`CH_F`）。K = このフレームのパルス数（12 ビットの割り算、展開済み：tick は 4 × SND_CAP < 4096 未満）。次に種類ごとのループ。 | 1 200 / 2 800 |
| `pk_tone` | `pk_channel` | 音程：パルスごとに出力が反転。 | |
| `pk_noise` | `pk_channel` | ノイズ：パルスごとに 17 ビットカウンタの次のビット（ビットは並べて $0000 にマップ）。反転はサンプルの始まりで（+ か − の音量、2 サンプルに分けない）。 | 4 600 / 12 900 |
| `pk_g4` | `pk_channel` | 5 ビットカウンタで通過させる 4 ビットカウンタ（AUDC 010：ヘリのミサイル）：両カウンタを 1 つの数 m に（`g4_crt`：m = b + 31 ((e − b) mod 15)）、パルス m + s、各 m について `g4_tab`（$FF は通さない、それ以外はそのビット）。最後に m から両カウンタを戻す。反転はサンプルの始まりで。 | 0 / 1 400 |
| `pk_other` + `pk_handlers`（`adv31`、`adv15`） | `pk_channel` | その他の種類はハンドラで。 | |
| `pk_on`、`pk_off`、`pk_part*` | 各ループ | 音程やその他のパルスでの反転：そのサンプルには反転前の部分を引いた変化量、次のサンプルにはその部分（サンプル単位の反転によるうなりを避ける。ノイズとミサイルはサンプルの始まりで反転）。 | |
| `pk_done` | 各ループ | フレームの残り tick を `CH_D`、`CH_F` へ、出力を保存。 | |

## sound_ay.asm（ページ 7）、sound_ay_run.asm（ページ 13）：AY での純音

| ルーチン | 呼び出し | 何をどうする | A / B |
|---|---|---|---|
| `ay_init` | `sound_init7` | TurboSound をオン、1 つ目の AY をモノラル、音程のみ、無音。 | |
| `sound_init7` | `sound_init` | `ay_init`、ページ 1 の POKEY テーブル、`snd_mod15/31`、DMA の設定（有効化はしない）。 | |
| `ay_frame` | `pokey_frame` | 純音を鳴らす POKEY の各チャンネル（AUDC 101x か 111x、音量のみではない、音量 ≠ 0）について：専用の AY チャンネル（`ay_slot`：1 は 2 つ目の AY の A、2 は 3 つ目の A、3 は 1 つ目の B、4 は 1 つ目の C）、周期 N = (AUDF + 1) × 3.454（PAL）/ 3.422（NTSC）を `mul d,e` で、音量は `ay_vol` で、ミキサーの音程ビット。`ay_mask` で `pokey_frame` にそれらを飛ばさせる。このフレームのレジスタを `ay_q`（3 フレーム × 33：3 チップの 0–10、`ay_qi` で順番に）へ入れ、出力するのは 2 フレーム前のもの。 | 2 200 / 2 800 |
| `ay_out` | `ay_frame`、`ay_init`、`ay_quiet` | HL から 3 つの AY のレジスタ 0–10（最後に 1 つ目を選択、B = $FF）。 | 3 400 / 3 400 |
| `ay_quiet` | `pokey_frame`（音オフ）、`ay_init` | すべて無音（音量 0、ミキサー $3F）。 | |

`sound_ay_run.asm` がページ 7 ではなく 13（$4000）にあるのは、`pokey_frame` がページ 7 をリングの上にマップしないためです
（NOTES のクリック音を参照）。

## panel_init.asm（ページ 7、起動時）

| ルーチン | 呼び出し | 何をどうする |
|---|---|---|
| `panel_init` | `start`（ページ 7 を $6000 に） | ゲームが Atari の文字セットを作る場所にそれを作る（`font.inc` のシステムフォント、カートリッジの記号）。各文字を 2 タイルとして（タイル 0–127 はパネル用、128–255 はスクロールテキスト用）ページ 10–11 へ。tilemap のパレットとレジスタ（NR $6B/$6C/$6E/$6F、クリップ）、針とロゴのスプライトのパターン、`edge_lo`/`edge_hi`（各バイトで最初と最後に点いている点、縁の判定用）。 |
| `pl_pics` | `panel_init`、`obj_pics` の前（ページ 7） | 飛行機の 10 フレーム（14 行）、戦車の 8 フレーム（11 行）、砲弾の 7 フレーム（16 行）を ROM のポインタテーブルから、`prepare` が player-missile メモリへコピーする通りに：それぞれ 4 ビットのパターン（1 点：値 1 のピクセル 2 つ）、同じアドレスのフレームは共有、完全に空のものはなし（$FF）。弾（1 点の 8 行）とヘリのミサイル（4 点の 1 行）。パターンは 0 から（全部で 20）。 |
| `obj_pics` | `panel_init`（ページ 7） | 物体の画像：種類 7–15 について取りうる見た目の種類（自身のもの、`ROM_NEXT_KIND` の $0C 未満のもの、2 と 3 からの爆発のもの）、それぞれ鏡像も、height + 1 行。24 からの 4 ビットパターンとして 58 画像、点の値はその行の色がパレットバンク 14（種類 12、15）または 15（その他）の中で占める位置。`obj_lookup` 用の `obj_head`/`obj_e`。 |

## load_rom.asm（ページ 7）

| ルーチン | 呼び出し | 何をどうする |
|---|---|---|
| `load_rom` | `start`（テストビルドでは無し） | esxDOS でプログラムのフォルダにある River_Raid.rom を開き（F_OPEN、F_READ、F_CLOSE。長い名前が見えない環境では短い名前で）、その 8192 バイトを $A000（ページ 5）へ読む。なければ赤いボーダーで停止。実機の Next でのみ確認済み。 |

## インクルードファイル

- `vars.inc`：ゲーム変数の Atari の RAM アドレス（元の名前）。
- `palette.inc`：Atari のパレットを Next の色にしたもの（`tools/mkpalette` が作る）。
- `random.inc`：RANDOM の歩みの列（`tools/mkrandom`）。
- `font.inc`：システムフォント（`tools/mkfont`、AltirraOS のもの、注記付き）。
- `poly.inc`、`poly17.bin`：POKEY の 4、5、17 ビット系列（`tools/mkpoly`）。

## コードを変える前に知っておくこと

- **自己書き換えコード**はホットループでよく使います：即値とジャンプ先を埋め込む（`ds_edge_test` の `.bx1/.be1/.bx2/.be2/.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x`、`dh_pf` の `.mode/.x0a…/.x1d/.bits/.fn`、`snd_sum` の `.jp`、各 `pk_*` の `.pf/.pq`）。変種はバイト単位で確認すること（残っていた `add a,a` 1 つで音が倍になったことがある）。
- **展開されたコードへの入口**：`snd_sum` は余りのために `rept` ブロックの途中へジャンプします。
- **スロット 2** は作業用の窓です：ページが必要なルーチンは自分でマップし、元に戻しません。次の利用者が自分のページをマップします。**スロット 3** は音が鳴っている間ページ 12 のままでなければなりません。
- **テーブルはページ境界に揃えて**あり、`ld h,high table / ld l,index` で引けます：`span_masks`、`span_class`、`edge_lo/edge_hi`、`obj_head`、`ov_exp2`/`ov_exp4`、`eg_*`、`bg_*`、パレット。
- **検証**：変更のたびに `nxcheck` が毎フレーム C++ 版と状態と画面メモリ、行ごとの岸の色、描かれた物体、Copper のリストとメモリを比べ、最後に画像を比べます。全部で 2 コア約 25 分（HANDOFF.ja.md、*方法*）。アセンブルに失敗すると古いページが残るので、まずビルドの出力を見ること。
- **計測**：`NXHISTALL=ファイル`（全フレーム）または `NXHIST=ファイル`（1 フレーム）と `tools/prof.py`。`NXSLOW=T` は T サイクルを超えるフレームを列挙。`NXHISTAPPLY=ファイル` は `apply`（`wait_frame` の終わりから）について同じことをし、平均と最大を表示。`tools/prof_local.py build/test.sym ファイル フレーム数 [ルーチン…]` はローカルラベル（`ds_edge_test.row`、`panel_frame.mod` など）ごとにも時間を分けます。最も重いフレーム：`-stress` と `NXBRIDGE=80 NXGHOST=1 NXGAME=1`。
- **apply**（1 フレーム約 7 400、上の表には入らない）：スクロールテキスト約 1 700（うち X スクロール mod 320 の引き算が約 650）、針とロゴ約 1 400、パネル約 200（変わったものだけ）、スプライト属性約 1 800、Copper リスト約 1 200。
- **書き直し**は、毎フレーム新旧のやり方を並べて動かし違いを数えるテストビルドで確かめるのが速いです（衝突の行、配置、カーソルでそうした）。その後で古いほうを消します。
