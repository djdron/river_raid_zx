# ZX Spectrum Next 移植版的汇编源码，逐个文件说明

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | [Español](CODE.es.md) | 中文 | [日本語](CODE.ja.md)

写给想读懂这份代码或让它更快的 Z80 程序员。每个文件：里面有什么，每个例程做什么、由谁在何时调用、
怎样工作、花多少时间。为什么这样做见 [NOTES.zh.md](NOTES.zh.md) 和 [HANDOFF.zh.md](../HANDOFF.zh.md)；
用浅白的话讲的总体图景见 [HOW_IT_WORKS.zh.md](HOW_IT_WORKS.zh.md)。

这里是 Next 的代码（`src/`）。TS-Conf 移植版（[tsconf/CODE.zh.md](../tsconf/CODE.zh.md)）使用其游戏部分
的一份拷贝：`play.asm`、`game.asm`、`river_gen.asm`、`spans.asm`、`display*.asm` 各文件、`panel.asm`
以及 `sound_driver` 在这里为两者一并描述（TS-Conf 的少量改动列在那边）；这里其余的部分——画面、精灵、
Copper、面板、DAC 上的声音、启动——是 Next 独有的。两台机器的差异表在 tsconf/CODE.zh.md 的开头。
本代码用到的 Next 专有硬件：Z80N 指令（`nextreg`、`mul`、`bsla`）、8K 槽、按列存放的 Layer 2、
Copper、tilemap、可缩放的精灵、zxnDMA 和 DAC、三个 AY、50 和 60 Hz。

## 数字

时间是 Next 核心在 28 MHz 下每帧的周期数（平均值），取自 nxcheck 的直方图（`NXHISTALL=文件`，然后
`python3 tools/prof.py build/test.sym 文件 60`，再除以帧数），用的是不带屏幕内存的校验构建，与游戏
本身一致（`-DNOSCREEN`、`NXNOSCREEN=1`）。两次运行：

- **A**：PAL，bot 1，从开始起 3 000 帧（通常的开局）：平均每帧约 106 000，最多约 162 000；
- **B**：从第 80 座桥开始的 `-stress`，PAL，6 000 帧（`NXBRIDGE=80 NXGHOST=1 NXGAME=1`：所有槽位都被占用、全速、一直开火）：平均约 164 000，最多约 202 000（NTSC 约 160 000 / 约 202 000；14 MHz NTSC 约 131 000 / 约 165 000，满额约 240 000）。

一帧在 PAL 下约有 567 000 个周期，NTSC 下约 481 000（14 MHz 时减半）。`apply`（以及其中的
`panel_frame`）在被测量的工作之后运行（在滚动字幕下方），不计入这些数字：每帧约 7 400。一个例程的时间
只算它自己的指令：它调用的例程记在各自的名字下。

按部分（A / B）：

| 部分 | A | B |
|---|---|---|
| display：物体摆放与碰撞（`display_simple`、`display_objs`、`display_hits`、`sp_*`） | 41 300 | 55 200 |
| 声音（`pokey_frame`、`snd_*`、`pk_*`、`ay_*`、`sound_driver`） | 26 900 | 39 300 |
| 河流的新行（`river_gen`、`render_line`、`rl_fill`、`span_line`、`push_line`） | 18 800 | 44 000 |
| 精灵和 Copper 列表（`build_sprites`、`ob_*`、`pl_*`、`build_copper`） | 10 900 | 15 900 |
| 游戏逻辑及其他（`prepare`、`main_loop`、`move_objects`、`random_step`、面板打印……） | 9 400 | 10 500 |

最耗时的例程（A / B）：

| 例程 | A | B | 文件 |
|---|---|---|---|
| `display`（自身代码） | 11 800 | 13 500 | display_simple |
| `pk_noise` | 4 600 | 12 900 | sound_pulses |
| `dh_pf` | 10 200 | 11 200 | display_hits |
| `span_line` | 4 200 | 10 300 | spans |
| `ds_edge_test` | 3 200 | 10 200 | display_simple |
| `render_line` | 3 900 | 9 400 | render |
| `snd_sum` | 8 600 | 8 600 | sound |
| `rl_fill` | 3 800 | 8 300 | spans |
| `ds_obj` | 5 300 | 6 100 | display_objs |
| `dh_obj` | 4 900 | 6 100 | display_hits |
| `ob_list` | 4 100 | 5 600 | sprites |
| `ob_attr` | 2 900 | 5 200 | sprites |
| `move_objects` | 2 000 | 3 900 | game |
| `dl_fill` | 1 600 | 3 700 | river_gen |
| `ay_out` | 3 400 | 3 400 | sound_ay_run |
| `snd_fill` | 2 800 | 2 800 | sound |
| `ay_frame` | 2 200 | 2 800 | sound_ay_run |
| `pk_channel` | 1 200 | 2 700 | sound_pulses |
| `pokey_frame`（自身代码） | 2 500 | 2 700 | sound |
| `draw_line` | 900 | 2 300 | river_gen |
| `pk_g4` | 0 | 1 400 （导弹发声的那一帧约 9 000） | sound_pulses |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `build_copper` | 1 100 | 1 000 | sprites |
| `hit_setup` | 500 | 700 | display_hits |

B 中最重的一帧（约 202 000）：声音最高约 60 000（DAC 上的噪声和导弹，约 180 个脉冲），摆放和河岸检测
（`display`、`ds_obj`、`ds_edge_test`）约 30 000，碰撞（`dh_pf`、`dh_bits`、`dh_obj`、`hit_*`）约
25 000，河流新行约 25 000。

（`prof.py` 用地址下方最近的全局标号作为例程名，所以紧挨在代码前的数据标号可能会把时间算到自己头上；
第 12 页 $6000-$7FFF 的符号对应的是第 7 页同地址的 `panel_init`，它只在启动时运行一次。）

## 代码运行时的内存

8K 槽（$0000、$2000、…… $E000）以及其中的页：

| 槽 | 地址 | 平时 | 被谁换页 |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31：位于原版地址的 Atari 内存 | `pokey_frame`：生成采样时换成 14–15，即 POKEY 的 17 位计数器（`poly17.bin`） |
| 2 | $4000–$5FFF | 不固定：没有固定的页 | `render_line`：18–27（Layer 2，每 32 列一页）；`display`、`span_line`、`spans_clear`：28（`SPAN_PAGE`，各行的色段）；`panel_frame`：11（tilemap 的映射）；`panel_init`：10、11 |
| 3 | $6000–$7FFF | 12：缓冲区（`copper_list`、`ds_objs`、`sprite_list`、`ov_exp2`/`ov_exp4`（展宽后的单字节点，`dh_obj` 用）、河岸缝隙 `eg_*`（`ds_edge_test` 用）、$7C00 处的 DAC 环形缓冲） | 仅在启动时：7（`panel_init`、`sound_init7`、`load_rom`）。**发声时绝不能换**：DMA 通过这个槽读取环形缓冲 |
| 4 | $8000–$9FFF | 4：代码 | — |
| 5 | $A000–$BFFF | 5：卡带，从 River_Raid.rom 读入 | — |
| 6 | $C000–$DFFF | 6：代码 | — |
| 7 | $E000–$FFFF | 1：变量、表（其中有岸边缝隙 `bg_*`）、栈（从 $0000 向下，直到 $FF00 之上） | — |

第 4 页结束于约 $9E2C（上限 $A000），第 6 页约 $DD53（上限 $E000），第 7 页约 $6913（构建时会打印）：
删除 DLI 时刻表后留出了一点空间。以前找空间的办法就是在页之间搬代码（`display_objs.asm` 原先放在
第 4 页调色板对齐前的空隙里，现在在页末）。

中断始终关闭（启动时 `di`）：帧节奏靠轮询光栅行（`wait_frame`），声音由 DMA 送出，逐行颜色由
Copper 负责。

## 一帧

`main_frame`（river_raid.asm），每帧：

1. 记下本帧画面要显示的内容（`scroll`、河岸边缘和水的颜色、当前玩家），`read_input`，CAPS + 1（切换到另一种制式时 `restart`）。
2. 平时：`prepare` → `display` → `build_sprites` → `main_loop` → `vbi`。重置期间（`busy`，原版清内存的那些帧：NTSC 13 帧，PAL 8 帧）：`display` → `build_sprites` → `clear_layer2_page` →（最后一帧 `finish_reset`）→ `vbi`。
3. `pokey_frame`：本帧的采样写入 DAC 环形缓冲，以及 AY 的音调。
4. `wait_frame`：轮询当前视频行（NR $1E/$1F）直到 `wait_line`（NTSC 208，PAL 220），在滚动字幕下方，那里屏幕上不会有变化。
5. `apply`：构建好的所有东西一起生效（Layer 2 的滚动和颜色、精灵属性、面板的 tile、Copper 列表）。

打开 T（`tm_show`）时，每一部分会先设置边框颜色（`TM_COLOUR`：只有 T 打开时才调用 `tm_colour`；关闭时每部分约 30 个周期）：橙色 `apply`，灰色 `prepare`（重置期间还有 `clear_layer2_page`），红色 `display`，黄色 `build_sprites`，蓝色 `main_loop`，品红 `push_line`（河流的一行新行，在 `main_loop` 之内），白色 `vbi`，青色 `pokey_frame`，黑色为剩余时间。`push_line` 先设品红，再改回蓝色。

顺序很重要：`display` 使用上一帧 `main_loop` 留下的状态（正如 Atari 的 DLI 显示的是上一帧的状态），
`build_sprites` 使用 `display` 留下的结果。

---

## river_raid.asm：帧、启动、内存

主文件：内存布局、`include`、各页的汇编（`mmu`/`org`）、第 1 页的变量和第 12 页的缓冲、测试构建的钩子。

| 例程 | 调用 | 做什么、怎么做 |
|---|---|---|
| `start` | 加载时 | `load_rom`（测试构建中没有），用 R 播种 RANDOM，28 MHz，映射各页，`init_tables`，`init_video`，`panel_init`（映射第 7 页），然后 `restart`。 |
| `restart` | `start`；CAPS + 1 | 以 `tv_pal` 的制式“开机”：`tv_setup`，清空 Layer 2（10 页一次清完），`sound_init`，`start_attract`，落入 `main_frame`。 |
| `main_frame` | 每帧 | 见 *一帧*。自身约 340 周期。 |
| `wait_frame` | `main_frame` | 忙等 NR $1F 与 `wait_line` 比较。它的时间是空闲，不是工作。 |
| `init_tables` | `start` | 一次性：各种表：`pix_tab`（`render_line` 用），`ring_lo`/`ring_hi`（屏幕内存的 160 行顺序），`span_class`（一个字节 4 个像素相同时的颜色），`span_init`（掩码），一个空的 Copper 列表。 |
| `tv_setup` | `restart` | 制式相关设置：NR $05 50/60 Hz，`init_line_tables`，`wait_line`，随机映射，Copper 的面板部分（复制 `copper_panel_ntsc`/`_pal`，填入灰色 `COPPER_GREY`），tilemap 的第一个 Y 滚动，裁剪窗口（Layer 2 到面板最后一条灰线、精灵、tilemap）。 |
| `init_video` | `start` | 黑色边框，不用 ULA，全局透明色 $E3，Layer 2 320×256×8 在 bank 9，层顺序（tilemap 在精灵之上、精灵在 Layer 2 之上），调色板：Layer 2 的 4 项，精灵的 128–255 = Atari 颜色，NR $15 开启精灵覆盖边框的裁剪模式。 |
| `test_ghost` | 测试构建，`test_ghost_on` 时在 `display` 之后 | nxcheck 的 NXGHOST：设置飞机的碰撞和燃油，使它不会坠毁。 |

此外：`span_rec`（宏：HL = SPAN_PAGE 中河流第 A 行的 32 字节记录），`palette`（Atari 颜色 → Next 颜色，
256 字节）和 `random_columns`，`TEST` 变量（`start_bridges_hi`、`snd_passed`、`test_ghost_on`）。

## play.asm：主循环（A197–A6EA）

原版在主循环中运行的游戏逻辑，与 C++ 移植版一致。状态保存在原版内存的地址上。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `main_loop` | `main_frame`（重置期间不调用） | A197–A6EA：读取 RANDOM（`random_read`），飞机（`fly_plane`）或爆炸/复活（`respawn_or_game_over`），`drive_tank`，`move_objects`，然后 `main_loop_end`。开始重置时提前返回。 | 620 / 620 |
| `main_loop_end` | `main_loop`、`finish_reset` | A5B7–A6EA：导弹和坦克炮弹（`move_missile`、`move_shell`），`scroll_river`，START/SELECT。 | 180 / 170 |
| `scroll_river` | `main_loop_end` | A6FD：每帧两次把速度加到一个小数上；每次进位就是一次 `push_line`（河流的一行新行：昂贵的部分，见 river_gen）。 | 140 / 160 |
| `fly_plane` | `main_loop` | A3E9–A5B4：燃油、转向（`steer`）、速度（`change_speed`）、射击、子弹（`move_bullet`），碰撞结果：`explode`（击中或撞上的物体：得分），`crash`。 | 290 / 480 |
| `steer`、`change_speed` | `fly_plane` | 飞机的 X，带亚像素的小数部分；速度 $40–$FE。 | |
| `explode` | `fly_plane` | A4E0–A589：槽位变成爆炸，得分（BCD），桥的奖励。 | |
| `crash` | `fly_plane`、`explode` | sub $B1C0：飞机坠毁，伴随事件音效；`section_checkpoint`。 | |
| `draw_bullet`、`move_bullet` | `fly_plane`、`crash` | 子弹的 8 行写入导弹 2 的内存（仅 `-DBEAM`；否则 `draw_bullet` 立即返回）。 | 380 / 520 |
| `new_game`、`reset` | START、游戏结束、复活 | sub $B0F1：河流和物体清零（`restore_checkpoint`），`clear_screen_memory`（仅在有屏幕内存时：校验构建和光束构建），`busy` = 13 或 8 帧。 | |
| `clear_layer2_page` | `busy` 期间的 `main_frame`、`restart` | 每帧清 Layer 2 的 10 页中的两页（`l2_clear` 计数）；重置的第一帧不清（`l2_wait`：它的画面仍在显示），同时 `apply` 隐藏河流的行（`l2_hidden`）。A 中平均每帧约 1 100，但在它运行的那几帧里一页就是 8 KB 的写入。 | 1 100 / 570 |
| `finish_reset`、`finish_respawn`、`respawn_or_game_over` | | 重置之后：河流从检查点继续，下一位玩家或游戏结束。 | |
| `swap_players`、`update_high_score`、`set_up_game`、`select_game` | | 双人、带校验字节的最高分、游戏编号。 | |
| `show_lives`、`show_score`、`show_bridges`…… | 循环、VBI | 面板字符写入 Atari 内存（$1000）。 | 620 / 720 |
| `print_bcd` | 各 `show_*` | B086：BCD 字节显示为数字，前导零留空。 | 1 200 / 1 400 |
| `read_input` | `main_frame`（测试构建中没有） | 键盘（Q A O P、空格/M、回车、G、H、CAPS + 1/2）、Kempston 1 和 2 以及 Mega Drive 手柄，写入 Atari 的摇杆、扳机和控制台字节。T（按下时）切换 `tm_show`，关闭时：备用色为黑色。 | — |

## game.asm：每帧的游戏部分和 VBI

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `random_read` | `main_loop`（A205） | POKEY 的 RANDOM：读取时刻的 17 位计数器。校验会统计这些读取。 | |
| `random_step` | `vbi` | 计数器前进一帧：一个固定的线性映射（`random.inc` 中的 17 列，NTSC 或 PAL），每次 4 位：对 0–15 位的 4 个半字节，各从 `rnd_tab`（第 1 页，256 字节对齐：64 k + 4 v）取一个 3 字节项异或进去，若第 16 位为 1 再异或其列（`rnd_col16`）。原先逐位计算，约 2 300。 | 560 / 560 |
| `rnd_tables` | `tv_setup` 末尾 | 根据制式的列（`rnd_cols`）生成 `rnd_tab` 和 `rnd_col16`：每项是其值对应各列的异或。 | |
| `bank_colour` | `vbi`、`start_attract` | sub $AFD0：河岸的色调（顶部有桥进入时会变）。 | 200 / 200 |
| `start_attract` | `restart` | 演示模式在其第一行时的状态（游戏 1，无飞机）。 | |
| `draw_logo_and_needle` | `reset`、`start_attract` | 彩虹和燃油指针写入 player-missile 内存，与 sub $B0F1 留下的一样（仅 `-DBEAM`；Next 上它们是精灵）。 | |
| `push_line` | `scroll_river`、`start_attract` | 河流的一行新行：`next_line`（river_gen）把各段记录到 `dl_seg`，随后在 `line_done` 中 `render_line`（Layer 2）和 `span_line`（碰撞用的色段）据此绘制；有屏幕内存时（校验构建和光束构建，`SCREEN_MEMORY`），这一行的字节还会经 `line_buf` 写入屏幕内存（48 次 LDI，顶行地址上移一行）。 | |
| `prepare` | `main_frame` | 帧开始时的 AE99–AF38：从屏幕下方出去的坦克和炮弹，炮弹颜色，面板上的生命、桥数和分数。player-missile 内存中的形状（$0B00–$0FFF）只在周期模型构建（`-DBEAM`）中写入：Next 的精灵和碰撞直接从 ROM 取。 | 约 2 000（含复制约 3 000） |
| `drive_tank` | `main_loop` | A21B：路上的坦克前进，在河边开火。 | |
| `move_objects` | `main_loop` | A26C–A2ED：槽位中的物体动画和移动（船和直升机碰到河岸会掉头：槽位的河岸标志来自 display）。 | 2 000 / 3 700 |
| `move_missile`、`move_shell` | `main_loop_end` | 直升机的导弹，坦克的炮弹。 | |
| `vbi` | `main_frame` | B2A5–B43E：`sound_driver`，帧计数器，下一帧的颜色（`bank_colour`），`scroller_step`，`random_step`。PAL 下游戏结束时会看到 sub $B21A 之前的一些值（`vbi_before`）。 | 420 / 430 |
| `scroller_step` | `vbi`、`start_attract` | B44B：演示模式下滚动字幕每帧移动一个色钟，游戏中静止。 | |

## river_gen.asm：河流生成器（A711–AE93）

一次生成河流的一行，与原版一样：24 位 LFSR，段和块，河岸和岛的宽度，装饰（房子、山），道路和桥，每
16 行放置一个物体。它的结果是 `dl_seg` 中这一行的各段（每段 4 字节：起始字节、类型、数据：0 表示边缘，
其片段在 $B800 表中的偏移；1 表示同值字节，即该值；2 表示一行装饰，即其位图地址；以字节 48 结束）以及
槽位。游戏中没有行缓冲：`line_buf`（48 字节，192 个 2 位色钟；事先不清空，各段从字节 0 到 48 依次填入）
只在有屏幕内存时才写。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `next_line` | `push_line` | 一行：`count_lines`、`move_bank`、`change_island`、`scroll_objects`、`place_object`，然后 `draw_line`。 | 210 / 290 |
| `count_lines` | `next_line` | A711：数行；在块和段的开始处准备接下来的内容（`choose_section_width`、`start_decoration`、检查点）。 | 160 / 210 |
| `move_bank`（+ `bank_hit_setup`、`bank_hits_left/right`） | `next_line` | A826：本行河岸的位置，不能撞上仍在进入的物体。 | 350 / 570 |
| `change_island`、`choose_section_width` | | 岛向目标宽度变化。 | |
| `draw_line` | `next_line` | 这一行的各段：河岸填充（`dl_fill`、`dl_fill_bank`），边缘（`dl_edge`、`dl_bank_edge`：来自 $B800 的 2 字节片段），装饰的一行（`dl_deco_row`，其位图地址前移），水；每段连同数据写入 `dl_seg`，DRAW_POS 前移；只有在有屏幕内存时才把它们的字节写入 `line_buf`。 | 900 / 2 300 |
| `dl_fill` | `draw_line` | 从 DRAW_POS 起 B 个值为 C 的字节：一个类型 1 的段（字节本身只在有屏幕内存时才写）。 | 500 / 1 300 |
| `scroll_objects` | `next_line` | AB76：所有东西下移一行；最低的槽位离开屏幕时，槽位整体移动。 | 560 / 820 |
| `place_object`、`choose_enemy`、`position_object`、`place_tank` | `next_line` | 每 16 行在下一个空槽位放一个新物体；块开始时可能在路上放一辆坦克。 | |
| `step_lfsr` | 多处 | sub $B183：24 位 LFSR。 | 140 / 200 |
| `section_checkpoint`、`restore_checkpoint`、`start_game` | | 复活点；新游戏从第 1 座桥开始（测试构建中为 `start_bridges_hi`）。 | |

生成器的开销按每一新行计算：速度每帧两次加到一个小数上，每次进位就是一行，所以每帧 0–2 行，飞机飞得
越快行越多。

## render.asm：一行写入 Layer 2

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `render_line` | `line_done` | 这一行的色钟 20–179（`WINDOW_FIRST`）写入 Layer 2 的第 A 行，依据 `dl_seg` 中的各段（没有行缓冲）。Layer 2 按列存放（字节 x·256 + y，每个 8K 页 32 列），所以这一行要沿列写下去（`inc h` = 下一列），10 页轮流映射到槽 2（`rl_next`）。同值段：其颜色从 `pix_tab` 取一次，然后 `rl_fill`（每字节 8 列，逐页；`rl_fill`、`rl_next` 在第 6 页的 spans.asm）；边缘的字节（来自 ROM 表）和装饰的一行（来自 ROM 中的位图）：每字节由 `pix_tab` 给出每色钟 2 个点，每个写两次；窗口之前的字节在数据中跳过。每行 320 次写入。在第 6 页（为了腾出空间从第 4 页移来）。 | 3 900 + 3 800 / 9 400 + 8 300 |

## spans.asm：用于与 playfield 碰撞的行色段

河流的每一行在 SPAN_PAGE（第 28 页，$4000）中有一条 32 字节的记录，组成 256 行的环：其河岸色段（颜色 1）
和边缘色段（颜色 2）的起止色钟。碰撞时用精灵的各行与这些色段比较，而不是与像素比较。用同一个环索引，
还有它们的缝隙：`eg_e1`–`eg_s2` 和 `eg_e3`–`eg_s4`（第 12 页）是边缘色段之间的水（2 段时为两段之间，
4 段时为第 1 与第 2、第 3 与第 4 段之间，没有色段时为整行，其他情况没有：$FF）；`bg_e1`–`bg_s2`、
`bg_e3`–`bg_s4`（第 1 页）是河岸色段之间最宽的两个缝隙（从第一段之前的色钟 32 到最后一段之后的 224）。
完全落在缝隙内的方框在这一行上碰不到任何东西。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `span_line` | `line_done` | 依据 `dl_seg` 的各段生成新行的记录，完全不看像素：同值段整段是一种颜色（`span_class`），装饰的一行是河岸色（与 C++ 移植版的 bankRuns 一样，即没有装饰的行），边缘的色段按其片段从 `edge_runs` 现成取得（片段内的色钟及其颜色，在字节 48 处截断）；每次颜色变化结束一个色段（`.change`）。然后是缝隙（`.gaps` 来自边缘色段，`.bgaps` 来自河岸色段：保留最宽的两个，`.gap`）。 | 4 200 / 10 300 |
| `edge_runs_init` | `init_tables`（启动） | 生成器用到的每个边缘片段（$B800 表的偏移 0–30）写入 `edge_runs`（第 12 页，每片段 16 字节）：其两个字节的像素 0–7，在第一个像素和每次变化处记一对（像素、其颜色；3 即水按 0 处理），之后为 $FF。 | 一次 |
| `spans_clear` | `start_attract` | 所有行都没有色段（屏幕内存已清空）。缝隙保留：没有色段时无论缝隙如何都碰不到东西，而每一新行都会重做它们。 | |
| `span_init` | `init_tables` | 掩码：一个字节的第 i..j 位（`span_masks`）。 | |

## display_simple.asm：物体的摆放及其碰撞

与 C++ 移植版的 `displayGeometry`（`dli_removed` 分支）一样：没有 DLI。每个物体位于其槽位的 y，按河流
范围裁剪，碰撞就是简单的几何。它留下：`ds_objs`（每个物体给精灵用的行：8 字节，第一行、行数、形状和
颜色指针、x、尺寸），`ds_bank_ev`（河岸颜色的变化，供 `build_copper` 用），HIT 中的碰撞结果以及各槽位
的河岸标志。

`display`（自身约 11 800 / 13 500）：

1. 映射 SPAN_PAGE，`dh_lists`（其他精灵的描述符），按 B527–B55C 清除并设置寄存器，`bm_hitclr`，`dh_sprites`（HIT = $FF，然后其他精灵与河岸及彼此之间的检测）。
2. `.slot`，从 FIRST_SLOT 起的每个槽位：IY 指向槽位的外观类型（第 5 页：类型、X、尺寸分别在 IY + 11、+ 22、+ 33，就地读取，不复制），保存 Y 和标志（`ds_y`、`ds_flags`），`ds_edge_kind`；起点 = max(y, $5D)；第一行 = y + height[type] − 起点（≥ $80：已从顶部消失，下一个）；X = 起点 + 3（超过 255：结束）；行数 = min(行 + 1, 256 − X)；`ds_rowp` 为第一行的字节；`ds_obj`（行写入 `ds_objs`）；若是桥：`.road`（道路颜色从其每一行之后的扫描线起，X − 69 + 1；最后一行之后是该段的河岸颜色，除非 X 已回绕，经 `ds_bank`；一行的颜色只在与上一行不同时才记录）。形状和颜色的首行就地计算（DE、BC 传给 `ds_obj`）。ROM 的表（高度、形状、颜色）用 8 位加法读取（`ROM_SHAPES` 和 `ROM_COLOURS` 从页首开始）。
3. 对类型 8–$0D 检测边缘（P3PF）（`ds_edge_kind`：直升机、气球、船会在那里掉头）：`ds_edge_test`，然后 `ds_set_flags`。
4. 与子弹、坦克炮弹（桥除外）和飞机检测：`dh_obj`；碰到时记录槽位（HIT_BULLET_OBJECT、HIT_SHELL_OBJECT、HIT_PLANE_OBJECT），因此保留的是沿屏幕向下的最后一个。
5. `.end`：`test_ghost`（测试构建）；`ds_bank_fill` 仅在 `-DBEAM` 下。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `ds_edge_test` | `display`，类型 8–$0D 的每个物体 | 若某一行的范围（从第一个点到最后一个点）与其所在扫描行上的边缘色段相交，则 A = $02（即 C++ 移植版的 `edgeTouches`）。物体的方框（X 到 X + 8、16 或 32 个色钟；超过色钟 255 的部分忽略）逐行与该行的水缝隙比较（`eg_*`，行的环索引每次加一）；落在缝隙内就看下一行。否则用该行的第一个和最后一个点（`edge_lo`/`edge_hi` 按尺寸缩放：`.s1`/`.s2`，加 X：`.ex1`/`.ex2`）与该行的边缘色段（其记录）比较：两点之间有色段即为接触，不逐点检测。 | 3 200 / 10 200 |
| `ds_set_flags` | `display` | 把物体的河岸位写入其槽位的标志（第 0 位）。 | 1 100 / 1 300 |
| `ds_bank` | `display` | 从扫描线 A 起河岸颜色的一次变化（桥的道路以及恢复）：写入 `ds_bank_ev`。 | |
| `ds_bank_fill` | `display` 末尾，仅 `-DBEAM` | 根据 `ds_bank_ev` 为河流每一行写 `scan_bank`（光束 display 会读取；nxcheck 则改为把 Copper 列表与 C++ 移植版比较）。 | |
| `ds_edge_only` | `display` | 只为会读取河岸位的类型设置它。 | |

## display_objs.asm

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `ds_obj` | `display`，每个有行的物体 | 物体供精灵使用的行：第一条扫描线、行数、第一行的形状和颜色地址（DE、IY）、x、尺寸：写入 `ds_objs` 的 8 字节（`DS_OBJS` = 最多 16 个）。第一行在第 28 行或更高（在河流顶部之上）的物体会扩展为完整形状（多出 k = 起点 − y 行），这样精灵画完整，由精灵裁剪窗口来切掉。位于第 4 页末尾。 | 5 300 / 6 100 |

## display_hits.asm：把碰撞当作几何

没有碰撞寄存器，也不读取它们：只要在精灵的行上任何位置发生碰撞就算数。另外五个精灵由 `dh_desc` 中
10 字节的描述符描述（不变的部分在开始时从 `dh_template` 复制一次，`dh_init`；其余由 `dh_lists` 每帧填写）：行的基址（低）、掩码（已经转到点的位置上）、行的结束（最后一行之后的那一行；超过 255 为 255）、x、尺寸、精灵号、
第一行、行数、色钟宽度、基址（高）（`DH_SIZE` = 10；`DH_SHELL`、`DH_TANK`、`DH_PLANE`、`DH_MISSILE`、
`DH_BULLET`）。第 L 行上的一行就是基址 + L 处的字节：本帧形状直接来自 ROM（基址 = 其地址 − 第一行，
`dh_shape`、`dh_base`）；导弹和子弹的行是 `dh_ones`（全为 1），套上各自的掩码，掩码在模板里就已转到点的位置上（$03 转 6 位：$C0；子弹的第 5 位转 2 位：$80），所以不必转动任何一行。重置
之后（`pm_empty`，直到下一次 `prepare`）没有行。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `dh_lists` | `display` 开头 | 各描述符的行数、位置和基址；然后各自的结束（字段 2）。 | 1 300 / 1 300 |
| `dh_sprites` | `display` | HIT = $FF，然后在以下情况置 HIT 0：坦克碰到边缘（P1PF），飞机碰到河岸（P2PF），导弹和子弹碰到河岸或边缘（M0PF、M2PF）：`dh_pf`；飞机与坦克炮弹（P2PL 第 0 位）、导弹与飞机（M0PL）：`dh_pair`。 | |
| `dh_pf` | `dh_sprites` | NZ：精灵 IX 的行碰到 playfield（DE：`sp_edge`、`sp_bank`、`sp_under`）。对每一条河流行：先取掩码下该行的字节（没有点：下一行），再看其方框（X 到 X + 其色钟数）是否落在该行的缝隙内（A：第 0 位为边缘的 `eg_*`，第 1 位为河岸的 `bg_*`）；在内则无事；否则用该行两端与色段比较（`sp_*` 函数）。遇到第一次接触即停止。 | 10 200 / 11 200 |
| `sp_edge`、`sp_bank`、`sp_under` | `dh_pf` | 精灵的一行与该扫描行的边缘（棕色）、河岸（绿色）或两者的色段比较，与 C++ 移植版的 `spanTouches` 一样：它的第一个和最后一个点（`sp_ends`：`edge_lo`、`edge_hi`、按尺寸的宽度，加 X）与色段比较（`sp_runs`），两点之间有色段即为接触；该行的记录经 `sp_rec` 取得。 | |
| `dh_pair` | `dh_sprites` | NZ：两个精灵的行相遇：对它们的色钟做 `hit_setup`，然后在两者都有的每一行上，把各自的位（`dh_bits`，按尺寸 `hit_wide`）放入 `hit_a`、`hit_b`，再 `hit_line`。 | |
| `dh_bits`、`dh_end` | `dh_pf`、`dh_pair`、`dh_obj` | 精灵 IX 在第 A 行上的位：掩码下该行的字节，已在高位（Z：没有）；其最后一行之后的那一行（由 `dh_lists` 每帧一次写入字段 2）。 | 400 / 500 |
| `dh_obj` | `display`，每个物体（子弹、炮弹、飞机） | NZ：精灵 IX 碰到当前物体的行（`ds_rowp`，从 X = `ds_counter` 那一行起，共 `ds_rows` 行，位于槽位的 X 和尺寸：IY + 22、+ 33）。先看两者都有的行（`display` 给的 `ds_l1`、`ds_l2` 和精灵的结束：多数物体与它没有共同的行），再对物体（8、16 或 32）和精灵的色钟做 `hit_setup`；每行取物体行的字节（为零：下一行）和精灵的位，各自展宽（`hit_wide`），`hit_line`。 | 4 900 / 6 100 |
| `hit_setup` | `dh_obj`、`dh_pair` | Z：两个方框的色钟（B 起、C 宽；D 起、E 宽）不相交；否则求两者都在 playfield 色钟（32–223，最多 8 宽）内的窗口：它在各自点中的起点（`hit_ka`/`hit_sa`、`hit_kb`/`hit_sb`：字节、位）以及其色钟的位（`hit_w`）。 | 500 / 700 |
| `hit_wide` | `dh_obj`、`dh_pair` | 字节 A 的点，每位一个色钟，写入 DE 及之后（尺寸 C：每点 1、2 或 4 个色钟，来自 `ov_exp2`、`ov_exp4`：由 `init_tables` 生成的表），然后一个零。 | |
| `hit_line` | `dh_obj`、`dh_pair` | NZ：`hit_a` 和 `hit_b` 的点在窗口内相遇：各自从起点取两个字节，用 `bsla de,b`（Z80N，8 周期）移位，相互 AND 并与 `hit_w` AND。 | |

## display.asm：playfield 检测（以及旧的光束模型）

这个文件的大部分是 DLI 的完整、周期精确的模型（`op`、`bm_events`、`bm_draw`、`rec_set`、`p3_scan`、
`bm_wsync`、光束的 `collide` 主体……），保留作参考，只在 `-DBEAM` 下汇编。总会汇编的有：

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `pf_under`、`pf_bank`、`pf_edge`、`pf_none` | 光束 display（`-DBEAM`） | 精灵的一行（D 的位从第 7 位起，位置 E，尺寸 A：每位 1、2 或 4 个色钟）在 `bm_line` 行上是否逐点地压在河岸、边缘或两者之一上？找到该行的记录（`pf_line`），再遍历其色段（`pf_size`）。游戏已不再使用。 | |
| `pf_line` | `pf_bank`、`pf_edge` | HL = `bm_line` 行的记录（进位：是河流的一行）。 | |
| `pf_size`、`pf_v1`、`pf_v2`、`pf_v4` | `pf_*` | 精灵下方的色段：与精灵色钟重叠的色段用 `span_masks` 与其位比较（D：掩码所在页）；每种尺寸一个变体（N 次移位把色钟偏移变成位索引）。 | |
| `collide`（`.add`、`.pair`、`.overlap`、`.entry`） | 光束 display（`-DBEAM`） | 一行上精灵的列表（位、位置、尺寸）以及其中两者重叠的逐点检测；游戏已不再使用。 | |
| `bm_hitclr` | `display` | HITCLR：清除碰撞位。 | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | 每条扫描线：其开始时 ANTIC 的周期（`line_start`）以及绘制后剩余的周期（`line_after_draw`）；现在只有 `-DBEAM` 模型读取。 | |

## sprites.asm：精灵、Copper、`apply`、面板

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`（各物体）；飞机、它的子弹、坦克、直升机的导弹、炮弹（按 `drawRiver` 绘制它们的顺序，最后的在最上面）：各自用启动时生成的本帧图案（`pl_plane`、`pl_tank`、`pl_shell`、`pl_bullet`、`pl_missile`）放到其位置，`pl_sprite`；`pl_keep` 保存它们的属性，重置期间（`busy`）的帧会再次显示它们（`pl_again`）；`build_copper`。 | 1 000 / 1 100 |
| `pl_sprite` | `build_sprites` | 图案 A（$FF：没有）在第 D 行（在河流下方则没有），位置 E，调色板偏移 C：其 5 个属性字节写入 `sprite_list`（X = 2·(x − 52)，9 位；Y；偏移；图案；4 位、半图案）。 | 每个精灵约 100 |
| `ob_list` | `build_sprites` | `ds_objs` 的每一项，取 `ds_objf` 中的全部行：用顶行的形状和颜色地址找到启动时生成的图像（`obj_lookup`；找不到：`ob_miss`，不画），每 16 行一个精灵（`ob_attr`：X = 2·(x − 52)，Y，bank，4 位，半图案，双倍或四倍宽时的缩放），第一行在河流下方的那一块不建精灵。 | 5 700 / 6 400 |
| `build_copper` | `build_sprites` | 只在河岸颜色变化时（`cp_colour`；只要有河岸事件就总是，`ds_bank_n` ≠ 0）：`copper_start`，然后对 `ds_bank_ev` 中每条河流行的每次颜色变化放一个 WAIT + MOVE $41，设在前一行；然后是面板部分（`copper_panel`），最后的 WAIT。`cp_full` = 1。 | 1 400 / 1 600 |
| `apply` | `wait_frame` 之后 | Layer 2 的滚动（NR $17），精灵属性（端口 $57，每个精灵 OTIR 5 字节；比上一帧多出的隐藏），炮弹、坦克和飞机的颜色（精灵调色板），Layer 2 的颜色 0、2、3，其裁剪窗口（重置后清 Layer 2 期间，从第二帧起：只有面板的行，`l2_hidden`；`l2_clip_y2` 为 `tv_setup` 给出的窗口最后一行），`panel_frame`，Copper：停止，若 `cp_full` 则发送整个列表，否则只发送滚动字幕的 X 滚动字节，重新启动（模式 %11）。长时间无操作后关闭屏幕（IDLE_TIME）。不计入上面的数字。 | — |
| `panel_frame` | `apply` | 面板：只处理 `panel_put` 列出的位置（`pf_dirty`；在 `start_attract` 的复制和 `tv_setup` 之后为全部），每个位置从 `.cells`（其左半的格子；行首字符只有右半）起，写 2 个格子：tile 2·代码 + 半，颜色位作为调色板偏移。滚动字幕（半字 h 在 8h − X0，X0 = 16·TEXT_LO + 38 − 2·FINE_SCROLL）：映射第 26 行上的环（半字 h 在第 h mod 40 列；只写自上一帧以来新出现的半字，`.ring_write`；跳变后写全部 40 个），X 滚动 X0 mod 320（9 位：`CP_XSCROLL_HI_BACK`、`CP_XSCROLL_BACK`）；tilemap 的裁剪窗口右侧缩短 S = X0 & 7 个点（回绕的那一列）；精灵 70（图案 20，调色板偏移 6）在 X 320 − S 处显示半字 h0 + 40（变化时写入其 64 字节：`.spr_pattern`）。指针和标志的精灵。 | 滚动字幕约 1 700，面板约 200，指针和标志约 1 400 |

数据：`copper_start`（Layer 2 调色板索引 1，原 NR $4A（T 的颜色）处的一个 NOP，tilemap 的 Y 和 X 滚动为 0：其行即屏幕的行，面板以外的行上什么也没有），
`copper_panel_ntsc`/`_pal`（布局相同，因此从列表末尾算起的偏移对两者都适用：
第 200 行：面板第一行的 tilemap Y 滚动（`CP_PANEL_Y`，由 `tv_setup` 填入），Layer 2 颜色 0–3 设为黑色，精灵窗口从第 215 行向下（`OBJ_LAST` + 1，
在任何物体的行之下；指针和标志更靠下）；201：灰色（`COPPER_GREY`，由 `tv_setup` 填入）；面板每一行的 tilemap Y 滚动；第 230 行（PAL 为 240）：
恢复颜色 0–3，边缘和水的颜色由 `apply` 写入（`CP_EDGE_BACK`）；滚动字幕的 Y 和 X 滚动（`CP_XSCROLL_HI_BACK`、`CP_XSCROLL_BACK`）；在 `wait_line`：精灵窗口恢复为河流的窗口）。列表不整体发送时，`apply` 发送从边缘到 X 滚动的那些字节（`.cp_send`）。

## panel.asm（第 6 页）：面板字符

| 例程 | 调用 | 做什么、怎么做 |
|---|---|---|
| `panel_put`、`panel_put_de` | 写面板的地方 | 在 HL（DE）处向面板写一个字符：已经是它就什么也不做；否则写入并把位置记到 `pf_dirty`（60 个或更多：全部）。 |
| `print_bcd` | `show_score`、`show_other_score`、`show_high_score`、`show_bridges`、游戏结束 | HL 处的 B 个 BCD 字节作为数字写到 DE，'0' = C，前导零留空；演示模式下不做。对每个位置（分数、最高分或另一位玩家的分数、桥数、另一位玩家的桥数）保存数字基址和已打印的字节（`pb_cache`），相同时立即返回。 |
| `show_lives` | `prepare` 等 | 生命符号；数量与上次打印的相同时不做（`sl_last`）。 |
| `pb_forget` | `start_attract` | 忘掉上次打印的数字（全部重印）。 |

重叠的位置会让其他位置的记录失效：另一位玩家的生命和桥数，游戏结束文字占据生命的位置。

## sound.asm：声音驱动和 POKEY 采样

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | B2A5–B3D8：原版的驱动：通道 1 起飞提示音、事件音效、低燃油提示音或引擎；2 爆炸或导弹；3 射击或奖命；4 坦克炮弹。写 POKEY 的 AUDF/AUDC（`pokey_audf`、`pokey_audc`）。 | 770 / 930 |
| `sound_init` | `restart` | 打开 DAC（NR $08），环形缓冲和通道静音，`sound_init7`（第 7 页：AY、POKEY 表、编程 DMA），然后在第 12 页换回后启用 DMA（$87）。 | |
| `pokey_frame` | `main_frame` | `ay_frame`（纯音交给 AY；四个都在那里时：环形缓冲静音一次，`snd_idle`，结束），然后决定多少采样：`wait_line` 前剩余的行（NR $1E/$1F），DMA 当前位置（重读其地址），领先最多 `SND_LEAD`（760），至少 `SND_MIN_LEAD`（200），最多 `SND_CAP`（700）。然后：`snd_fill`（把这一段清为 0），每个不在 AY 上的通道：音量 × 本帧增益（`snd_gain_set`：8，音量和超过 31 时为 7–4，`mul d,e`）作为恒定电平（仅音量，或 AUDF ≤ 4：一半）或 `pk_channel`（其翻转作为 + 和 − 写入环形缓冲），然后 `snd_sum`（累加和得到电平）。期间第 14–15 页映射在 $0000（17 位计数器）。 | 2 400 / 2 500 |
| `snd_gain_set` | `pokey_frame` | `snd_gain`：每级音量 8，或当 DAC 上各通道音量和超过 31 时取能让电平保持在 255 以内的最大值（到 36 为 7，到 42 为 6，到 51 为 5，否则为 4）。 | 约 150 |
| `snd_fill` | `pokey_frame` | 把 DE 个值为 A 的字节从 HL 写入环形缓冲（回绕时分两段），每段用 PUSH 从末尾向下写（保存 SP）。 | 2 800 / 2 400 |
| `snd_sum` | `pokey_frame` | 对 DE 个采样求累加和：`add a,(hl) / ld (hl),a / inc l`，展开 8 次，余数从合适位置进入（自修改的 `jp`），在环形缓冲中逐页进行。约 270 个采样约 8 400 周期：每个采样约 31。 | 8 600 / 7 300 |
| `sound_random` | `sound_driver` | 噪声音高用的 RANDOM（不是 `random_read`，那个会被校验统计）。 | |

环形缓冲：$7C00 处 1024 字节（第 12 页），1K 对齐，由 zxnDMA 以突发模式、预分频 55（15 909 Hz）送到
端口 $DF，结束时重启。电平 0–240。

## sound_pulses.asm、sound_handlers.asm：一个通道的翻转

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `pk_channel` | `pokey_frame`，AUDF ≥ 5 的每个通道 | 准备：音量的部分值（4 份中的 × 0–3，用于在一个采样内部的翻转），4 位和 5 位计数器的周期步进（`snd_mod15/31`），周期换算为采样数和周期 × 64 并填入循环；第一个脉冲（`CH_D`、`CH_F`）；K = 本帧的脉冲数（12 位除法，展开：tick 数小于 4 × SND_CAP < 4096）；然后进入对应类型的循环。 | 1 200 / 2 800 |
| `pk_tone` | `pk_channel` | 音调：每个脉冲输出翻转一次。 | |
| `pk_noise` | `pk_channel` | 噪声：每个脉冲取 17 位计数器的下一位（位连续存放，映射在 $0000）；其翻转发生在采样开始处（+ 或 − 音量，不跨两个采样拆分）。 | 4 600 / 12 900 |
| `pk_g4` | `pk_channel` | 由 5 位计数器门控的 4 位计数器（AUDC 010：直升机的导弹）：两个计数器合为一个数 m（`g4_crt`：m = b + 31 ((e − b) mod 15)），脉冲 m + s，对每个 m 查 `g4_tab`（$FF 不通过，否则为该位）；最后从 m 还原两个计数器。翻转在采样开始处。 | 0 / 1 400 |
| `pk_other` + `pk_handlers`（`adv31`、`adv15`） | `pk_channel` | 其他类型通过处理器完成。 | |
| `pk_on`、`pk_off`、`pk_part*` | 各循环 | 音调或其余类型在脉冲处的翻转：本采样得到变化量减去翻转前的部分，下一个采样得到那一部分（避免整采样带来的嗡声；噪声和导弹则在采样开始处翻转）。 | |
| `pk_done` | 各循环 | 本帧剩余 tick 存入 `CH_D`、`CH_F`，保存输出状态。 | |

## sound_ay.asm（第 7 页）、sound_ay_run.asm（第 6 页）：AY 上的纯音

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `ay_init` | `sound_init7` | 打开 TurboSound，第一片 AY 单声道，只用音调，静音。 | |
| `sound_init7` | `sound_init` | `ay_init`，第 1 页的 POKEY 表，`snd_mod15/31`，编程 DMA（不启用）。 | |
| `ay_frame` | `pokey_frame` | 对每个发纯音的 POKEY 通道（AUDC 101x 或 111x，不是仅音量，音量 ≠ 0）：分配其专属的 AY 通道（`ay_slot`：1 第二片 AY 的 A，2 第三片的 A，3 第一片的 B，4 第一片的 C），周期 N = (AUDF + 1) × 3.454（PAL）/ 3.422（NTSC）用 `mul d,e` 计算，音量经 `ay_vol`，混音器的音调位；`ay_mask` 告诉 `pokey_frame` 跳过它们。本帧寄存器写入 `ay_q`（3 帧 × 33：三片芯片的 0–10，经 `ay_qi` 轮换），输出的是 2 帧之前的那组。 | 2 200 / 2 800 |
| `ay_out` | `ay_frame`、`ay_init`、`ay_quiet` | 从 HL 写三片 AY 的寄存器 0–10（最后选中第一片，B = $FF）。 | 3 400 / 3 400 |
| `ay_quiet` | `pokey_frame`（声音关闭）、`ay_init` | 全部静音（音量 0，混音器 $3F）。 | |

`sound_ay_run.asm` 在第 6 页而不是第 7 页，这样 `pokey_frame` 就永远不会把第 7 页映射到环形缓冲上（见
NOTES：咔嗒声）。

## panel_init.asm（第 7 页，启动时）

| 例程 | 调用 | 做什么、怎么做 |
|---|---|---|
| `panel_init` | `start`（第 7 页在 $6000） | 在游戏构建 Atari 字符集的位置构建它们（来自 `font.inc` 的系统字体，卡带的符号），每个字符作为两个 tile（tile 0–127 为面板的，128–255 为滚动字幕的）放入第 10–11 页，tilemap 的调色板和寄存器（NR $6B/$6C/$6E/$6F，裁剪），指针和标志精灵的图案，`edge_lo`/`edge_hi`（每个字节第一个和最后一个亮点，用于边缘检测）。 |
| `pl_pics` | `panel_init`，在 `obj_pics` 之前（第 7 页） | 飞机的 10 帧（14 行）、坦克的 8 帧（11 行）、炮弹的 7 帧（16 行），从 ROM 中它们的指针表取得，与 `prepare` 复制到 player-missile 内存的一样：每个是一个 4 位图案（一个点：2 个值为 1 的像素），地址相同的帧共享，完全空白的帧没有图案（$FF）；子弹（8 行单点）和直升机的导弹（一行 4 点）。图案从 0 开始（共 20 个）。 |
| `obj_pics` | `panel_init`（第 7 页） | 物体的图像：对类型 7–15，它们可能具有的外观类型（自身的，`ROM_NEXT_KIND` 中低于 $0C 的，爆炸从 2 和 3 起的），每种还有镜像，height + 1 行；58 个图像作为从 24 起的 4 位图案，点的值为其行颜色在调色板 bank 14（类型 12、15）或 15（其他）中的位置；`obj_head`/`obj_e` 供 `obj_lookup` 使用。 |

## load_rom.asm（第 7 页）

| 例程 | 调用 | 做什么、怎么做 |
|---|---|---|
| `load_rom` | `start`（测试构建中没有） | 通过 esxDOS 打开程序目录中的 River_Raid.rom（F_OPEN、F_READ、F_CLOSE；在看不到长文件名的地方用短文件名），把它的 8192 字节读到 $A000（第 5 页）。没有该文件：红色边框并停止。只在真实 Next 上验证过。 |

## 包含文件

- `vars.inc`：游戏变量的 Atari 内存地址（原版的名字）。
- `palette.inc`：Atari 调色板对应的 Next 颜色（由 `tools/mkpalette` 生成）。
- `random.inc`：RANDOM 步进的各列（`tools/mkrandom`）。
- `font.inc`：系统字体（`tools/mkfont`，来自 AltirraOS，附其说明）。
- `poly.inc`、`poly17.bin`：POKEY 的 4、5 和 17 位序列（`tools/mkpoly`）。

## 修改代码前要知道的事

- **自修改代码**在热循环中很常见：填入的立即数和跳转目标（`ds_edge_test` 的 `.bx1/.be1/.bx2/.be2/.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x`；`dh_pf` 的 `.mode/.x0a…/.x1d/.bits/.fn`；`snd_sum` 的 `.jp`；各 `pk_*` 的 `.pf/.pq`）。任何变体都要逐字节核对（曾经有一个遗留的 `add a,a` 让声音翻了倍）。
- **展开代码的入口点**：`snd_sum` 为处理余数会跳进 `rept` 块的中间。
- **槽 2** 是工作窗口：需要在那里放某页的例程自己映射，用完不恢复；下一个使用者映射自己的页。**槽 3** 在发声期间必须保持第 12 页。
- **表按页对齐**，这样查表就是 `ld h,high table / ld l,index`：`pix_tab`、`span_masks`、`span_class`、`edge_lo/edge_hi`、`obj_head`、`ov_exp2`/`ov_exp4`、`eg_*`、`bg_*`、调色板。
- **校验**：每次修改后，`nxcheck` 每帧把状态和屏幕内存、逐行河岸颜色、绘制出的物体、Copper 列表和内存与 C++ 移植版比较，最后比较图像。完整一套在 2 个核心上约 25 分钟（HANDOFF.zh.md，*方法*）。汇编失败会留下旧的页：先看构建输出。
- **测量**：`NXHISTALL=文件`（所有帧）或 `NXHIST=文件`（一帧）加 `tools/prof.py`；`NXSLOW=T` 列出超过 T 周期的帧。`NXHISTAPPLY=文件` 对 `apply`（从 `wait_frame` 结束起）做同样的事并打印其平均和最大值；`tools/prof_local.py build/test.sym 文件 帧数 [例程…]` 还按局部标号细分时间（`ds_edge_test.row`、`panel_frame.mod`……）。最重的帧：`-stress` 加 `NXBRIDGE=80 NXGHOST=1 NXGAME=1`。
- **apply**（每帧约 7 400，不在上面的表中）：滚动字幕约 1 700（其中用减法做 X 滚动 mod 320 约 650），指针和标志约 1 400，面板约 200（只处理变化的部分），精灵属性约 1 800，Copper 列表约 1 200。
- **重写**时，较快的验证方法是做一个测试构建，每帧让新做法和旧做法并行运行并统计差异（碰撞的行、摆放、游标都这样做过），之后再删掉旧做法。
