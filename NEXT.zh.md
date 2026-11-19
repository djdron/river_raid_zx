# River Raid：ZX Spectrum Next 移植

[English](NEXT.md) | [Русский](NEXT.ru.md) | [Українська](NEXT.uk.md) | [Deutsch](NEXT.de.md) | [Polski](NEXT.pl.md) | [Italiano](NEXT.it.md) | [Español](NEXT.es.md) | 中文 | [日本語](NEXT.ja.md)

[River Raid：现代 ZX Spectrum 移植](README.zh.md)的一部分；另一个移植：[TS-Conf](tsconf/README.zh.md)。许可证：[README.zh.md](README.zh.md#许可证)。

River Raid（Activision，Atari 8 位机，1983，作者 Carol Shaw）到 ZX Spectrum Next 的移植，基于 [djdron/river_raid](https://github.com/djdron/river_raid) 中的 C++ 移植：它弄清了原版如何完成每一件事，并与原版逐帧核对。

非官方的爱好者项目，用于学习目的，与 Activision 和 Microsoft 无关。项目中不包含游戏本身：程序在运行时读取你自己的卡带映像。

它在 Next 上如何工作（面向所有人）：[docs/HOW_IT_WORKS.zh.md](docs/HOW_IT_WORKS.zh.md)。接手工作：[HANDOFF.zh.md](HANDOFF.zh.md)；具体做法和数据：[docs/NOTES.zh.md](docs/NOTES.zh.md)；逐个例程的汇编源码（英文和俄文）：[docs/CODE.md](docs/CODE.md)。

## 状态

游戏完整，带声音。启动时运行演示模式（attract mode）；START 开始游戏：飞机飞行、转向、加速和减速、开火、消耗燃料并在补给站上空加油；敌人、桥和补给站会爆炸并得分；坦克向飞机开炮，直升机发射导弹；坠毁、从上一座桥出发的新飞机、每 10 000 分奖励一架飞机、游戏结束和最高分；SELECT 切换游戏（1-8：四个起始桥，单人或双人轮流），任意键暂停。河流下方是面板（得分、游戏编号、燃料表、生命、最高分或另一位玩家的得分、桥）以及带彩虹标志的滚动字幕，不在游戏时它滚动显示制作人员名单。每一帧都做原版所做的事（游戏逻辑、河流生成器，以及显示列表中断所显示的内容和它读取的碰撞，不运行它而直接算出），并与 C++ 移植逐帧核对。

声音：原版的声音驱动每帧设置 POKEY 的四个声道（与 C++ 移植核对）；POKEY 本身由软件仿真，它的输出写进一个采样环，由 zxnDMA 自行送往 DAC（每秒 15 909 个）。还没在真正的 Next 上听过：在 Xpeccy+ 的内核上能播放，检查程序会把它写成 WAV（`-wav`）。在 Xpeccy+ 中把 DAC 和 PSG 的音量设为 100（默认 80）：DAC 播放噪声，PSG（AY）播放纯音。

PAL 或 NTSC：程序以 PAL 版 Atari 启动（Next 为 50 Hz），CAPS + 1 切换到 NTSC 版（60 Hz）并可切回，就像重新开机一样。它们的差别与原版相同：NTSC 游戏快 17%（每秒 60 帧而不是 50 帧），面板和滚动字幕位置更高，坠毁后清理内存需要 13 帧而不是 8 帧，PAL 上从 $2F 级起补给站略少，等等（C++ 移植的 PAL 和 NTSC 变体）。

速度：在 28 MHz 下，游戏开始时一帧的工作平均约占 50 Hz 帧的 21%，最重的场景（所有敌人位置都被占满、全速、一直开火，从第 80 座桥开始）最多约 41%；无论 PAL 还是 NTSC 都没有迟到的帧。所以 14 MHz 下也能运行：即使最重的帧也只占 50 Hz 帧的约 83%、60 Hz 帧的约 98%。其中声音约 25 000 个时钟周期（一帧的 4%），有爆炸和直升机导弹时最多约 40 000；在繁忙的帧中它少做一些采样，把其余留给后面的帧。

## 运行

把 `build/river_raid.nex` 和你的 `River_Raid.rom`（卡带映像：8192 字节，无文件头，与 C++ 移植所用的相同）放在 Next 的 SD 卡的同一个文件夹中，在 Browser 中打开 .nex。没有 ROM（或文件不是这个卡带）时边框变红，程序停止。ROM 先按长文件名查找，再按短文件名 `RIVER_~1.ROM` 查找。

| | 键盘 | 摇杆 |
|---|---|---|
| 飞行 | Q A O P | Kempston 1（双人游戏中的第二位玩家：Kempston 2，或同一个） |
| 开火 | 空格或 M | 开火 |
| START | Enter | Mega Drive 手柄的 START |
| SELECT（游戏 1-8） | G | Mega Drive 手柄的 A |
| 暂停 | H（按下并松开；再按一次继续） | |
| PAL / NTSC | CAPS + 1（重新开始） | |
| 声音关 / 开 | CAPS + 2 | |
| 28 MHz / 14 MHz（游戏速度不变：只改变一帧中剩余的时间） | CAPS + 3 | |
| 在边框上显示一帧的工作，每部分一种颜色：橙色 apply，灰色 prepare（以及复位期间的 clear_layer2_page），红色 display，黄色 build_sprites，蓝色 main_loop，品红 push_line（一行新的河流，在 main_loop 内），白色 vbi，青色 pokey_frame，黑色为剩余时间 | T（开 / 关） | |

游戏 1-8 与 Atari 上相同：从第 1、5、20 或 50 座桥开始，奇数为单人，偶数为双人（轮流进行；键盘为两人操控）。

POKEY 的计数器决定哪个敌人何时苏醒，每次运行时它都从不同的值开始，和真机一样。

## 构建

```
make deps    # 把 sjasmplus、C++ 移植和 Xpeccy+ 取到 deps/（需要 git、C/C++ 编译器、make、cmake、zlib）
make         # build/river_raid.nex
```

单独 `make` 只需要 sjasmplus（装在别处时用 `make SJASMPLUS=...`）。`src/palette.inc`（C++ 移植的调色板模型）、`src/random.inc`、`src/font.inc`、`src/poly.inc` 和 `src/poly17.bin`（POKEY 的噪声）由 `make palette` 生成。

## 检查

```
make check     # FRAMES=... 帧（默认 3000）；你的 ROM 放在 rom/River_Raid.rom
make profile   # 一帧的时间花在哪里（FRAMES 之后的那一帧）
```

`make check-original` 把程序与原版卡带本身比较，就像当初比较 C++ 移植那样：`rr_oracle`（来自 C++ 移植的仓库，由该目标构建：在 libatari800 上运行的原版，需要 git、C 编译器、make、autoconf、automake）录制原版的运行（每帧之后的 RAM、游戏逻辑从 RANDOM 读到的值、输入），`nxcheck -oracle DIR` 用同样的输入和同样的 RANDOM 值运行程序，每帧之后把它的 RAM 与原版的比较（`Game::diffWithRam`：河流生成器、物体、游戏状态、碰撞、player-missile 内存、河流的行），出现差异后从原版的状态继续。八次运行，37 000 帧：演示模式、机器人玩到游戏结束再重新开始、双人游戏、飞行、加油、NTSC 和 PAL。结果都相同，只有两次 NTSC 运行中游戏结束的那一帧例外：在那里原版把帧计数器设在其 VBI 之前或之后，取决于那一帧的工作持续多久（C++ 移植以及本程序取更常见的情况）。

`make check` 在 PAL 和 NTSC 下都运行（`-pal`、`-ntsc`；`-switch N`：在第 N 帧之前按 CAPS + 1）。`tools/nxcheck` 在 [Xpeccy+](https://github.com/dotkoval/xpeccy-plus) 的 ZX Spectrum Next 内核上无窗口运行程序，并在旁边运行 C++ 移植（`rr::Game::frame`，POKEY 计数器和操作都相同）。操作来自一个虚构的玩家：它在演示模式中等待，有时选择别的游戏，按 START，飞向水面中央，躲避前方的敌人，燃料不足时飞过补给站，开火，偶尔暂停（`-bot N` 换一组选择，`-stress` 全速并一直开火，`-seed N` 换一个 POKEY 计数器，`-attract` 不要玩家）。每帧之后它比较河流生成器的状态（`RiverGen::diffWithRam`）、游戏状态（包括滚动字幕的状态）、最高分和面板字符、屏幕内存（只在检查用的构建中存在）、画出的物体（`Game::drawn`）、Copper 的内存以及它的列表中的河岸颜色与逐行河岸颜色（`Game::scan`）；最后逐像素比较最后一帧的画面：河流、面板和滚动字幕（用 Next 的颜色绘制的 `Game::drawRiver` 和 `drawStatusBar`）。它还报告玩了什么以及各帧耗时多少。4 x 40 000 帧、不同的玩家（游戏 1-8，约 70 局、300 次坠毁）结果都相同。破坏一致性的改动会显示第一处不同的帧和字段。

## 工作原理

| Z80 | 8K 页 | 内容 |
|---|---|---|
| $0000-$3FFF | 30, 31 | Atari 的 RAM：游戏状态在原版的地址上，player-missile 内存，屏幕内存（只在检查用的构建中）；转储与原版和 C++ 移植逐字节一致 |
| $4000-$5FFF | 18-27 | Layer 2 的窗口 |
| $6000-$7FFF | 12 | 物体的行（`ds_objs`）、表、精灵属性、Copper 的列表 |
| $8000-$9FFF | 4 | 程序：帧、河流生成器、游戏主循环 |
| $A000-$BFFF | 5 | 卡带映像，在它自己的地址上：表在原版读取它们的地方读取 |
| $C000-$DFFF | 6 | 程序：游戏、显示、精灵、面板 |
| ($6000-$7FFF) | 7 | 仅在启动时：字符集、图块、燃料指针和标志的精灵 |
| $E000-$FFFF | 1 | 缓冲区、表和栈 |

每一帧（`src/river_raid.asm`）：

1. `src/game.asm`，`prepare`：移出屏幕下方的坦克和它的炮弹，炮弹的颜色，把生命、桥和得分写进面板字符（`Game::prepare`）。Next 不写 player-missile 内存：精灵的图像和碰撞的行都来自 ROM 中的形状。
2. `src/display_simple.asm`、`src/display_hits.asm`：DLI 的工作，但不用 DLI（C++ 移植 `dli_removed` 分支中的 `Game::displayGeometry`）。每个物体位于其位置（slot）的高度，被裁剪到河流范围内；它的行进入 `ds_objs`。游戏读取的碰撞是简单的几何：先比较矩形框（与每一行的水域空隙比较、彼此比较），再比较点，无论在哪里接触。原版按窗口、逐个物体读取：0.01–0.25% 的帧会判定不同，即早一帧的接触。
3. `src/sprites.asm`：Atari 显示的内容变成 Next 的硬件。每个物体（player 3，颜色每行都变）是一个现成的精灵，各行带着各自的颜色，放在物体的位置。其他 player 和 missile 也各是一个精灵，放在游戏给出的位置。它们所有的图像都是启动时根据 ROM 中的形状一次性生成的 4 位图案（`src/obj_pics.asm`），所以每帧只需选一个图案并写入精灵属性（Atari 的一个像素是精灵的两个像素；两倍和四倍宽度用精灵的缩放实现）。桥附近河岸颜色会变化：Copper 在 Layer 2 的调色板中逐行设置它。
4. `src/play.asm`，`main_loop`：主循环（`Game::mainLoop`）：操作（键盘和摇杆，按 Atari 的方式读取）、暂停、每 16 帧由 POKEY 的 RANDOM 唤醒一个敌人、坦克、物体、飞机（燃料、转向、速度、子弹、撞到了什么）、导弹、炮弹、START 和 SELECT、新游戏、坠毁和新飞机，以及按速度生成并写入 Layer 2 的河流行（`src/river_gen.asm`，逐行对应 `river_gen.cpp`）。原版在坠毁或 START 后清理内存（13 帧）期间，只运行显示和 VBI，Layer 2 每帧清理两页，从复位的第二帧开始，清理期间被隐藏（它的裁剪窗口只保留面板的行）：河流立刻变黑，与 C++ 移植一样，没有横扫屏幕的条带。
5. `src/game.asm`，`vbi`：声音驱动（`src/sound.asm`：POKEY 的寄存器）、帧计数器、下一帧的颜色（桥被击中时水面闪红）、POKEY 计数器前进一帧（一个矩阵，`src/random.inc`）。然后 `pokey_frame`（`src/sound.asm`）为 DMA 生成这一帧 POKEY 输出的采样。
6. 在滚动字幕下方（光栅行 208）新画面生效：Layer 2 的卷动和颜色、精灵属性、面板和滚动字幕、Copper 的列表。

面板和滚动字幕使用 tilemap（40 x 32，8x8 图块，每像素 4 位）：Atari 的每个字符（8x8，每像素一个色钟）是两个图块，在启动时由游戏开机时构建的字符集生成（OS 字体的字母和数字、卡带自己的符号）；只写入发生变化的字符。Copper 把 tilemap 移到每一行字符；滚动字幕是它那一行地图中的一个环，用 X 卷动横向移动，两侧边缘都能看到的那半个字符在右侧被 tilemap 的裁剪窗口切掉，并由一个精灵在那里显示。面板的灰色来自 Layer 2（Copper 在面板的行上把它的颜色变成灰色），所以燃料指针（一个精灵）在它上面、在字符下面，与 Atari 上一样。标志由五个精灵组成。

Layer 2（320x256，256 色）保存 playfield 的 2 位颜色索引；显示一行 192 个色钟中的 160 个（从第 20 个开始；水面从不更靠近边缘），每个色钟两个点，所以比例与 Atari 相差不到 2%。颜色是 C++ 移植的 PAL 颜色（Altirra 的模型），作为 Next 的 8 位调色板项。
