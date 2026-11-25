# TS-Conf 移植版的汇编源码，逐个文件说明

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | [Español](CODE.es.md) | 中文 | [日本語](CODE.ja.md)

写给想读懂 TS-Conf 移植版代码或让它更快的 Z80 程序员。游戏本身（逻辑、河流生成器、物体摆放和碰撞）
是 Next 的代码，复制在 `src/` 中；[docs/CODE.zh.md](../docs/CODE.zh.md) 描述那些例程，本文只说明它们
被改了什么。TS-Conf 独有的部分（画面、逐行河岸颜色、精灵、面板、General Sound 上的声音、从 SD 卡启动）
在这里逐个例程描述，并给出开销。概览见 [README.zh.md](README.zh.md)。

## 两台机器的比较

同一个游戏，两种显示方式。区别何在，在代码中的哪里体现：

| | ZX Spectrum Next | TS-Conf（ZX Evolution） |
|---|---|---|
| 处理器 | Z80N 28 MHz（3.5 / 7 / 14 / 28），中断关闭：轮询光栅行来定帧 | Z80 14 MHz（3.5 / 7 / 14），开启缓存；帧中断 IM 2，从一个事件移到下一个事件，沿帧向下推进 |
| Z80N 指令 | `nextreg`、`mul`、`bsla de,b`、`outinb`…… | 没有：写寄存器是 `ld bc,端口 / out (c),a`；`bsla de,b` 改为循环（`shl_de_b`，display_hits.asm）；不需要 `mul`（AY 周期用加法） |
| 内存 | 8K 槽（MMU，NR $50–$57） | 16K 窗口（PAGE0–PAGE3）；窗口 0 是可写 RAM（MEMCONFIG），因此 Atari 内存位于 $0000 |
| 河流 | Layer 2，320×256，8 位，按列：一行是沿列向下的 320 次写入，10 页轮换 | 16 色，320×240，一行图像 256 字节（每字节 2 点）：一行是沿行的 160 字节，一页 |
| 滚动 | NR $17，256 行的环 | GYOFFS，512 行的环（`scroll` 9 位） |
| 逐行河岸颜色 | Copper：WAIT/MOVE 列表，变化时发送 | 每种河岸颜色一个调色板（PALSEL 0–7，CRAM）；帧中断在变化的前一行设置 PALSEL（`build_events`、`irq`） |
| 精灵 | 128 个 16×16 图案，4 或 8 位，缩放 ×2 ×4；一个物体每 16 行一个精灵 | 单一的 512×512、4 位图像内存（SGPAGE），任意大小至 64×64，不能缩放：每个图像都保存 16、32 和 64 点宽三种；一个物体就是一个精灵 |
| 颜色 | NR $41 等，9 位 | 经 $E000 处的 FM 窗口访问 CRAM（`CRAM_SHADOW`）：颜色和 $E200 处的精灵列表（SFILE）就是普通的内存写入 |
| 面板和滚动字幕 | tilemap 在最上层，其 Y 和 X 滚动由 Copper 设置；滚动字幕是 tile 环 + 接缝处的一个精灵 | 独立的一幅图像（256 色，第 64–79 页），由帧中断从第 184 行起切换上去（VPAGE、GYOFFS、VCONFIG 加 GFXOVR），其字符只画一次再由 DMA 复制；滚动字幕是 512 点上 32 个字符的环，由中断设置 GXOFFS；tile 层 0 提供字符下的灰色以及河流上下方的黑色 |
| 声音 | POKEY 发出的声音写入环形缓冲，由 zxnDMA 送到 DAC（`pokey_frame` 在主处理器上，每帧约 26 000–39 000 个 28 MHz 周期）；纯音在 3 片 AY 上 | General Sound 自己的 Z80 演奏全部 POKEY（`gs/`）；主处理器每帧发送 8 字节（连驱动约 3 400）。没有该卡时：纯音放在 TurboSound 的 2 片 AY 上 |
| 卡带 | esxDOS：从程序目录读取 River_Raid.rom | 自带的 SD 和 FAT16/FAT32 代码：搜索整张卡（Wild Commander 不提供目录） |
| 电视制式 | 50 或 60 Hz（CAPS + 1） | 只有 50 Hz：板子的帧 |
| 清空画面 | PUSH，每帧两页 Layer 2 | DMA 填充，每帧半幅画面 |
| 工具 | `nxcheck`（Next 核心），`NXHISTALL` + `tools/prof.py` | `tscheck`（TSConf 核心），`TSHISTALL` + `../tools/prof.py` |

## 数字

时间是 TSConf 核心在 14 MHz（处理器时钟）下的周期数，一帧约 286 800。数据来自 tscheck 的直方图
（`TSHISTALL=文件`，然后 `python3 ../tools/prof.py build/test.sym 文件 60`，再除以帧数），用的是校验构建
（`-DTEST`：带有游戏本身没有的 Atari 屏幕内存：`line_done` 和 `draw_line` 比游戏中重约 1 000–2 000）。
带 General Sound，所以噪声不占主处理器的时间。两次运行：

- **A**：bot 1，从开始起 3 000 帧：工作量平均每帧约 69 000，最多约 120 000；
- **B**：从第 80 座桥开始的 `-stress`，6 000 帧（`TSBRIDGE=80 TSGHOST=1 NXGAME=1 … -bot 1 -stress`：所有槽位都被占用、全速、一直开火）：平均约 108 000，最多约 144 000。

工作量从 `apply_done` 计到 `frame_done`（不计等待帧中断）；下面的各部分还包括 `apply` 和中断（约 7 000）。

按部分（A / B）：

| 部分 | A | B |
|---|---|---|
| display：物体摆放与碰撞（`display`、`ds_*`、`dh_*`、`sp_*`、`hit_*`） | 38 300 | 51 000 |
| 河流的新行（`river_gen`、`render_line`、`span_line`、`line_done`、`push_line`） | 13 600 | 32 200 |
| 精灵和河岸事件（`build_sprites`、`ob_*`、`pl_*`、`obj_lookup`、`sfile_put`、`build_events`、`pal_get`） | 10 300 | 14 900 |
| `apply`、面板和中断（`apply`、`panel_frame`、`panel_draw`、`pc_*`、`pal_edges`、`irq`、面板打印） | 7 900 | 7 500 |
| 声音（`sound_driver`、`snd_*`、`gs_*`；没有卡时 `ay_*`：A 中约 5 800） | 3 400 | 3 500 |
| 游戏逻辑及其他（`move_objects`、`main_loop`、`random_step`、`vbi`……） | 7 000 | 8 800 |

最耗时的例程（A / B）：

| 例程 | A | B | 文件 |
|---|---|---|---|
| `display`（自身代码） | 11 200 | 12 900 | display_simple |
| `dh_pf` | 8 700 | 9 800 | display_hits |
| `span_line` | 3 900 | 9 500 | spans |
| `ds_edge_test` | 2 800 | 8 700 | display_simple |
| `render_line` | 3 500 | 8 400 | render |
| `ds_obj` | 5 300 | 6 200 | display_objs |
| `dh_obj` | 4 400 | 5 500 | display_hits |
| `ob_attr` | 2 500 | 5 100 | sprites |
| `move_objects` | 1 700 | 3 300 | game |
| `dl_fill` | 1 500 | 3 300 | river_gen |
| `ob_list` | 2 400 | 3 200 | sprites |
| `line_done`（复制到屏幕内存，仅校验构建） | 1 100 | 2 500 | game |
| `gs_send` + `gs_wait_c` + `gs_wait_d` | 2 400 | 2 300 | sound_gs |
| `pl_keep` | 800 | 1 600 | sprites |
| `panel_frame` | 1 600 | 1 600 | panel_ts |
| `irq` | 1 400 | 1 400 | river_raid |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `sfile_put` | 1 200 | 1 300 | river_raid |
| `apply`（自身代码） | 1 200 | 1 200 | river_raid |
| `pal_edges` | 1 100 | 1 100 | river_raid |
| `build_events` | 1 000 | 1 000 | river_raid |
| `hit_setup` | 500 | 700 | display_hits |

在 7 MHz（`TSSPEED=1`，每帧约 143 400 周期）下工作量是同样的指令：`-stress` 平均约 93 000，最多约
125 000，刚好放得下；3.5 MHz 下不够。`gs_send` 要等卡读走每个字节（14 MHz 下每字节约 300 周期）。

（`prof.py` 用地址下方最近的全局标号作为例程名。低于 $4000 的地址是 INIT_PAGE 中的启动工作：不计。）

## 代码运行时的内存

16K 窗口以及其中的页（板子的 16K 页）：

| 窗口 | 地址 | 平时 | 被谁换页 |
|---|---|---|---|
| 0 | $0000–$3FFF | 1（`ATARI_PAGE`）：位于原版地址的 Atari 内存 | 启动时：3（`INIT_PAGE`：`sprite_pics.asm`、`gs_load.asm`、`load_rom.asm` 在那里运行） |
| 1 | $4000–$7FFF | 5（`WORK_PAGE`）：从 $4000 起是各行的色段（`SPANS`，32 字节 × 256 行），从 $6000 起是缓冲区（`scan_*`、`edge_runs`、`ring_*`、`ds_objs`、`ov_exp2/4`、`eg_*`、`bg_*`、`line_*`、`edge_lo/hi`、`rnd_tab`），$7D00 处是系统字体 | `render_line`：河流图像的一页（32–47）；`panel_draw`/`pc_*`：面板图像（64–79）；启动时 tile 映射（7）、tile（8）、精灵图像（24–31）；之后总是换回 5 |
| 2 | $8000–$BFFF | 2（`CODE_PAGE`）：代码到约 $9FBF，从 $A000 起是卡带 | — |
| 3 | $C000–$FFFF | 6（`HIGH_PAGE`）：代码到约 $D7EC，然后 $E000 处是 FM 窗口（`CRAM_SHADOW`：CRAM $E000–$E1FF，SFILE $E200–$E3FF；写入同时也写到下面的 RAM），表和变量到约 $FD65，栈，$FE00 处的 IM 2 向量 | — |

图像：河流从第 32 页起（`VID_PAGE`，16 页：512 行，每行 512 字节，显示其中 320 点），面板从第 64 页起
（`VPANEL`），tile 映射在第 7 页，tile 的点在第 8 页，精灵的 512×512 点在第 24–31 页（`SGPAGE`）。
INIT_PAGE 的代码结束于约 $11DF，工作页的缓冲区到 $7C00。FM 窗口一直打开：$E000–$E3FF 不能挪作他用，
$E400–$E4FF 是它的寄存器（`palette_lo` 在那里，只读）。

## 一帧

`main_frame`（river_raid.asm），每帧：

1. 记下本帧画面要显示的内容（`scroll`、河岸边缘和水的颜色、当前玩家），`read_input`。
2. 平时：`prepare` → `display` → `build_sprites` → `build_events` → `main_loop` → `vbi` → `snd_frame`。重置期间（`busy`）：`display` → `build_sprites` → `build_events` → `clear_layer2_page` →（最后一帧 `finish_reset`）→ `vbi` → `snd_frame`。
3. `wait_frame`：HALT 直到帧中断到来（`frame_flag`），在面板下方的 `FRAME_LINE`。
4. `apply`：构建好的一切生效（滚动、声音、颜色、SFILE、顶部的河岸调色板，以及下一帧的中断事件）。
5. `panel_draw`：面板上变化的字符以及滚动字幕的新字符，画进它的图像（在 `apply` 之后：可能要花些时间，而面板从第 184 行起才可见）。

绘制画面时，中断会在 `apply` 设好的列表中每个事件处到来：EV_PAL（从下一行起的河流调色板）、EV_PANEL
（从第 184 行起的面板图像）、EV_GX（滚动字幕的 X），然后是帧中断。每个都在前一行的右边缘到来
（HSINT = 208），而 PALSEL、VPAGE、GYOFFS 在行末被采样，所以无论处理器速度如何、工作进行到哪里，
切换都是精确的。

---

## Next 的文件在这里的样子

从 `../src` 复制，相同的代码：

- `river_gen.asm`、`display_objs.asm`、`panel.asm`、`vars.inc`、`font.inc`、`random.inc`：未改动。
- `display.asm`、`display_simple.asm`、`spans.asm`：不映射 SPANS 页（删掉 `nextreg $52,SPAN_PAGE`：窗口 1 一直放着 SPANS）；`spans.asm` 去掉 `rl_fill`/`rl_next`（Next 上 `render_line` 的辅助例程）。
- `display_hits.asm`：`bsla de,b`（Z80N）改为 `shl_de_b`，一个 0–7 次 `sla e / rl d` 的循环（在 `hit_line` 中：每次检测最多多约 100 周期，每帧几百）。
- `game.asm`：`tm_colour` 写 BORDER（一个 CRAM 项：`TM_*` 是第 11 组从 2 起的空闲项，颜色由 `tm_cram` 设置），`TM_COLOUR` 只在 T 打开时才调用它；`push_line` 让 `scroll` 在 512 行的环中移动（9 位），并画到图像的 `scroll + RIVER_TOP` 行。
- `play.asm`：`clear_layer2_page` 用 TS-Conf 的（river_raid.asm，DMA）；`read_input` 没有 CAPS + 1（没有 60 Hz）、CAPS + 2（关闭声音）、CAPS + 3（速度）、第二个 Kempston 和 Mega Drive 手柄。
- `sound.asm`：只有 `sound_driver` 和 `sound_random`：`pokey_frame` 在 General Sound 上运行（`gs/`）。
- `render.asm`、`sprites.asm`、`sound_ay.asm`、`load_rom.asm`、`river_raid.asm`：TS-Conf 自己的（见下），做同样工作的地方沿用 Next 的名字。

前三组的例程在 [docs/CODE.zh.md](../docs/CODE.zh.md) 中描述；它们在这里的开销见上表。

## river_raid.asm：帧、启动、中断、颜色

主文件：板子的端口、内存、页、`include`、帧、中断、`apply`、河流调色板、变量和缓冲区。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `start` | 加载时 | 14 MHz 和缓存（SYSCONFIG $06），窗口 0 为 RAM（MEMCONFIG $0E），各页，`screen_black`，`load_rom`（SPG 构建），`init_tables`，`init_video`，精灵图像（`obj_pics`、`pl_pics`、`panel_pics`），`gs_load`，然后把 Atari 内存放到窗口 0，`panel_init`，`ay_quiet`，RANDOM 的种子，IM 2（向量在 $FE00），`restart`。 | 一次 |
| `restart` | `start` | `tv_setup`，清空画面（两半都用 DMA，并等待完成），帧中断设在 `FRAME_LINE`，`start_attract`，整个面板画好，落入 `main_frame`。 | 一次 |
| `main_frame` | 每帧 | 见 *一帧*。 | 340 / 340 |
| `wait_frame` | `main_frame` | HALT 直到下一次帧中断（先清 `frame_flag`：工作期间来的那次对 `apply` 已太晚；恰在 HALT 之前来的会把它送回判断处，`irq.frame`）：空闲，不是工作。 | — |
| `irq` | 中断 | 处理 `ev_ptr` 处的事件：EV_PAL 设 PALSEL；EV_PANEL 设 VPAGE = `VPANEL`，GYOFFS = 0，VCONFIG $8A（256 色，位图在 tile 和精灵之上）；EV_GX 设 GXOFFS；帧事件（EV_END）设 `frame_flag`。同一行的事件一起处理；然后把 VSINT 设到下一个事件的行（`vsint_set`），或帧事件的行。在帧事件时还把 `apply` 的画面寄存器和事件重新设好（`river_regs`、`ap_pal`、从 `ap_list` 起的 `ev_go`）：迟到的帧再显示一次上一帧。每条事件记录保存下一个事件的 VSINT 行，它最先写出（进入后约 150 个周期），然后是本事件的端口，然后在其余部分之前 EI：在 3.5 MHz（一行 224 个周期）下相邻行上的事件不会丢失。 | 1 400 / 1 400 |
| `vsint_set` | `irq`、`apply`、`restart` | VSINT = HL（9 位），保存在 `ev_line`。 | 340 / 330 |
| `apply` | `wait_frame` 之后 | GYOFFS = `show_scroll`，VPAGE 设为河流的，VCONFIG $81（16 色），GXOFFS 0；`snd_out`（AY 寄存器或发给卡的帧）；`panel_frame`；炮弹和飞机的颜色写入 CRAM；`sfile_put`；重置后清画面期间（从第二帧起）：河流全黑（颜色 0 的调色板，边缘和水为 0，只有面板事件）；否则 PALSEL 设为顶部的调色板（`ev_built`），`pal_edges`，面板事件复制到河岸事件之后（`ev_tail`）；把中断设到第一个事件（前后 DI）；`ev_show` = 刚设好的列表（`build_events` 写另一个）。 | 1 200 / 1 200 |
| `pal_get` | `build_events`、`apply` | Atari 颜色 E 对应的河流调色板（PALSEL 0–7）：每种河岸颜色都有自己的调色板，首次出现时建立（`pal_of`、`pal_n`）：其颜色 1 为该色，写入 CRAM。超过 8 种时重复用最后一个（从未发生）。 | 110 / 110 |
| `pal_edges` | `apply` | 到目前为止建立的所有调色板的颜色 2 和 3（边缘、水）。 | 1 100 / 1 100 |
| `sfile_put` | `apply` | SFILE 在 `spr_list` 中拼好：河流的精灵（S0），其后复制 `sf_tail`（带 LEAP 的结束项、面板的 3 个：指针和标志，S1、结尾）；其后直到上一帧末尾（`sf_end`）的项也在那里清零；然后由 DMA 复制到 SFILE（DMACTRL $85，RAM 到 SFILE，一次突发；CPU 只负责设置）。DMA 忙时（复位时的清除）由 CPU 经 $E200 的 FM 窗口复制。 | 1 200 / 1 300 |
| `build_events` | `main_frame` | 逐行河岸颜色，与 Next 的 `build_copper` 一样来自 `ds_bank_ev`：写入中断不读的那个缓冲（`ev_a`/`ev_b`），河流顶部的调色板，然后每次变化一个 EV_PAL 事件，5 字节（类型、调色板、供校验的颜色、提前一行的 VSINT 行）；`ev_tail` 是 apply 放面板两个事件的位置。 | 1 000 / 1 000 |
| `clear_layer2_page` | `busy` 期间的 `main_frame`、`restart` | 每帧用 DMA 填充清半幅河流图像（256 行 × 160 字节，4 页）（DMACTRL $14，从 `dma_zero` 起 80 字 × 256 行）；重置第一帧不做（`l2_wait`）；DMA 忙时不做。处理器只负责编程（约 150 周期）。 | |
| `dma_wait` | `restart`、`init_video` | 等 DMA 空闲（DMACTRL 第 7 位）。 | |
| `init_tables` | `start` | 与 Next 的一样（`edge_runs_init`、`ov_exp2/4`、`ring_*`、`span_class`、`edge_lo/hi`、`span_init`），`pix_tab` 的索引放在两个半字节中（16 色模式每字节 2 点）。 | 一次 |
| `init_video` | `start` | 河流模式（VPAGE 32，VCONFIG $81，PALSEL 0）；tile 映射（第 7 页：第 0–23 行 tile 1 黑色，184 行 tile 3 灰色上方的一条黑线，185–223 行 tile 2 灰色，224–239 行黑色；河流的行没有 tile）和 tile 的点（第 8 页）；精灵的 128K 用 DMA 清零；TSCONFIG $A0（打开 tile 层 0 和精灵）；FM 窗口永久打开，CRAM 和 SFILE 清零；坦克的颜色；HSINT，只开帧中断（INTMASK 1）。 | 一次 |
| `screen_black` | `start` 的第一步 | TSCONFIG 0，BORDER 0，经 FM 窗口把 CRAM 和 SFILE 的全部 1K 清零：无论 Wild Commander 留下什么模式都变黑（它在第 5 页的 ZX 屏幕正是启动缓冲区所在之处）。 | 一次 |
| `tv_setup` | `restart` | 只有 PAL：`init_line_tables`，RANDOM 的 PAL 列，`rnd_tables`。 | |
| `test_ghost` | 测试构建 | tscheck 的 TSGHOST，与 Next 上一样。 | |

`span_rec`（HL = SPANS 中某一行的记录）与 Next 上是同一个宏，位于 $4000。

## render.asm：一行写入图像

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `render_line` | `line_done` | 把这一行的色钟 20–179 写到图像的第 HL 行（0–511）：第 `VID_PAGE` + 行 / 64 页映射到窗口 1，行位于 $4000 + (行 & 63) × 256；依据 `dl_seg` 中的各段，与 Next 上一样：同值段就是其 `pix_tab` 字节每个源字节写 4 次（`.fill`：`ld (hl),a / inc l`），边缘的字节（ROM 表）和装饰的一行经 `pix_tab` 转换，每个输出 4 字节。每行沿行 160 次写入（Next 沿列写 320 次、跨 10 页）。结束时换回 WORK_PAGE。5 字节及以上的同值段（`RL_DMA_MIN`）在 DMA 空闲时改由它来做：从 `rl_word`（该值两次）填充（DMACTRL $04）到 `rl_page` 页。在 $C000 页（为腾出空间从 $8000 移来）。 | 3 500 / 8 400 |

## sprites.asm：河流的精灵

TS-Conf 的精灵不能缩放，所以每个图像都保存 16、32 和 64 点宽三种（一个 Atari 像素是 2 点；一个 player
在尺寸 ×1、×2、×4 时为 8 像素）。一个物体是一个最多 24 行的精灵（Next 每 16 行一个）。调色板：物体
14 和 15（`OBJ_PAL_A`、`OBJ_PAL_B`，各行颜色放在位置 1–15），炮弹和导弹 8，坦克 9，飞机和子弹 10。
各项（每项 6 字节，SFILE 格式：Y 带 YS 和 ACT，X 带 XS 和镜像位，tile 和调色板）写入 `spr_list`；由
`apply` 复制。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`；然后飞机、它的子弹、坦克、直升机的导弹、炮弹（`drawRiver` 绘制它们的顺序），经 `pl_pattern` + `pl_sprite`；`pl_keep`。重置期间 `pl_again`。 | 800 / 800 |
| `ob_list` | `build_sprites` | `ds_objs` 中有行（`ds_objf`）的每一项：用顶行的形状和颜色地址做 `obj_lookup`；找不到：没有精灵；第一行在河流下方：没有；否则 `ob_attr`。 | 2 400 / 3 100 |
| `obj_lookup` | `ob_list` | 由 $B900 + E 处的形状字节和 $B700 + D 处的颜色字节找到图像：`obj_head`（按形状字节），再沿 `obj_e` 中的链查找；A = 图像 + 第 7 位表示 `OBJ_PAL_B`。 | 1 000 / 1 300 |
| `ob_attr` | `ob_list` | SFILE 项：Y = `RIVER_TOP` + 其行在河流中的位置（9 位），带来自 `pic_h` 的 YS 和 ACT；X = 2 × (位置 − 52)（9 位），按尺寸带 XS 1、3 或 7；合适宽度的 tile（`pic_tn16/32/64_lo/hi`），调色板。 | 2 500 / 5 200 |
| `pl_pattern`、`pl_sprite` | `build_sprites` | 从表中取本帧图像（$FF：没有）；一个 16 点宽的精灵，在第 D 行（在河流下方则没有），位置 E，调色板 C。 | 每个精灵约 100 |
| `pl_keep`、`pl_again` | `build_sprites` | 保存 player 的各项；重置的帧会再次显示它们（与 Next 一样）。 | 800 / 1 600 |
| `cram_set` | 启动、`init_video` | CRAM 项 A × 16 + B = Atari 颜色 E（`palette_lo`）。 | |

## sprite_pics.asm（INIT_PAGE，启动时）：精灵图像

经窗口 1 写入 512×512 点的图像内存（SGPAGE，每点 4 位，一行 256 字节）；图像的 tile 为 8×8，编号为
(行 / 8) × 64 + x / 8。

| 例程 | 调用 | 做什么、怎么做 |
|---|---|---|
| `gfx_alloc` | `pic_set`、`pl_pics`、`panel_pics` | 为 BC 点宽、A 行高（8 的倍数）的图像找位置：在当前行带上横向放置，放不下时换到下面的行（`gfx_cx`、`gfx_cy`、`gfx_rh`）。 |
| `gfx_tile` | | 一个点所在的 tile 号。 |
| `gfx_row` | | 图像的第 C 行：字节 D 的各点（第 7 位在前）以颜色 E 写成三种宽度（每位 2、4、8 点），或只写第一种（B 1）。 |
| `obj_pics` | `start` | 与 Next 的 `obj_pics` 一样：对类型 7–15，它们可能具有的外观类型（自身的，`ROM_NEXT_KIND` 中低于 $0C 的，爆炸的），每种还有镜像，height + 1 行，与 DLI 绘制的一样；每个图像（按其地址）只画一次，三种宽度；点的值为其行颜色在调色板 14 或 15 中的位置（新出现时设置：`cram_set`）；`obj_head`/`obj_e` 供 `obj_lookup` 使用。 |
| `pic_set` | `obj_pics` | 图像 `op_p` 的三个 tile（在 gfx_x、+ 16、+ 48）及其 YS。 |
| `pl_pics` | `start` | 飞机的 10 帧、坦克的 8 帧、炮弹的 7 帧（来自 ROM 中它们的指针表，与 `prepare` 复制的一样）、子弹和直升机的导弹：16 点宽，颜色 1；每个地址一个图像，空帧为 $FF。 |
| `panel_pics` | `start` | 指针（导弹 1：2 个色钟，10 行）和标志：player 3 在 64 点处（数据 $FC），player 2（数据 $FF）每行向左偏一个色钟（7 行，占 32 点）。 |

## panel_ts.asm：面板和滚动字幕

面板是一幅独立的图像（第 64–79 页，256 色，每行 512 字节），从屏幕第 184 行起显示（帧中断的
EV_PANEL），位图在 tile 和精灵之上（GFXOVR）：值为 0 的点是透明孔，透出 tile 层 0（灰色、黑色）和面板
的精灵。颜色 4–7 为面板的 PF0–PF3，8 为滚动字幕的颜色。滚动字幕是图像 512 点上 32 个字符的环，通过
GXOFFS 显示（在其第一行的 EV_GX）。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `panel_init` | `start` | 在游戏构建 Atari 两套字符集的位置（A0FB–A143：滚动字幕的在 $0600，面板的在 $0800）构建它们；颜色（CRAM：字符颜色为调色板 0 的第 4–8 项，指针的颜色，来自 $B48D 的标志各行，tile 的黑和灰作为调色板 3 的第 14 和 15 项：河流调色板只用 0–3 项）；字符先画一次（`GLYPHS`：滚动字幕的，以及面板的 4 种颜色）供 `pc_put` 复制；清空面板图像；全部标记为在第一帧写入。 | 一次 |
| `panel_frame` | `apply` | 滚动字幕的 X（`pf_gx` = 16 TEXT_LO + 38 − 2 FINE_SCROLL，9 位），供中断的 EV_GX 使用；指针（导弹 1 在 fuel / 8 + $5C）和标志的两个精灵写入 `spr_s1`（`.spr`）。 | 1 600 / 1 600 |
| `panel_draw` | `apply` 之后 | `panel_put` 列出的字符（`pf_dirty`，复制之后为全部 60 个），经 `panel_frame.char`；滚动字幕：TEXT_LO 前进一格时，写其后第 24 个字符；跳变时写全部 25 个（`panel_frame.text`：字符 t 在环的第 16 t mod 512 点）。 | 160 / 160（+ `pc_*`） |
| `pc_put` | `.char`、`.text` | 用 DMA 把一个字符从其预先画好的位置（`pc_bank`）复制到面板图像的第 E 行、第 HL 点；DMA 忙时（重置时的清屏）改由 `pc_draw` 绘制。 | |
| `pc_draw` | `pc_put`、`panel_init` | 绘制一个字符的 8 行：亮点用颜色 B，其余为 0（透明孔）；0 点左边的点不画。 | A 中 700 |
| `pc_bank`、`pc_adr`、`pc_reg` | | 字形画在哪里；某一行的页和地址；把一个地址写入 DMA 寄存器。 | |

## sound.asm、sound_gs.asm、gs_load.asm 和 gs/：General Sound 上的声音

Next 的 `pokey_frame`（其采样、脉冲、17 位计数器）运行在卡自己的 12 MHz Z80 上；主处理器每帧发送一次
POKEY 寄存器。

| 例程 | 调用 | 做什么、怎么做 | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | 原版的驱动（与 Next 上一样）。 | 840 / 1 000 |
| `snd_frame` | `main_frame` | 有卡时什么也不做；否则 `ay_frame`。 | |
| `snd_out` | `apply` | 有卡时 `gs_send`；否则 `ay_out`。 | |
| `gs_send` | `snd_out` | 向端口 $BB 发命令 `GS_FRAME`（$A5），然后向 $B3 发 AUDF1–4 和 AUDC1–4，每个都在卡读走前一个之后（`gs_wait_c`：$BB 第 0 位清零；`gs_wait_d`：第 7 位）。超时（约 0.2 秒）：放弃该卡（`gs_on` 0），此后改用 AY。大部分时间是在等卡。 | 2 400 / 2 400 |
| `gs_load` | `start`（INIT_PAGE） | 命令 $F0（固件状态）：无应答则没有卡；`GS_READY`（$5A）表示程序在上次运行时已加载，直接继续使用。否则通过固件：#12 第 2 页到 $8000，#18 地址，#19/#1B 程序字节（`gs_prog`：用 incbin 引入 `build/gs_pokey.bin`），#13 跳到 `GS_ORG`（$8400），然后等待 `GS_READY`（程序先生成它的表）。`gs_on` = 1。 | 一次 |

卡上的程序 `gs/gs_pokey.asm`（单独构建为 `build/gs_pokey.bin`）：

| 例程 | 做什么、怎么做 |
|---|---|
| `gs_start` | IM 2（所有向量指向 `INT_AT` $4141，处理程序复制到那里），变量清零，$6000–$63FF 每个字节等于其自身的值（读 $6000 + 256 (n − 1) + v 会把 v 锁存到 DAC n），四个音量都设为 63；`poly_make`，`tables_make`，环形缓冲静音，输出 `GS_READY`。 |
| `main` | 等待命令：$F4（`GS_RESET`）DI、IM 1、JP 0（回到固件）；$F0（`GS_STATE`）回应 `GS_READY`；其他命令则读入 8 个数据字节到 `pokey_audf`/`pokey_audc`，然后 `pokey_frame`。 |
| `gs_int` | 卡的中断，每秒 37 500 次：一个 DDA（`DDA_STEP` 108/256）每秒 15 820 次从环形缓冲取一个采样，锁存到全部四个 DAC（`ld a,(hl)`，地址为 $6000、$6100、$6200、$6300 + 电平）：1 和 2 在左，3 和 4 在右，每侧是两路之和。 |
| `poly_make` | 由递推 q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) 及其初值生成 POKEY 17 位计数器的位，放在 $C000–$FFFF（16K）；Next 从 `poly17.bin` 读取（卡上的程序放不下 16K）。 |
| `tables_make` | `snd_tables`、`snd_mod15/31`、`g4_tab`（与 Next 的 `sound_init7` 一样）。 |
| `pokey_frame`、`snd_fill`、`snd_sum` | Next 的那些，去掉 AY、zxnDMA 和时间限制，且每级音量为 4 而不是 8：这里四个通道都在（Next 上音调由 AY 承担），最高 60 × 4 = 240；用 8 时爆炸叠加会超过 255（嘶嘶声），而每侧两个 DAC 给出相同的音量。另外：采样领先中断位置（`rp`）最多到 `SND_LEAD`，最多 `SND_CAP`，超出部分保持最后的电平（`SND_HOLD`）。 |
| `gs_pulses.asm`、`gs_handlers.asm` | Next 的 `sound_pulses.asm`、`sound_handlers.asm`：17 位计数器的指针在 $C0 回绕（其 16K 在 $C000），且不用 `mul`。 |

它的内存：$4000 向量，$4141 处理程序，从 $4200 起变量，$4300 `snd_tables`，$4400/$4500
`snd_mod15/31`，`g4_tab` 结束于 $4800，栈在 $6000 以下；第 2 页在 $8000：环形缓冲 $8000–$83FF，程序从
$8400 起；$C000 是 17 位计数器的位。

## sound_ay.asm：没有卡时的纯音

| 例程 | 调用 | 做什么、怎么做 | A |
|---|---|---|---|
| `ay_frame` | `snd_frame` | 与 Next 上一样：演奏纯音的 POKEY 通道，各分配一个 AY 通道（1 第二片的 A，2 其 B，3 第一片的 B，4 其 C），N = (AUDF + 1) × 3.454 用加法计算（`3a + round(a × 116 / 256)`，不用 `mul`），音量经 `ay_vol`；写入 `ay_regs`。没有 2 帧延迟：没有需要对齐的 DAC，`apply` 直接输出本帧的寄存器。 | 1 100 |
| `ay_out` | `snd_out` | 两片芯片的寄存器 0–10（端口 $FFFD 选择芯片和寄存器，$BFFD 写值）。 | 2 100（+ 600 `ay_clear`） |
| `ay_quiet` | `start` | 全部静音。 | |

## load_rom.asm（INIT_PAGE，SPG 构建）：从 SD 卡读取卡带

Wild Commander 启动 .spg 时既不提供目录也不提供 DOS，所以程序自己通过 Z-controller 读卡（端口 $77 第 1 位
是其 /CS，端口 $57 双向各一个字节）。扇区缓冲是 SPANS（启动后会重建）。

| 例程 | 做什么、怎么做 |
|---|---|
| `load_rom` | `sd_init`，MBR 的第一个分区（没有分区表时就是卡本身：`lr_bpb`），FAT 卷的参数，从根目录 `lr_search`；把文件的各簇读到 $A000（8192 字节）。找不到时 `lr_fail`：CRAM 第 1 项设为红色并 BORDER 1，然后停止。 |
| `sd_init`、`sd_cmd`、`sd_read` | SPI 模式（CMD0、CMD8、CMD55 + ACMD41、CMD58：SDHC 用块地址，否则 CMD16 512 并用字节地址，`lr_hc`），读一个 512 字节扇区。 |
| `lr_bpb` | 引导扇区：FAT16 或 FAT32，每簇扇区数，FAT、根目录和数据区的地址。 |
| `lr_search`、`lr_get`、`lr_advance`、`lr_rewind` | 依次读取目录项（FAT16 的固定根目录或一条簇链）；先文件后目录，深度优先，最多 8 层（`lr_save`/`lr_restore` 保存路径）。 |
| `lr_lfn`、`lr_name`、`lr_upper` | 由 LFN 项（每项 13 个字符）拼出长文件名，与 RIVER_RAID.ROM 做不区分大小写的比较；否则用短文件名 RIVER_~1.ROM。 |
| `lr_next`、`lr_clus_lba` | 从 FAT 取簇链的下一簇（16 或 32 位）；一个簇的第一个扇区。 |

## 包含文件和工具

- `palette_ts.inc`：Atari 颜色 → CRAM 字（每分量 5 位，电平 0–24），C++ 移植版的 PAL 颜色（`make palette`：`tools/mkpalette_ts`）。
- `vars.inc`、`font.inc`、`random.inc`：Next 的那些。
- `gs/poly.inc`：POKEY 的 4 位和 5 位序列（`tools/mkpoly`）。
- `tools/mkspg.py`：由各页（`spg_page2/6/5/3.bin`）生成 SPG 1.0 文件：$8000–$9FFF、$C000–$FFFF、字体、INIT_PAGE 的代码。
- `tools/tscheck.cpp`：Xpeccy+ 的 TSConf 核心（及其 General Sound）与 C++ 移植版并行运行，逐帧比较。

## 修改代码前要知道的事

- **共用代码**：对游戏的修改（逻辑、生成器、display、碰撞）先改 C++ 移植版，再改 Next 的 `src/`，最后改这里的拷贝（`diff ../src/X.asm src/X.asm` 只会显示上面列出的改动）。只关于 TS-Conf 如何显示的修改留在这里。
- **窗口 1** 平时是 WORK_PAGE，只有 `render_line`、`panel_draw` 或启动代码会在其中映射别的页；它们都会换回 WORK_PAGE（SPANS 和缓冲区在那里）。
- **$E000 处的 FM 窗口**一直打开：写 $E000–$E3FF 会写到 CRAM 和 SFILE（同时也写到下面的 RAM，`apply` 就是这样读回它们的）；绝不要在那里放别的东西。
- **中断事件**有两个缓冲（`ev_a`、`ev_b`）：`build_events` 写 `ev_show` 没有指向的那个；`apply` 在 DI 下启用它。
- **在行末采样的寄存器**（PALSEL、VPAGE、GYOFFS、GXOFFS）：在前一行的中断里设置；中断在 HSINT 208（右边缘）到来，所以在 3.5–14 MHz 下都来得及。
- **DMA** 由清画面（`clear_layer2_page`）和面板字符（`pc_put`）共用：DMA 忙时 `pc_put` 用处理器绘制；SFILE 的复制（`sfile_put`）和新行的长段（`render_line`）也用它，DMA 忙时各自改用处理器。
- **校验**：`make check`（3 000 帧；`FRAMES=`），以及带 bot、`-stress`、TSBRIDGE、TSSPEED=1（7 MHz）、TSGS=neo 或 0 的运行，见 [README.zh.md](README.zh.md)。每次修改后都逐帧比较：状态、逐行河岸颜色（`ev_built`）、General Sound 的寄存器以及机器每帧的图像（逐像素）。
- **测量**：`TSHISTALL=文件`（整个运行中每条指令的时间，包括启动、中断和等待），然后 `python3 ../tools/prof.py build/test.sym 文件 60`；工作量的平均和最大值在 tscheck 输出的最后几行。`TSMSHOT=k` 写出从第 k 帧起机器的每一帧（32 帧，包括迟到帧的第二帧）；`TSBORDER=1` 打开 T；`TSSHOT=k` 加 `TSFULL=1` 写出从 k 起带边框的帧（一次运行的最后一张图边框只有一种颜色：运行停在 `apply_done`）。`TSTIME=N` 打印第 N−2..N+2 帧的工作量。`TSVOL=1`：各帧 POKEY 音量之和以及卡的最高电平（必须保持在 255 以内）。
