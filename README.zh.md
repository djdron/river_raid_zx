# River Raid：现代 ZX Spectrum 移植

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | 中文 | [日本語](README.ja.md)

River Raid（Activision，Atari 8 位机，1983，作者 Carol Shaw）在今天的 ZX Spectrum 机器上：
**ZX Spectrum Next** 和 **TS-Conf**（ZX Evolution / Pentevo）。两个移植都基于
[djdron/river_raid](https://github.com/djdron/river_raid) 中的 C++ 移植：它弄清了原版如何完成每一件事，并与原版逐帧核对。游戏逻辑与原版一致，逐帧相同，使用同样的 RAM、同样的地址；每台机器用自己的硬件把它显示出来。

非官方的爱好者项目，用于学习目的，与 Activision 和 Microsoft 无关。项目中不包含游戏本身：程序在运行时读取你自己的卡带映像。

## 两个移植

| | [ZX Spectrum Next](NEXT.zh.md) | [TS-Conf](tsconf/README.zh.md)（ZX Evolution / Pentevo） |
|---|---|---|
| 文件 | `river_raid.nex`（在 Browser 中打开） | `river_raid.spg`（从 Wild Commander 启动） |
| ROM | `River_Raid.rom` 与 .nex 放在同一文件夹 | `River_Raid.rom` 放在 SD 卡上任意位置（FAT16/32） |
| 河流 | Layer 2，河岸颜色由 Copper 逐行设置 | 16 色模式，硬件卷动，河岸颜色由帧中断逐行设置（每种颜色一套调色板） |
| 敌人、飞机、导弹 | 精灵 | 精灵 |
| 面板、滚动字幕 | tilemap | 在河流下方切换进来的独立画面、图块、精灵 |
| 声音 | 程序把 POKEY 仿真到 DAC（zxnDMA），纯音由 AY 播放 | 全部在 General Sound 上（由声卡自己的 Z80 仿真 POKEY，单声道）；没有声卡时由 TurboSound 的 AY 播放纯音 |
| CPU | 28 MHz（14 MHz 也够） | 14 MHz（7 MHz 也够） |
| 电视制式 | PAL 50 Hz 或 NTSC 60 Hz（CAPS + 1） | PAL 50 Hz |
| 详细说明 | [NEXT.zh.md](NEXT.zh.md) | [tsconf/README.zh.md](tsconf/README.zh.md) |

两个移植的游戏都已完整：演示模式（attract mode）、游戏 1-8（从第 1、5、20 或 50 座桥开始；单人或双人轮流）、飞机、燃料与补给站、敌人、坦克、直升机的导弹、桥、得分、生命、最高分、暂停、面板以及带彩虹标志的滚动字幕。两者都还没有在真机上运行过：都在模拟器 [Xpeccy+](https://github.com/dotkoval/xpeccy-plus)（它的 Next 和 TSConf 内核）上核对。

## 获取

每次 push 时程序都会在 GitHub 上构建：[Actions](https://github.com/djdron/river_raid_zx/actions)，workflow `build`（.nex）或 `tsconf`（.spg）的构件（artifact）。你需要自己的 `River_Raid.rom`：卡带映像，8192 字节，无文件头（与 C++ 移植所用的相同）。没有它，边框会变红。

## 操作

| | 键盘 | 摇杆 |
|---|---|---|
| 飞行 | Q A O P | Kempston |
| 开火 | 空格或 M | 开火 |
| START | Enter | （Next：Mega Drive 手柄的 START） |
| SELECT（游戏 1-8） | G | （Next：Mega Drive 手柄的 A） |
| 暂停 | H | |

Next 还有几个按键（PAL/NTSC、声音、CPU 速度、在边框上显示一帧的时间）：[NEXT.zh.md](NEXT.zh.md)。

## 如何核对

凡是改变游戏行为的改动，先在 C++ 移植中做，再到 Next，再到 TS-Conf 移植中同一份代码的副本。每个移植都有自己的检查：程序在 Xpeccy+ 内核上无窗口运行，旁边运行 C++ 移植，输入相同、POKEY 计数器相同，每帧之后比较两者：游戏状态、河流生成器、面板，以及逐像素比较画面（`make check`、`make -C tsconf check`；一个虚构的玩家玩上几十万帧）。Next 的程序还与原版卡带本身（在 libatari800 上运行）做了比较（`make check-original`）。

## 构建

```
make deps          # 把 sjasmplus、C++ 移植和 Xpeccy+ 取到 deps/（需要 git、C/C++ 编译器、make、cmake、zlib）
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

构建只需要 sjasmplus；检查需要其余部分，以及放在 `rom/River_Raid.rom` 的你的 ROM。

## 仓库

| 路径 | 内容 |
|---|---|
| `src/`、`tools/`、`Makefile` | ZX Spectrum Next 的程序及其检查（[NEXT.zh.md](NEXT.zh.md)） |
| `tsconf/` | TS-Conf 移植：独立的项目和构建，游戏代码从 `src/` 复制（[tsconf/README.zh.md](tsconf/README.zh.md)） |
| [docs/HOW_IT_WORKS.zh.md](docs/HOW_IT_WORKS.zh.md) | Atari 的画面和碰撞如何在 Next 上实现，面向所有人 |
| [docs/NOTES.zh.md](docs/NOTES.zh.md) | Next 程序是如何做的、发现了什么，附数据 |
| [docs/CODE.md](docs/CODE.md) | Next 的汇编源码，逐个例程（英文和俄文） |
| [HANDOFF.zh.md](HANDOFF.zh.md) | 项目状态，便于接手工作 |

## 许可证

本项目自己的代码和文档采用 MIT 许可证，见 [LICENSE](LICENSE)。`src/palette.inc` 和 `tsconf/src/palette_ts.inc` 由 C++ 移植的调色板模型（MIT）生成。`src/font.inc` 和 `tsconf/src/font.inc` 是 AltirraOS 的字体（Copyright (C) 2008-2018 Avery Lee；可在保留其声明的前提下自由复制和分发，文件中保留了该声明），与 C++ 移植中的相同：Atari 操作系统的 ROM 不属于卡带。检查使用 [Xpeccy+](https://github.com/dotkoval/xpeccy-plus)（MIT）和汇编器 [sjasmplus](https://github.com/z00m128/sjasmplus)（BSD-3）；二者都不包含在仓库中，由 `make deps` 下载。River Raid 本身（ROM、其代码、图形和声音）属于其权利人，不在本许可证范围内。
