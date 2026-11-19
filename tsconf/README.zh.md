# River Raid：TS-Conf 移植

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | 中文 | [日本語](README.ja.md)

移植到 TS-Conf（ZX Evolution / Pentevo）：一个独立的项目，有自己的构建，与 ZX Spectrum Next 版分开（[NEXT.zh.md](../NEXT.zh.md)；两者见[主页](../README.zh.md)）。只共用 `../deps`（sjasmplus、C++ 移植、Xpeccy+：在根目录 `make deps`）。

游戏的运行与 Next 上相同（同样的游戏逻辑、display 和河流生成器，复制到 `src/`），按 TS-Conf 的方式显示。只有 50 Hz（PAL）：主板的帧。

逐个例程的源码、对 Next 共用代码的改动，以及两台机器区别的对照表：[CODE.md](CODE.md)（英文和俄文）。

- 河流：16 色模式，320x240，一行画面 256 字节（开头 160 字节），512 行成环，由硬件卷动（GYOFFS）；新的一行河流直接写进它所在的行（`render.asm`），不做复制。
- 河岸颜色逐行变化：河岸出现过的每种颜色都有自己的一套调色板（PALSEL 0-7：其中颜色 1 就是这种颜色，只设置一次；2 和 3 是岸边和水，每帧设置）。帧中断在一帧中从一个变化点移到下一个（`build_events`、`irq`），在变化前一行设置 PALSEL；该寄存器在行末才生效，所以在任何 CPU 速度下变化都是准确的。
- 物体、飞机、子弹、坦克和导弹：精灵（`sprites.asm`），它们的图像在启动时根据卡带中的形状生成，每个物体都有 16、32 和 64 点宽三种（精灵不能缩放）。
- 面板和滚动字幕（`panel_ts.asm`）：第 184-239 行来自一幅独立的画面，由帧中断在第 184 行切换进来（VPAGE、GYOFFS），使用 256 色模式，位图在图块和精灵之上（GFXOVR）；图块层 0 是字符下面的灰色（它也在那里遮住河流的精灵）；燃料指针和标志是其上方的精灵。字符在启动时画一次，由 DMA 复制；滚动字幕是一个 32 个字符的环，铺在画面的 512 个点上，由 GXOFFS 显示。
- 图块层 0 也是河流上方的黑色。
- 操作：Q A O P，空格或 M 开火，Enter 为 START，G 为 SELECT，H 暂停；Kempston。
- 声音：有 General Sound（原版卡或 NeoGS）时全部由它播放：声卡自己的 Z80 像 Next 的 DAC 那样播放 POKEY（`gs/`：Next 的 `pokey_frame` 及其脉冲，17 位计数器的比特由声卡根据其递推公式自己生成），单声道（相同的采样送到声道 1 和 3，即左右声道），每秒 15 820 个采样（它的中断每秒 37 500 次，256 次中取 108 次）。启动时通过声卡固件把程序装进声卡（`gs_load.asm`；再次运行时会发现程序仍在那里）；之后 apply 每帧发送一次 POKEY 的寄存器（`sound_gs.asm`）。没有声卡（或声卡不应答）时：只有纯音（引擎、提示音、射击、奖励、炮弹的呼啸）由 TurboSound 的两个 AY 播放，与 Next 的方式相同（`sound_ay.asm`）：POKEY 的声道 1 和 2 用第二块芯片的 A 和 B，3 和 4 用第一块的 B 和 C。在 Xpeccy 中：打开 General Sound（AY 需要 TurboSound NedoPC）。

在 14 MHz 下，一帧的工作在演示模式中平均约 69 000 个时钟周期，从第 80 座桥开始全速并一直开火（-stress）时约 111 000，最多约 181 000，一帧共约 287 000；在 7 MHz 下仍然够用，但很紧（-stress 最多约 143 000，一帧约 143 400；没有迟到的帧）；在 3.5 MHz 下跟不上。

内存（16K 窗口）：$0000 Atari 的 RAM（第 1 页；启动期间是存放启动工作的第 3 页），$4000 行的游程和缓冲区，$7D00 起为 OS 字体（第 5 页；`render_line` 绘制时会把画面的一页放到这里），$8000 程序和从 $A000 起的卡带（第 2 页），$C000 程序、缓冲区和栈（第 6 页）；河流画面从第 32 页起，面板画面从第 64 页起，图块映射在第 7 页，图块的点在第 8 页，精灵的点从第 24 页起。

    make          build/river_raid.spg：给 Wild Commander 用的程序（SPG 1.0）；它自己在 SD 卡上
                  找到 River_Raid.rom（见下文）
    make sna      build/river_raid.sna：内含你的 ROM 的 128K 快照（../rom/River_Raid.rom）
    make check    在 Xpeccy+ 的 TSConf 内核上运行测试版本，并与 C++ 移植逐帧比较：状态以及
                  每一帧的画面（FRAMES=... 帧数，默认 3000）；有 General Sound（Xpeccy+ 的，
                  固件 gs105b.rom）时还比较声卡收到的寄存器
    make palette  重新生成 src/palette_ts.inc（C++ 移植的颜色，换算成主板的电平）

`build/tools/tscheck` 也能自己玩：`-bot N`（nxcheck 的虚构玩家）、`-stress`、`-start N`；TSBRIDGE、TSGHOST、NXGAME 与 nxcheck 相同；TSSPEED=1 为 7 MHz；TSGS=neo 为 NeoGS，TSGS=0 为没有声卡（检查 AY 的纯音）；TSWAV=文件、TSWAVCPP=文件：声卡的采样和 C++ 移植的 POKEY（同样的采样率，WAV 文件，可以听）。

.spg 也会在 GitHub 上构建（workflow `tsconf` 的构件）。把 River_Raid.rom（卡带映像，8192 字节）放在 SD 卡上任意位置：程序启动时会搜索整张卡（`load_rom.asm`：第一个分区或整张卡，FAT16 或 FAT32，先根目录，再其下的文件夹，最深 8 层；长文件名不区分大小写，或短文件名 RIVER_~1.ROM）。找不到时：边框变红。启动工作期间屏幕是黑的（`screen_black`：一次性把整个 CRAM 设为黑色，不管 Wild Commander 留下的是什么模式：它的 ZX 屏幕在第 5 页，正是启动写缓冲区的地方）。

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd 文件夹` 用主机上的文件夹充当 SD 卡运行 .spg（`-img 文件`：卡的映像）；`-sna build/river_raid.sna 600 out.ppm` 运行快照。
