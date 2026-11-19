# How River Raid works on modern ZX Spectrums

English | [Русский](HOW_IT_WORKS.ru.md) | [Українська](HOW_IT_WORKS.uk.md) | [Deutsch](HOW_IT_WORKS.de.md) | [Polski](HOW_IT_WORKS.pl.md) | [Italiano](HOW_IT_WORKS.it.md) | [Español](HOW_IT_WORKS.es.md) | [中文](HOW_IT_WORKS.zh.md) | [日本語](HOW_IT_WORKS.ja.md)

This is for anyone curious, no programming needed. How the game itself works (the river, enemies, bridges, why it gets harder) is told in the C++ port's [docs/HOW_IT_WORKS.md](https://github.com/djdron/river_raid/blob/main/docs/HOW_IT_WORKS.md). Here: how the Atari's picture, its collisions and its sound are made on two different computers, the ZX Spectrum Next and a ZX Evolution board running TS-Conf. Most of it is the same on both; where they differ, each has its own part (**On the Next**, **On TS-Conf**).

## Three different machines

The Atari 800 of 1979 has a 6502 processor at 1.79 MHz. The Next has a Z80 at up to 28 MHz; TS-Conf a Z80 at up to 14 MHz. All three are 8-bit computers, but their video chips work very differently.

The **Atari** draws the screen line by line, as the TV's beam goes. For moving things it has only eight "sprites": four **players** (each 8 dots wide) and four **missiles** (each 2 dots wide). Eight is far too few for River Raid's plane, jets, helicopters, ships, tanks, balloons, fuel depots and bridges, so the game cheats: it re-uses one player for every enemy down the screen. While the beam draws the screen, a small piece of code (the *display list interrupt*, DLI) wakes up before each object, moves player 3 to the object's place, gives it the object's shape and colour row by row, and when the object is finished, moves the same player down to the next object. Ten objects on screen are really one player, moved ten times during one picture.

What is a DLI? An *interrupt* is the hardware tapping the processor on the shoulder: the processor puts down what it was doing, runs a short piece of code, and goes back. The Atari's video chip follows a *display list*, a small program that says what each band of the screen shows. Any of its lines can carry a mark; when the beam reaches a marked line, the processor is interrupted: a display list interrupt. River Raid's main DLI starts just above the river and keeps hold of the processor down to the river's bottom. At every line it waits for the beam (the chip can hold the processor until the next line begins) and changes player 3 just in time. Only then does the processor go back to the game.

The **Next** has a much more generous video chip: a full-colour background layer (*Layer 2*), up to 128 hardware sprites of 16×16 dots that can be drawn two or four times as wide, a layer of tiles for text, and a helper called the *Copper* that can change colours at any line of the screen.

**TS-Conf** is a set-up of the ZX Evolution (Pentevo) board's video chip: a background picture in 16 or 256 colours that the hardware can scroll, two layers of tiles, up to 85 sprites of any size up to 64×64 dots (but none can be stretched), its own DMA for copying memory fast, and an interrupt that can be set to come at any line of the screen. It has no Copper. Its sound is usually a *General Sound*: a card with a Z80 of its own and four 8-bit DACs.

Neither can do what the Atari does, re-using a sprite while the picture is being drawn. But neither needs to: they simply have enough sprites. So the ports do not copy what the Atari's chips do. They copy **what the Atari shows**, then build the same picture from each machine's parts.

## Every frame, the Atari's work first

Fifty times a second (on the Next sixty too, as an American NTSC machine; TS-Conf's frame is 50) the program does exactly the work the Atari did for that frame: it moves the river on, moves the enemies, the plane, the bullet, reads the joystick, counts fuel and score. It keeps all of it in the same memory, at the same places, as the Atari did. That is what makes it checkable: the copy of the Atari's memory can be compared byte by byte with a real Atari's (an emulator of it) and with the C++ port, after every frame.

This part is the same program on both machines: the TS-Conf port runs a copy of the Next's code for the game, the river's generator, the enemies' placing and the collisions. Only the picture and the sound are each machine's own.

## The river

The river, its banks, islands, roads and houses are the Atari's **playfield**: the background. On the Atari each line of the river is 48 bytes of screen memory, four dots per byte, each dot one of four colours: background (black), bank (green or grey), bank edge, water (blue).

Each new line of river that the game makes is copied into one row of a background picture, each Atari dot as two dots side by side (the Atari's dots are wide). The colours are not stored as colours but as "colour 1, 2 or 3", and the palette says what colour 1, 2 and 3 are. This is how a whole river can turn red when a bridge is hit: one palette entry changes. The river scrolls down: the Atari does it by pointing its display at different memory, the ports by telling the background to start showing from another row. Only one new row is written per line of river; nothing is copied around.

Near a bridge the bank colour changes line by line (the road). Each machine does that its own way.

**On the Next** the river is in Layer 2, a 320×256 picture of 256 colours. Layer 2 is stored by columns, so a new line is written down 320 columns. The road's colours are the Copper's: before such a line is drawn, it changes the palette's "colour 1".

**On TS-Conf** the river is a 16-colour picture, 320×240, two dots in a byte, so a new line is 160 bytes written straight along its row. There is no Copper, but TS-Conf has 16 palettes of 16 colours and a register that says which one the river uses; the register takes effect at the end of a line. So each bank colour the river has had gets a palette of its own, and the interrupt is moved down the screen from one change to the next: a line before the road begins it switches the river to that colour's palette, at the road's end back again. Wherever the processor is in its work, the change lands on exactly the right line.

## The enemies: from one player to many sprites

The ports do not play the Atari's DLI any more, not even its timetable. Each enemy simply stands at the height its slot gives it, cut off where the river begins and ends. (The Atari's DLI could in principle reach an object a few lines late when it comes too close below the previous one; measured over a hundred thousand frames it never did, so the plain rule gives the same picture.)

Each object then becomes a ready-made sprite. The Atari changes player 3's colour on every line (that is how enemies have stripes); the ports' sprites can have a colour of their own in every dot, so the stripes are simply drawn into them. Each Atari dot becomes two dots of the sprite.

The pictures of all the enemies (every kind, every frame of animation, every explosion, mirrored too) are made once when the program starts: about sixty of them. Each frame then only says which picture each sprite shows and where; nothing is drawn while playing.

The plane, its bullet, the tanks on the banks, the tank's shell and the helicopter's missile use the Atari's other players and missiles, which have one colour each and stay at one place all screen long. The game puts each at a known line (the plane always at the same height, the shell where the tank fired it...), so each is one sprite with its picture made at the start too.

**On the Next** a sprite is 16×16 dots, so an object taller than 16 lines is two. Double or quadruple width is the sprite drawn two or four times as wide by the hardware. An object coming in from the top is drawn whole and the part above the river is cut off by the sprites' clip window.

**On TS-Conf** a sprite can be up to 64×64 dots, so every object is one sprite, but the hardware cannot stretch it: each picture is made at the start three times, 16, 32 and 64 dots wide. What lies outside the river is hidden under a tile layer that is black above the river and grey under the panel.

## Collisions: who touched what

On the Atari, the game never works out collisions itself. The video chip does it: while drawing, whenever a player's dot lands on a coloured dot of the playfield, or on another player's dot, it sets a bit in a collision register ("player 2 touched colour 1", "missile 2 touched player 3"). The DLI reads these registers after each object: that is how the game knows that the bullet hit this ship, that the plane flew into the bank, that a jet reached the edge and must turn.

These bits are only ever set, never cleared by the chip: they stay until the program clears them all at once (by writing to a register called HITCLR). And player 3 is every enemy in turn. Read once at the end of the frame, the registers would say only "player 3 touched something", not which ship. So after each object the DLI copies the registers into the game's memory, next to that object ("the bullet hit the object in slot 5"), clears them, and moves player 3 on to the next object. The game looks there later.

Neither the Next's video chip nor TS-Conf's has anything like that, so the program works it out itself, and only what the game reads: the plane with the bank, the bullet with the bank and with objects, the objects with the bank edge, the tank with the edge, the helicopter's missile with the plane and the bank, the shell with the plane and objects. (The Next does have one hardware flag of this kind, "two sprites overlapped", but it says neither which sprites nor anything about the river, and it comes a frame too late.)

Every moving thing is where the game put it, so each collision is a question about a few lines. For each sprite: on its lines, do its dots touch the bank (or the edge)? For two sprites: on the lines both are on, do their dots meet? The work goes "cheap first, exact only if needed": first whether their boxes meet at all; only then the dots, a line at a time: each line's dots lined up with the other's and compared all at once (shapes have gaps a bullet can pass through). For a helicopter, balloon or ship against the bank's edge the ends of each of its lines are enough: an edge between them counts as a touch. The bank is looked at without its houses and roads: then each line of the river is just bank, edge, water, edge, bank (twice with an island), a handful of numbers kept from when the line was made. And water is never a collision in River Raid. Most of it is avoided with "is it even close?": each line of the river remembers where its water starts and ends, so a sprite or an enemy well inside the water is passed over with two comparisons.

Here the ports no longer follow the Atari's timing. The Atari's DLI reads the chip's registers right after each object and clears them, so it sees a touch only within a window of lines; a bullet touching only an object's last row, for example, falls between two windows and is counted a frame later, when the bullet is deeper in. The ports count a touch wherever it happens. In about one frame in a thousand (one in four hundred at the far bridges, where every enemy slot is full) this decides otherwise: always a hit or a crash a frame earlier than on the Atari. Nobody playing would notice, but the game no longer follows the original frame for frame. It is the price of speed: the timetable and its reads took more than half the work of the busiest frames.

**On the Next** lining the dots up is one instruction (its processor can shift a row of dots by any number of places at once); the enemies' placing and all the collisions take about 45 000 of its ticks in the busiest frame, about 8% of a fiftieth of a second.

**On TS-Conf** the Z80 has no such instruction, so the shift is a short loop; the same work takes about 57 000 of its ticks a frame on average in the busiest scenes, about 20% of its frame at 14 MHz.

## The panel and the scrolling line

Below the river the Atari shows a panel in large letters (score, game number, fuel gauge, high score, bridge) and a line that scrolls the credits, with a rainbow Activision logo. Both ports build the Atari's own letters when the program starts (the ones the game makes from the computer's font and its own symbols), and a letter of the panel is written only when it changes (a digit of the score, a life). The fuel needle and the rainbow logo are sprites.

**On the Next** the letters are *tiles*: small 8×8 pictures arranged in a grid, like letters on a page, each Atari letter two tiles. The scrolling line is a ring: the whole tile row slides sideways two dots a frame, and only the letter coming in on the right is written into the column that has just slid out on the left. Because the tile layer is exactly as wide as the screen, that column also shows at the right edge; there it is hidden, and a single sprite shows the letter coming in instead. The panel's grey background is the river's own layer, with its four colours turned grey by the Copper for the panel's lines; the fuel needle appears over the grey but under the letters, as on the Atari.

**On TS-Conf** the panel is a picture of its own, in 256 colours, which the interrupt switches the screen to at the panel's first line (the same interrupt that changes the river's palette; its picture, its scroll, its mode all change there). Its letters are drawn once at the start and copied into place by the DMA. The panel's picture lies over the sprites, with holes where it has no letters; under the holes a tile layer shows the grey, and the needle and the logo are sprites shown over it. The scrolling line is a ring of 32 letters in a picture 512 dots wide; the interrupt sets where the screen starts showing it, so only the letter coming in is written.

The pictures are 320 dots wide: everything the machines can draw is in there, and around it only a single colour (the border). The Atari's picture is a little wider: the river and panel by 8 of its pixels on the left, the scrolling line by about 3 of its letters. So in the attract mode the scrolling text is cut at the edges.

## Sound

The Atari's sound chip, POKEY, has four channels. Each counts down a fast clock (64 000 ticks a second) from a number the game sets, and every time the count runs out it gives a pulse; what a pulse does depends on another setting: flip the channel's output (a clean tone, higher the smaller the number), or take a bit from one of POKEY's shift registers, which give a long, random-looking stream of bits (noise: the engine, explosions). Each channel also has a volume. The game itself only sets these numbers once a frame: the engine's pitch from the speed, a falling whistle for the tank's shell, a hiss for an explosion.

Neither machine has a POKEY, but both can play a stream of numbers through a DAC (a port where a number becomes a voltage, so a stream of numbers is a sound wave). So POKEY's output is worked out by program, about 15 800–15 900 numbers a second, about 320 a frame, and left in a ring of memory, which hardware then plays on its own, round and round.

Working the wave out tick by tick would be far too slow. Instead each channel jumps from pulse to pulse: it knows how many samples away its next pulse is, and between pulses its output does not change. Where the output turns on or off, it writes "+ volume" or "− volume" into the ring; at the end one pass adds them up into the wave. The ring is kept about two and a half frames ahead of where it is being played, so a frame with a lot of work can make fewer numbers and leave the rest to the next frames. The DAC takes one byte, 0 to 255: four channels at full volume would pass that, so the numbers are scaled to fit (when two explosions meet the engine's noise, the loudest moments in the game).

**On the Next** the program works the wave out itself, and its DMA (a piece of hardware that copies a byte from memory to the DAC every 1/15 909 of a second on its own) plays it. The pure tones (the beeps, refuelling, firing, the shell's whistle) skip all this: the Next also has AY sound chips, which make exactly that square wave themselves, so those POKEY channels are just handed to an AY with the pitch and volume converted. Only the noises (the engine, explosions, the helicopter's missile) go to the DAC. This costs about 25 000 of the processor's ticks a frame, 4% of a fiftieth of a second; the busiest (engine, explosion, firing and a missile at once) more than twice that. When the game has more work than time, the sound gives way, not the game. The DMA reads memory through the same windows as the processor: when the code briefly put another piece of memory in the ring's window, the DMA played that instead, a click every frame, so nothing may move there while it plays.

**On TS-Conf** the whole of it runs on the General Sound card. When the game starts, it puts a small program into the card (the same wave-making code as the Next's), and from then on it only sends the card POKEY's eight numbers once a frame; the card's own Z80 makes the wave, all four channels, and its own interrupt plays it, 15 820 numbers a second, into its DACs. The main processor spends about 3 400 ticks a frame on sound, mostly waiting for the card to take each number. Without a card, only the pure tones play, on the board's two AY chips, as the Next plays them.

## Interrupts

**On the Next** they are not used at all. What the Atari's DLI did is worked out ahead of time, as a calculation, while the previous picture is still showing. What has to change at a particular line of the real screen (the road's colour) is written into the Copper's list, and the Copper, which never misses a line, does it. The processor only has to watch which line the beam is on, to switch to the new frame below the scrolling line, where nothing changes on the screen. The sound does not need them either: the DMA plays it without the processor.

**On TS-Conf**, with no Copper, the interrupt does the Copper's job. Before each frame the program makes a list of what must change and where: the river's palette at each change of the bank's colour, the panel's picture at its first line, the scrolling line's position, and the frame's end. The interrupt is set to the first of them; each time it comes, it does that change and sets itself to the next one. The change takes effect at the end of the line, so it does not matter how long the interrupt takes to arrive. The last one, below the panel, tells the program that the frame is over.

## Starting

**On the Next** the program loads the cartridge's image, River_Raid.rom, from its own folder through the Next's DOS.

**On TS-Conf** the program is started from Wild Commander, which gives it neither a folder nor a DOS, so it reads the SD card itself (FAT16 or FAT32) and searches it for River_Raid.rom, the root first, then every folder. While it works, the screen stays black. Without the file: a red border.

## Time

All of this has to happen within a fiftieth of a second.

**On the Next** at 28 MHz, about sixteen times faster than the Atari, an average frame now takes about 21% of the time it may; the busiest the program can be made to meet (every enemy slot full, flying at full speed and firing all the time, at bridge 80) about 41%. So it would run at 14 MHz too. Where the time goes in the busiest frames: the river's two new lines about 31 000 ticks, the sound up to 40 000, the enemies' placing and collisions about 45 000, the sprites about 13 000, the game itself about 14 000. The program switches the Next to 28 MHz itself; a real Next at 28 MHz now and then makes the processor wait for memory, which the emulator's core should account for, but it has not been checked on real hardware.

**On TS-Conf** at 14 MHz an average frame takes about 26% of its time, the busiest scenes about 40% on average and 53% at most. At 7 MHz it still fits, just; at 3.5 MHz it does not keep up. Without the sound's work (it is on the card) the river's new lines take about 34 000 ticks in the busiest scenes, the enemies' placing and collisions about 57 000, the sprites and the palette's changes about 16 000, the game itself about 9 000.

It was not always so fast. Playing the Atari's DLI cycle by cycle, with its collision registers emulated line by line, took about 60% of the Next's frame on average and up to 88%; at the busy bridges a frame was often late. Then, step by step, first in the C++ port and checked against the original each time: the cycles were dropped but for a few rules; the enemies became ready-made multicolour sprites; the other sprites were taken from where the game put them instead of searched for; the collisions were worked out from the sprites' rows; the DLI's loop became a timetable; all the sprites' pictures were made at the start; the panel and the scrolling line were written only where they change; and finally the DLI went altogether, the collisions plain geometry with "is it even close?" first. Only after that was the TS-Conf port made, on the same code. A frame that is late is simply shown twice: only the speed depends on the processor, not what happens in the game.

## How we know it is right

Every change to what the game does is made first in the C++ port and compared there with the original game running in an Atari emulator: after every frame the whole of the Atari's memory (the river, every object, the score, fuel, the collisions), and the river as drawn against the original's screen, dot for dot.

Then the ports, each in an emulator of its machine (the Next's and TS-Conf's cores of Xpeccy+, TS-Conf's with its General Sound): after every frame the copy of the Atari's memory is compared with the C++ port, and so are the objects drawn, the bank's colours line by line (the Copper's list on the Next, the interrupt's list on TS-Conf) and the sound card's numbers; and the picture, dot for dot (on TS-Conf every frame's). Hundreds of thousands of frames of games played by a simple robot player, from the first bridge to bridge 200 (the robot can be made unable to crash, on both sides, to get that far), are the same. TS-Conf has been checked only in the emulator so far, not on a real board.

One difference from the original is known, and chosen: the collisions (above, a hit or a crash a frame earlier in about one frame in a thousand). The Atari's own way is kept in the C++ port, which can still be checked against the original.
