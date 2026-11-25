# River Raid（Atari 8 位机）→ ZX Spectrum Next（及 TS-Conf）：项目状态

[English](HANDOFF.md) | [Русский](HANDOFF.ru.md) | [Українська](HANDOFF.uk.md) | [Deutsch](HANDOFF.de.md) | [Polski](HANDOFF.pl.md) | [Italiano](HANDOFF.it.md) | [Español](HANDOFF.es.md) | 中文 | [日本語](HANDOFF.ja.md)

这个文件用于在任何电脑上或新的对话中接手工作。新会话请以“阅读 HANDOFF.zh.md 和 docs/NOTES.zh.md”开始（TS-Conf 移植还要读 tsconf/README.zh.md, tsconf/NOTES.zh.md）。

## 目标
River Raid（Activision，Atari 800，1983，作者 Carol Shaw）在 ZX Spectrum Next 上运行，基于 [djdron/river_raid](https://github.com/djdron/river_raid) 中的 C++ 移植：
- 游戏逻辑与原版一致，逐帧相同：同样的 RAM、同样的地址，与 C++ 移植及原版本身核对；
- 画面使用 Next 的硬件（Layer 2、精灵、tilemap、Copper），与 C++ 移植画出的逐像素相同；
- 时间上：一帧的工作在 28 MHz 下放进一个 50 Hz 帧之内；
- 不分发任何原版资源：程序在运行时读取用户的 ROM。

## 状态
游戏已完整，带声音：演示模式（attract mode）、游戏 1–8、单人和双人、飞机、燃料、敌人、坦克、导弹、桥、得分、生命、最高分、暂停、面板以及带彩虹标志的滚动字幕。默认 PAL（50 Hz），CAPS + 1 切换为 NTSC（60 Hz）。已与 C++ 移植逐帧核对（机器人游戏，几十万帧，PAL 和 NTSC，第 1–200 座桥），并在 libatari800 上与原版核对。尚未在真正的 Next 上运行：只在 Xpeccy+ 的 Next 内核上运行过。

DLI 已经完全没有了，它的时钟周期和它的循环都没有了：每个物体位于它自己位置（slot）的 y 上，按河流裁剪；碰撞是简单的几何计算（先矩形框，再点），只要精灵和物体的行在任何地方接触就算。这稍微改变了游戏：原版按窗口读取碰撞寄存器（从一次 HITCLR 到一次读取，逐个物体），会漏掉一些接触或晚一帧才看到；在机器人的长时间运行中测得 0.01–0.25% 的帧判定不同，总是原版晚一帧看到或根本看不到的接触（子弹在物体的最后一行上，飞机或坦克在最后一次读取之下的行）。先在 C++ 移植的 `displayGeometry` 中实现（`dli_removed` 分支，那里的默认方式；原版的读取方式保留为 `RR_DISPLAY=simple`），然后在这里实现，并与之逐帧核对。以前物体由 DLI 的计数器放置：12 万帧中它从未落后于任何物体，所以放置结果相同；旧的时间表保存在 git 历史和 C++ 移植的 `dli_removal` 分支中。

速度（一帧的工作，以内核时钟周期计；一个 60 Hz 帧在 28 MHz 下约 481 000，14 MHz 下约 240 000；50 Hz 约 567 000 / 约 283 000）：最重的负载，从第 80 座桥开始的 `-stress`（所有位置占满、全速、一直开火），NTSC 14 MHz 下平均约 131 000，最多约 165 000（余量约 75 000，约 30%）；28 MHz 下 NTSC 约 160 000 / 约 202 000，PAL 约 159 000 / 约 198 000（28 MHz 的周期数包含内存等待）。最重的帧：声音最多约 60 000（DAC 上的噪声和导弹，每帧约 180 个脉冲），物体放置和岸边测试约 30 000，精灵碰撞约 25 000，河流的新行约 25 000（`render_line`、`rl_fill`、`span_line`）。`apply`（在滚动字幕下方）约 7 400。

两个移植的概述：[README.zh.md](README.zh.md)；Next 的操作、构建和检查：[NEXT.zh.md](NEXT.zh.md)。

## TS-Conf 移植（tsconf/）
移植到 TS-Conf（ZX Evolution / Pentevo），是 `tsconf/` 中有自己构建的独立项目（`make -C tsconf`；只共用 `deps/`）；详情见 [tsconf/README.zh.md](tsconf/README.zh.md)。那里的游戏也已完整：演示模式、游戏、面板、滚动字幕、声音。用 `tsconf/build/tools/tscheck` 在 Xpeccy+ 的 TSConf 内核上检查：每帧之后与 C++ 移植比较（状态、逐行的河岸颜色、面板），并逐像素比较机器每一帧的画面；演示模式 10 000 帧，机器人，从第 80 座桥开始在 14 和 7 MHz 下的 `-stress`，有和没有 General Sound，以及 NeoGS。尚未在真正的主板上运行；用户在自己的 Xpeccy+ 中从 Wild Commander 启动 SPG。

- **代码**：游戏逻辑、display、河流生成器和碰撞是 Next 源码在 `tsconf/src/` 中的副本（`mul` 换成移位，`bsla de,b` 换成 `shl_de_b`）；行为改动先进 C++ 移植，再进 Next，再进这里的副本。TS-Conf 自己的部分：`river_raid.asm`（内存、帧循环、`apply`、`irq`）、`render.asm`、`sprites.asm`、`sprite_pics.asm`、`panel_ts.asm`、`load_rom.asm`、`sound_ay.asm`、`sound_gs.asm`、`gs_load.asm` 以及 `gs/`（General Sound 的程序）。
- **内存**（16K 窗口，MEMCONFIG $0E：$0000 为 RAM）：$0000 Atari 的 RAM（第 1 页；启动期间是存放启动工作的第 3 页），$4000 行的游程和缓冲区（第 5 页），$8000 代码和从 $A000 起的卡带（第 2 页），$C000 代码、缓冲区、栈（第 6 页）；河流画面从第 32 页起（16 色，一行 256 字节，512 行成环，由 GYOFFS 卷动），面板画面从第 64 页起，图块映射第 7 页，图块第 8 页，精灵从第 24 页起。14 MHz 并开启缓存（SYSCONFIG $06）。
- **逐行的河岸颜色**：一个调色板（PALSEL 0），河岸颜色固定在其中（两种绿色和桥边道路的颜色：第 1、9-15 项）；每个新行的河岸点画成其颜色对应的那一项（`line_bank`，同 C++ 移植的 `lineBankColour`，只在桥边计算：`road_row`；两种绿色的点表一直在，道路行经第一种绿色的表并替换河岸点；每行不切换任何东西），所以颜色跟着行走，中断每帧只来三次（面板、滚动字幕的 X、帧）。用户的主意。之前：每种颜色一个调色板，中断在帧中往下移动来设 PALSEL（更早是逐行写 CRAM，在 7 MHz 下出错）。
- **精灵**：启动时生成 16、32 和 64 点宽的物体（不能缩放），player 和 missile；S0 在图块层 0 之下，燃料指针和标志（S1）在面板之上。
- **面板**：自己的 256 色画面，由中断在第 184 行切换进来（VPAGE、GYOFFS、VCONFIG、GFXOVR），字符在启动时画好，变化时由 DMA 复制，滚动字幕是 32 个字符的环，由 GXOFFS 显示。
- 复位后的**清除**：用 DMA，从复位的第二帧开始，期间河流的颜色为黑色（河流立即变黑，与 C++ 移植一样）。
- **DMA** 还每帧把精灵列表复制到 SFILE（`sfile_put`，来自 `spr_list`），并填充河流新行中 5 字节及以上的单色段（`render_line`）；它忙时（复位时的清除）由 CPU 来做。**T** 像 Next 一样在边框上显示一帧的工作（BORDER 取一个 CRAM 项：第 11 组从 2 起的空闲项，`tm_cram`；`panel_draw` 另用绿色）。**CAPS + 3** 切换处理器频率：14、7、3.5 MHz 轮流（SYSCONFIG，`cpu_spd`；程序以 14 启动）。
- **SPG**（给 Wild Commander 用的 SPG 1.0，`tools/mkspg.py`）：常驻部分在 $5B00（为 0 时 WC 不启动它）；程序自己在 SD 卡上任意位置找到 `River_Raid.rom`（Z-controller，FAT16/32，`load_rom.asm`）。GitHub workflow `tsconf` 构建它（构件 `river_raid.spg`）。
- **声音**：有 General Sound 时全部由它播放：声卡的 Z80 运行 Next 的 `pokey_frame` 和脉冲代码（`tsconf/gs/gs_pokey.asm`，约 1.9K 的程序位于第 2 页的 $8400，环在 $8000，17 位计数器的 16K 在 $C000 按递推公式 q(k) = q(k−9)^q(k−11)^q(k−12)^q(k−17) 生成），它的中断（每秒 37 500 次）在 256 次中取 108 次采样（每秒 15 820 个）送到全部四个声道，1 和 2 左，3 和 4 右，每级音量 4（四个声道都为 15 时电平 0-240；像 Next 那样每级 8 时，爆炸叠加会超过 255 而回绕：嘶嘶声）（单声道，用户的要求：AY 是立体声）。`gs_load`（启动时）询问声卡状态（$F0：程序回答 $5A，所以第二次运行会继续使用它），否则通过固件上传（#12 页，#18/#19/#1B 字节，#13 跳转）——不用 $F4 复位：在 Xpeccy+ 的 2M 声卡上固件启动约需 5 秒。`apply` 每帧发送一个命令和 8 个数据字节（AUDF1-4、AUDC1-4）；声卡不再应答时改用 AY。没有声卡时：纯音由 TurboSound 的两个 AY 播放（NedoPC；POKEY 1、2 用第二块芯片的 A、B；3、4 用第一块的 B、C），与 Next 相同。
- **速度**（14 MHz，每帧约 287 000）：演示模式平均约 65 000，最多约 178 000；`-stress` 第 80 座桥约 108 000 / 约 144 000；7 MHz 下（每帧约 143 000）`-stress` 约 93 000 / 约 125 000（够用，没有迟到的帧）；3.5 MHz 跟不上。
- **tscheck 环境变量**：TSGS（默认 gs，neo，0）、TSWAV / TSWAVCPP、TSSPEED、TSBRIDGE、TSGHOST、NXGAME、TSSHOT（加 TSFULL 为带边框的整帧）、TSBORDER（打开 T）、TSDIFF、TSTIME、TSBUSY；`-spg 文件 帧数 out.ppm -sd 文件夹` 用主机文件夹充当卡运行 SPG。
- **未决**：还没在真正的 Evo/Pentevo 上运行（键盘、Kempston、SD 读取、GS 和 NeoGS 的真实固件都按 Xpeccy+ 的模拟）；GS 程序一旦装进声卡就一直留到断电（更新的构建不会覆盖上传）；声音已与 C++ 移植做了数值比较（寄存器完全一致，音量包络相似度 0.96），用户在 Xpeccy+ 上试听。DMA 的 SFILE 复制和行填充以及 T 键只在 Xpeccy+ 上试过。

## 需要什么
- 整个项目文件夹；`make deps` 把 sjasmplus、C++ 移植和 Xpeccy+ 取到 `deps/`。
- 你自己的 ROM `River_Raid.rom`（8192 字节，无文件头），检查时放在 `rom/River_Raid.rom`；在 Next 上放在 .nex 旁边。

## 结构
| 路径 | 内容 |
|---|---|
| `src/river_raid.asm` | 程序：内存映射、启动和重新启动（PAL/NTSC）、帧循环、表、数据页；构建 .nex 或测试页 |
| `src/river_gen.asm` | 河流生成器（逐行对应 `river_gen.cpp`） |
| `src/game.asm` | 演示模式的开始、`prepare`、物体的移动、VBI（颜色、滚动字幕、POKEY 计数器） |
| `src/sound.asm`、`src/sound_pulses.asm`、`src/sound_ay.asm`、`src/sound_ay_run.asm` | 声音驱动（POKEY 寄存器）、AY 上的纯音、把 POKEY 仿真到 DMA 的环、DMA 和 DAC 的设置（声道的脉冲和 AY 的每帧代码在第 6 页：DMA 通过 MMU 读取 $7C00 处的环，所以声音播放时不能在 $6000-$7FFF 映射别的页） |
| `src/play.asm` | 主循环：操作、暂停、飞机、爆炸、坠毁、复位、新游戏 |
| `src/panel.asm` | 面板字符（第 6 页）：`panel_put` 只在字符变化时写入，并把它记入 `panel_frame` 的列表；`print_bcd`、`show_lives` 不打印已有的内容（`pb_cache`、`sl_last`） |
| `src/display_simple.asm` | display：每个物体在其槽位的 y 上（IY 指向游戏保存它各字段的地方；它的行进入 `ds_objs`），物体的碰撞（`dh_obj`），它的边缘（`ds_edge_test`） |
| `src/display_hits.asm` | 碰撞的几何计算：其他精灵的行来自 ROM 中的形状（`dh_lists`），每帧一次与河岸及彼此比较（`dh_sprites`：`dh_pf`、`dh_pair`），物体与子弹、炮弹、飞机比较（`dh_obj`）；两者共用一个测试：先矩形框，再移位后的点掩码（`hit_setup`、`hit_line`、`hit_wide`）；精灵按其各行两端与河岸或岸边比较（`sp_edge`、`sp_bank`、`sp_under`） |
| `src/display_objs.asm` | `ds_obj`（第 4 页，位于调色板对齐的空隙中） |
| `src/display.asm` | 带 `-DBEAM` 时：逐点的 playfield 测试（`pf_*`），旧的 DLI 周期模型和 collide 的逐点测试（已不再能构建） |
| `src/sprites.asm` | 物体、其他 player 和 missile 作为 4 位精灵（它们的图像在启动时生成：`obj_pics.asm`），Copper 的列表（面板部分），`apply`，`panel_frame`（面板变化的字符、滚动字幕的环和精灵、燃料指针和标志） |
| `src/spans.asm` | 每行河流的河岸和岸边像素游程，来自 draw_line 的片段（`dl_seg`：整块填充、装饰物的一行当作河岸、岸边的游程直接取自启动时由 `edge_runs_init` 生成的 `edge_runs`：不查看任何像素），以及这一行的空隙（岸边游程之间的水，`eg_*`；河岸游程之间最宽的两个，`bg_*`）；`rl_fill`、`rl_next`（render_line 用：第 4 页已满） |
| `src/load_rom.asm` | 启动时读取 `River_Raid.rom`（第 7 页） |
| `src/render.asm` | 直接从 draw_line 的片段把一行河流写入 Layer 2（填充用一种颜色，岸边和装饰行的字节从 ROM 经该行的一组点表转换：其河岸用其颜色的那一项）；游戏中没有行缓冲（`line_buf` 只在有屏幕内存时） |
| `src/bank_colours.asm`、`src/copper_panels.asm` | 每个新行的河岸颜色（`line_bank`：它的一组点表），Layer 2 的河岸各项（`bank_set`），Copper 的列表（`build_copper`）；两种制式下列表中面板的部分（第 7 页，由 `tv_setup` 复制） |
| `src/panel_init.asm` | 8K 第 7 页，仅在启动时：字符集、图块、固定的精灵图案、调色板 |
| `src/obj_pics.asm` | 第 7 页，仅在启动时：物体（`obj_pics`）以及其他 player 和 missile（`pl_pics`）的图像，作为 4 位精灵图案；物体的查找表 |
| `src/vars.inc` | 原版的 RAM 地址和 ROM 表 |
| `src/palette.inc`、`src/random.inc`、`src/font.inc`、`src/poly.inc`、`src/poly17.bin` | 由 `make palette` 生成（tools/mkpalette、mkrandom、mkfont、mkpoly） |
| `tools/nxcheck.cpp` | 检查：程序在 Xpeccy+ 的 Next 内核上运行，旁边运行 C++ 移植，或与 rr_oracle 的录制比较（`-oracle`） |
| `tools/check_original.sh` | `make check-original`：原版的八次运行 |
| `tools/prof.py` | 根据 nxcheck 的直方图统计各例程耗时 |
| [docs/NOTES.zh.md](docs/NOTES.zh.md) | 做法和发现，附数据 |
| [tsconf/NOTES.zh.md](tsconf/NOTES.zh.md) | TS-Conf 移植自己的部分：主板、中断、General Sound、启动，附数据 |
| [docs/HOW_IT_WORKS.zh.md](docs/HOW_IT_WORKS.zh.md) | Atari 的画面、碰撞和声音如何在 Next 和 TS-Conf 上实现，面向所有人 |
| [docs/CODE.zh.md](docs/CODE.zh.md) | 逐个例程介绍 Next 的汇编文件（游戏部分与 TS-Conf 共用）：做什么、何时、怎样做、各花多少周期 |
| [tsconf/CODE.zh.md](tsconf/CODE.zh.md) | TS-Conf 移植自己的文件（同样的写法）、对共用文件的改动，以及两台机器的区别 |

## 已确认的事实（全部核对过）
1. **相同的 RAM。** Atari 的 16 KB RAM 是位于 $0000–$3FFF 的 8K 第 30–31 页：每个变量都在原版的地址上。RAM 转储与原版和 C++ 移植逐字节比较（`Game::diffWithRam`）。
2. **卡带在它自己的地址上。** ROM 是位于 $A000–$BFFF 的第 5 页：表在原版读取它们的地方读取；程序里不含它的任何内容。
3. **没有 DLI。** 每个物体的行从 X = max(y, $5D) + 3（扫描行 X − 69）开始，数量为 X 回绕（河流结束）之前的行数：与 DLI 的循环放置它们的方式相同，而那个循环从未落后于任何物体（在 C++ 移植中核对了 12 万帧）。没有周期、没有读取、没有 HITCLR。
4. **碰撞是几何计算。** 游戏读取的是：P1PF（坦克，岸边）、P2PF（飞机，河岸）、M0PF 和 M2PF（导弹、子弹：河岸或岸边）、P3PF（物体，岸边，只对直升机、气球、船）、P2PL（飞机与炮弹和物体）、P3PL（炮弹，物体；不含桥）、M2PL（子弹，物体）、M0PL（导弹，飞机）。其他精灵的行只在游戏放置它们的地方（炮弹从 shellY 起 16 行，坦克从 tankY 起 11 行，飞机从 $AA 起 14 行，导弹是它那一行，子弹在 bulletY 下方 8 行），它们的位来自 ROM 中的形状（除 `-DBEAM` 外不再写 player-missile 内存）；只要在它们的行上任何地方发生就算碰撞；被击中的物体是屏幕上最靠下的那个。所有情况共用一个测试：先比较矩形框的色钟，再在两者都存在的每一行上，把它们的点（每个色钟一位）用桶形移位器（`bsla de,b`）移到窗口的第一个色钟，然后做 AND。物体的岸边（P3PF）：每一行先用它的矩形框与该行的水域空隙（`eg_*`）比较，否则用该行的第一个和最后一个点（`edge_lo`、`edge_hi`）与该行岸边的游程比较，不逐点比较（C++ 移植的 `edgeTouches`；2 万帧中从未与逐点测试不同）。其他精灵与河岸或岸边（`dh_pf`）也一样：每一行先用矩形框与空隙比较，否则用该行两端与所需颜色的游程比较（`sp_edge` 棕色，`sp_bank` 绿色，`sp_under` 任一；C++ 移植的 `spanTouches`）。
8. **不写 player-missile 内存。** 游戏中没有任何东西读回它：精灵的图像和碰撞的行都来自 ROM 中的形状（只有 `-DBEAM` 构建会写它）。
5. **POKEY 的 RANDOM** 是一个 17 位计数器；程序把它保持在游戏逻辑读取的位置（A205），每次 VBI 前进一帧（一个矩阵，NTSC 或 PAL）。
6. **PAL/NTSC** 与 C++ 移植相同：显示列表的结尾（面板行 190/194）、面板和标志的布局、复位帧数 13/8、补给站界限 $2E/$2F、RANDOM 的读取点、滚动字幕的起点、PAL 下游戏结束时 sub $B21A 之前的 VBI。
7. **游戏结束时的竞争。** 游戏结束时，原版的帧计数器落在其 VBI 之前还是之后取决于该帧的长度；C++ 移植以及本程序取通常情况。`make check-original` 中的两处差异就是这个。

## 环境限制
- sjasmplus 1.24.1（提交 5c44bea），Xpeccy+ 提交 0ec06e33，river_raid 提交 f9b51e5（`dli_removed` 分支）：`tools/get_deps.sh`。程序所跟随的 C++ 移植每有改动，都需要同时更新这个提交。Xpeccy+ 2026.10.1（用户的版本）会画出可见行之下、无窗口内核不画的行（`NXFULL=1` 写出整个帧缓冲）。
- Xpeccy+ 的 Next 内核通过 libxpeccy 无窗口使用：没有固件（调色板从 0 开始），不调用 `comp_power_on`；60 Hz 时画面从 Layer 2 的第 0 行开始，50 Hz 时从第 24 行开始。
- 检查需要 ROM；CI 只构建 .nex（构件不打成 zip）。
- 代码用制表符缩进。文档：`X.md` 英文，`X.ru.md` 俄文，以及 `X.uk.md`、`X.de.md`、`X.pl.md`、`X.it.md`、`X.es.md`、`X.zh.md`、`X.ja.md`（与 C++ 移植相同）。`tools/doc_languages.py` 在每个标题下写出语言行（新译文中那里写 LANGUAGES 一词）。文档的改动要进入所有语言。
- 提交：作者 `djdron <djdron@gmail.com>`，信息以 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 结尾，不带会话链接。

## 方法
凡是改变游戏行为的，都先在 C++ 移植（现在是 `dli_removed` 分支）中做、在那里检查、连同文档提交；然后移植到这里，用 nxcheck 检查，nxcheck 从 `deps/river_raid` 链接 C++ 移植（`tools/get_deps.sh` 固定提交）。在 `dli_removed` 上默认是 `displayGeometry`；`RR_DISPLAY=simple` 是原版的读取方式（与 `dli_removal` 相同，用 `game_check` 和 `rr_oracle` 与原版核对过），`RR_GEOMCHECK=1` 统计几何判定不同的帧（`=2` 逐个打印：什么、在哪里）。只涉及 Next 硬件的（精灵、Copper、表）只在这里做。

nxcheck 每帧之后检查：游戏状态、屏幕内存、画出的物体（`ds_objs` 对比 C++ 移植的 `drawn`）、Copper 的内存对比它的列表、每条河流行的河岸点在 Layer 2 中的调色板项对比 C++ 移植的 `lineBank`；最后逐像素比较画面。完整的一套（2 个核心上约 25 分钟）：`-pal` 和 `-ntsc` 各 3 000 帧，`-bot 2` 和 `-bot 3` 各 20 000，`-bot 8` 和 `-bot 9` 各 30 000，`-attract` 20 000，`NXGAME=7` PAL 和 NTSC 以及 `NXGAME=5` 各 10 000。后面的桥：`NXBRIDGE=n NXGHOST=1 NXGAME=1`（每局都从第 n 座桥开始，两边飞机都不会坠毁）。最重的帧：`-stress` 加 `NXBRIDGE=80 NXGHOST=1 NXGAME=1`（机器人全速、一直开火、不暂停；所有位置占满）。速度：`NXHISTALL`（所有帧）或 `NXHIST`（一帧）以及 `tools/prof.py`、`tools/prof_local.py`（按局部标签）；`NXSLOW=T` 列出超过 T 个周期的帧；`NXSPEED=2` 在 14 MHz 下运行。屏幕内存（`SCREEN_MEMORY`）只在检查用（`-DTEST`）和电子束构建中存在：要像游戏实际运行时那样测量检查用构建，用 `-DNOSCREEN` 构建并以 `NXNOSCREEN=1` 运行 nxcheck。`-DG4CHECK` 加 `NXG4=1` 检查 `pk_g4` 的计数器和表。做一个每帧把新方法与旧方法比较并统计差异的测试构建（碰撞行、游标和放置都是这样做的），是确认重写正确的最快方法。

## 决定
- 规范是 C++ 移植，而不是 6502 的列表：在 Z80 上速度相同、易读、已经核对过。
- 320x256 的 Layer 2 保存 playfield 的 2 位颜色索引，192 个色钟中的 160 个，每个两个点；岸边和水的颜色是调色板第 2、3 项，河岸颜色是第 1 项和第 4–10 项（只设一次：两种绿色和桥边道路的颜色），每行的河岸点画成其颜色的那一项（`line_bank`，只在桥边计算；两种绿色的点表一直在，`pix_set0`、`pix_set1`；每行不切换任何东西）。Copper 不再逐行改颜色（它的列表只在制式改变或颜色关/开时重做）。
- 每个物体是一个现成的精灵，各行带着各自的颜色（启动时生成的 4 位图案，`obj_pics`：一个点就是它那一行的颜色在精灵调色板第 14 或 15 组中的位置；根据它最上面一行的形状和颜色地址查找）；位于河流顶端之上的物体被完整画出，并由精灵的裁剪窗口裁掉。其他 player 和 missile 各是一个精灵，位于游戏给出的位置，它们的每一帧也是启动时生成的 4 位图案（`pl_pics`）；游戏过程中不向图案内存写入任何东西。
- display 遵循 C++ 移植的 displayGeometry：没有 DLI，碰撞用几何计算（0.01–0.25% 的帧与原版判定不同，早一帧）。为了 14 MHz 下的速度而选择：DLI 的时间表和读取在最重的帧中约 145 000 个周期，现在约 45 000。
- 衡量标准是最差的帧，而不是平均：只在没有变化时才跳过工作的捷径（面板的数字）对平均有帮助；能降低最差帧的是完全不做的工作（启动时生成的图像、滚动字幕的环、不需要 scan_bank 和屏幕内存）或每次都更便宜的工作（用空隙代替游程、用移位掩码代替逐点、不查表的填充）。
- 用到的 Z80N 指令：`nextreg`（到处）、`mul d,e`（AY 的周期，`g4_crt`）、`bsla de,b`（`hit_line`）。TS-Conf 移植的副本用移位和加法代替 `mul` 和 `bsla`。
- 滚动字幕是 tilemap 第 26 行中的一个环（半个字符 h 在第 h mod 40 列，X 卷动为 X0 mod 320；只写新的半字符）；回绕到右边缘的那一列在那里被 tilemap 的裁剪窗口切掉（S = X0 & 7 个点，每帧设置），由一个精灵（图案 20，调色板偏移 6）在那里显示下一个半字符，它的 64 字节只在变化时写入。面板字符只在变化时写入 tilemap（`panel_put`、`pf_dirty`）。Copper 在第 200 行之前保持 tilemap 的 Y 卷动为 0（这样无论它何时开始一帧，滚动字幕下方都不会出现面板的任何部分；以前 Xpeccy+ 2026.10.1 会在那里再次显示滚动字幕，现已确认不再出现）。
- 面板和滚动字幕是 tilemap；面板的灰色来自 Layer 2（在面板的行上由 Copper 把它的 0–10 号颜色变成灰色，它的裁剪窗口延伸到面板最后一条灰色行），所以和河流一样宽 320 点；后备颜色（fallback）保持黑色，边框也是。
- 画面是 Next 的 320 个点，色钟 20–179：C++ 移植显示 12–179（滚动字幕是全部 192）；左边的 8 个不显示（边框只能是单一颜色，精灵在它上面会消失）。演示模式中滚动字幕左边少 2 个字符，右边大约少 1 个。
- 像素的形状交给屏幕：Xpeccy+ 是正方形；C++ 移植 0.86（NTSC）/ 1.03（PAL）；真正的 Next 通过 HDMI 在 60 Hz 下约 0.89。
- 声音：DAC 增益为每单位音量 8（电平最高 240；只有音量之和超过 31、电平会回绕的帧才取 7–4），保持 C++ 移植中与 AY 纯音的平衡（在 YM 表的顶端）；单声道，与原版一样。在 Xpeccy+ 中大约是 C++ 移植响度的一半（Next 混音器中每侧一个 DAC；DAC 和 PSG 音量默认 80）。
- 复位后从复位的第二帧开始清除 Layer 2，清除期间用它的裁剪窗口隐藏（`l2_wait`、`l2_hidden`）：河流立即变黑，与 C++ 移植一样，没有横扫的条带。
- 帧在滚动字幕下方生效（光栅行 NTSC 208，PAL 220）。
- 默认 PAL；CAPS + 1 切换并重新开始，就像开机一样（Q A O P 中 P 是“右”）。
- 操作：Q A O P，空格/M 开火，Enter 为 START，G 为 SELECT，H 暂停；Kempston 1 和 2，Mega Drive 的 START 和 A。CAPS + 1 PAL/NTSC，CAPS + 2 声音关/开，CAPS + 3 28/14 MHz（NR $07：`cpu_14`；程序从 28 MHz 开始）。纯音在 AY 上播放（sound_ay_run.asm：每个 POKEY 声道有一个 AY 声道：1 是第二块 AY 的 A，2 是第三块的 A，3 是第一块的 B，4 是第一块的 C，与 DAC 的采样一样晚 2 帧）；其余（噪声、导弹、仅音量）在 DAC 上（曾尝试过全部用 AY 的模式并放弃了：AY 的噪声不能低于 N = 31，所以引擎只能保持一个音高，爆炸声只剩嘶嘶声）。屏幕内存只存在于 -DTEST 和 -DBEAM 构建中（SCREEN_MEMORY；用 -DNOSCREEN 加 NXNOSCREEN=1 测量不带它的检查用构建）；draw_line 把它的片段记录在 `dl_seg` 中，供 render_line 和 span_line 使用。T 键开关在边框上显示一帧的工作：从 `apply` 开始每部分用一种后备颜色（边框的颜色，以及没有任何层绘制的地方）（橙色 `apply`，灰色 `prepare`（以及复位期间的 `clear_layer2_page`），红色 `display`，黄色 `build_sprites`，蓝色 `main_loop`，品红 `push_line`（一行新的河流，在 `main_loop` 内），白色 `vbi`，青色 `pokey_frame`，黑色为剩余时间；`TM_*` 在 river_raid.asm 中，`TM_COLOUR`），所以从 `wait_line` 开始的彩色行就是各部分所用的时间。

## 未决问题
- 没有在真正的 Next 上试过；键盘和摇杆的读取没有检查过（检查程序直接给出操作）。速度是在 Xpeccy+ 的 Next 内核上测量的；真机在 28 MHz 下的内存等待没有检查。
- 声音只在 Xpeccy+ 上听过（那里的噼啪声是 DMA 读到了映射在环上方的另一页：已修复；播放时不能在 $6000-$7FFF 上映射任何东西）。没在真正的 Next 上：zxnDMA（突发模式、预分频 55、自动重启、读回地址）和端口 $DF 上的 DAC 都按 Xpeccy+ 内核对 VHDL 的模拟。
- ROM 现在由第 7 页中的 `load_rom` 读取（为腾出空间而移动）；测试构建中没有它，所以只能在真正的 Next 上检查。
- 碰撞用几何计算（见上）：玩家是否会注意到早一帧的接触还没试过；原版的读取方式可以作为选项恢复（C++ 移植保留了它们，`RR_DISPLAY=simple`；这里它们在 git 历史中）。
- 演示模式之前的开机过程（最初的 38/25 帧）不显示；程序从演示模式开始。

## 下一步
- DAC 上的声音（平均约 37 000，`-stress` 中最多约 60 000）：把 DAC 的采样率减半，或者把 AY 能准确播放的噪声（AUDF 17 及以下）放到 AY 上。
- `ds_edge_test`（重帧中约 14 000）：一次性用物体的矩形框对比它所有行的空隙；在没有唤醒的帧中跳过沉睡的物体（平均 −8 000，不是最差的帧；先在 C++ 移植中做）。
- `display`、`ds_obj`（约 21 000）、`dh_pf`（约 14 000）、河流的行（约 27 000）。
- C++ 移植 `dli_removed` 分支的文档（docs/DLI_REMOVAL.md：displayGeometry、edgeTouches）。
- 如果需要：AY 的纯音用立体声（NR $09）。
- 在真正的 Next 上运行（键盘、摇杆、DMA 声音、ROM 加载、带内存等待的速度）。
- TS-Conf：在真正的 Evo/Pentevo 上运行 SPG（有 General Sound 或 NeoGS，以及没有）。
