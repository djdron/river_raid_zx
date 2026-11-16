# How River Raid works on the ZX Spectrum Next

English | [Русский](HOW_IT_WORKS.ru.md)

This is for anyone curious, no programming needed. How the game itself works (the river, enemies, bridges, why it gets harder) is told in the C++ port's [docs/HOW_IT_WORKS.md](https://github.com/djdron/river_raid/blob/main/docs/HOW_IT_WORKS.md). Here: how the Atari's picture and its collisions are made on a different computer, the ZX Spectrum Next.

## Two different machines

The Atari 800 of 1979 has a 6502 processor at 1.79 MHz; the Next has a Z80 at up to 28 MHz. Both are 8-bit computers, but their video chips work very differently.

The **Atari** draws the screen line by line, as the TV's beam goes. For moving things it has only eight "sprites": four **players** (each 8 dots wide) and four **missiles** (each 2 dots wide). Eight is far too few for River Raid's plane, jets, helicopters, ships, tanks, balloons, fuel depots and bridges, so the game cheats: it re-uses one player for every enemy down the screen. While the beam draws the screen, a small piece of code (the *display list interrupt*, DLI) wakes up before each object, moves player 3 to the object's place, gives it the object's shape and colour row by row, and when the object is finished, moves the same player down to the next object. Ten objects on screen are really one player, moved ten times during one picture.

What is a DLI? An *interrupt* is the hardware tapping the processor on the shoulder: the processor puts down what it was doing, runs a short piece of code, and goes back. The Atari's video chip follows a *display list*, a small program that says what each band of the screen shows. Any of its lines can carry a mark; when the beam reaches a marked line, the processor is interrupted: a display list interrupt. River Raid's main DLI starts just above the river and keeps hold of the processor down to the river's bottom. At every line it waits for the beam (the chip can hold the processor until the next line begins) and changes player 3 just in time. Only then does the processor go back to the game.

The **Next** has a much more generous video chip: a full-colour background layer (*Layer 2*), up to 128 hardware sprites of 16×16 dots, a layer of tiles for text, and a helper called the *Copper* that can change colours at any line of the screen. It cannot do what the Atari does, re-using a sprite while the picture is being drawn. But it does not need to: it simply has enough sprites.

So the port does not copy what the Atari's chips do. It copies **what the Atari shows**, then builds the same picture from the Next's parts.

## Every frame, the Atari's work first

Fifty times a second (sixty on an American NTSC machine) the Next does exactly the work the Atari did for that frame: it moves the river on, moves the enemies, the plane, the bullet, reads the joystick, counts fuel and score. It keeps all of it in the same memory, at the same places, as the Atari did. That is what makes it checkable: the Next's copy of the Atari's memory can be compared byte by byte with a real Atari's (an emulator of it) and with the C++ port, after every frame.

Then comes the picture.

## The river

The river, its banks, islands, roads and houses are the Atari's **playfield**: the background. On the Atari each line of the river is 48 bytes of screen memory, four dots per byte, each dot one of four colours: background (black), bank (green or grey), bank edge, water (blue).

On the Next the river is in Layer 2, a 320×256 picture. Each new line of river that the game makes is copied into one row of Layer 2, each Atari dot as two Next dots side by side (the Atari's dots are wide). The colours are not stored as colours but as "colour 1, 2 or 3", and the Next's palette says what colour 1, 2 and 3 are. This is how a whole river can turn red when a bridge is hit: one palette entry changes.

The river scrolls down. The Atari does it by pointing its display at different memory; the Next does it by telling Layer 2 to start showing from another row. Only one new row is written per line of river; nothing is copied around.

Near a bridge the bank colour changes line by line (the road). The Copper does that: before such a line is drawn, it changes the palette's "colour 1".

## The enemies: from one player to many sprites

To know what the Atari shows, the Next plays the Atari's DLI too: the same instructions, in the same order, with the same timing. As it goes, it writes down for every screen line what player 3 looked like on that line: its 8 dots of shape, its position, its width (normal, double or quadruple) and its colour.

From that list the Next makes sprites. It goes down the screen and cuts player 3 into pieces of up to 16 lines that sit at one position: each piece becomes one Next sprite. A ship 8 lines tall is one sprite; a bridge or a long fuel depot may be two. The 8 dots of each Atari line become 16 dots of the sprite (each Atari dot is two Next dots), and double or quadruple width is simply the sprite drawn two or four times as wide.

The Atari changes player 3's colour on every line (that is how enemies have stripes). A Next sprite has one set of colours, so here too the Copper helps: before each line, it changes the colour the sprites use, just as the Atari's DLI did.

The plane, its bullet, the tanks on the banks, the tank's shell and the helicopter's missile use the Atari's other players and missiles, which stay at one place all screen long. They are cut into sprites the same way.

Drawing a sprite's shape takes time, so the Next remembers which shapes it already has in its sprite memory. When a ship looks the same as in an earlier frame (which is most of the time) its old shape is used again and nothing is drawn.

## Collisions: who touched what

On the Atari, the game never works out collisions itself. The video chip does it: while drawing, whenever a player's dot lands on a coloured dot of the playfield, or on another player's dot, it sets a bit in a collision register ("player 2 touched colour 1", "missile 2 touched player 3"). The DLI reads these registers after each object: that is how the game knows that the bullet hit this ship, that the plane flew into the bank, that a jet reached the edge and must turn.

These bits are only ever set, never cleared by the chip: they stay until the program clears them all at once (by writing to a register called HITCLR). And player 3 is every enemy in turn. Read once at the end of the frame, the registers would say only "player 3 touched something", not which ship. So after each object the DLI copies the registers into the game's memory, next to that object ("the bullet hit the object in slot 5"), clears them, and moves player 3 on to the next object. The game looks there later.

The Next's video chip has nothing like that, so the Next works it out, for each line where something moves: which dots of each player and missile are lit, and what is under them. Then it sets the same bits the Atari's chip would have set, and the DLI, played on the Next, reads and clears them at the same moment as on the Atari.

The Next does have one hardware flag of this kind: "two sprites overlapped". It is no help here. It says neither which sprites nor anything about the river (the banks are in Layer 2, not sprites). With up to sixty sprites a frame, it would be set by sprites the Atari would never have compared (the logo, the needle). And it is set only while the beam actually draws the sprites, a frame later, when the Atari's DLI had to know in the middle of this one.

There is a catch. The DLI reads the collision registers while the screen is still being drawn, and the Atari's chips and processor share their time very precisely. Whether a touch on the line being drawn "counts" for this object or for the next one depends on exactly at which moment of the line the processor reads the register. To get it right the Next keeps an exact clock of the Atari: it counts, for every instruction of the DLI, how many of the Atari's machine cycles it takes, and lets the "beam" draw each line at the right moment in between. This is the most delicate part of the port, and it is the same model the C++ port uses, checked against the original.

To make it fast, the Next only works out the collisions the game actually reads (ten of the sixty-four the Atari's chip keeps track of): the plane with the bank, the bullet with the bank and with objects, the objects with the bank edge, the tank with the edge, the helicopter's missile with the plane and the bank, the shell with the plane and objects. Two sprites far apart on the line are not compared dot by dot. And water is never a collision in River Raid, so when there is only water under a sprite, there is nothing to look at.

So the work goes "cheap first, exact only if needed". Is there any sprite on this line at all? If not, the line is done. Where do two sprites start and end on the line? If the stretches do not meet, they did not touch; only if they do are their dots compared. Is there anything but water under a sprite? Only then are its dots matched with the bank's.

What it costs, measured over 20 000 frames of play by the robot player (PAL; NTSC is the same): collisions take about 79 000 ticks of an average frame, 14% of a fiftieth of a second. That was a fifth of the frame's work then; after the DLI was sped up (see Time) it is a quarter. Of the 79 000, nearly half goes on the cheap part (is there anything on this line, and where is the line's river in memory), the rest about evenly on sprites against the river and sprites against each other. One idea not yet tried: do the cheap test once per object instead of on every line, and skip all of an object's lines when its box touches neither the bank nor another sprite. How much that would save is not known until it is measured, since empty lines are already quick.

## The panel and the scrolling line

Below the river the Atari shows a panel in large letters (score, game number, fuel gauge, high score, bridge) and a line that scrolls the credits, with a rainbow Activision logo.

On the Next these are made of *tiles*: small 8×8 pictures arranged in a grid, like letters on a page. When the program starts, it builds the Atari's own letters (the ones the game makes from the computer's font and its own symbols) and turns each into two tiles. Every frame it writes the panel's letters as tiles. The scrolling line moves sideways two dots a frame: the tile layer itself is shifted, and the one tile that would show at both edges of the screen at once is made fresh every frame.

The panel's grey background is the colour the Next shows where nothing at all is drawn, so the fuel needle (a sprite) appears over the grey but under the letters, as on the Atari. The rainbow logo is five sprites.

## Sound

The Atari's sound chip, POKEY, has four channels. Each counts down a fast clock (64 000 ticks a second) from a number the game sets, and every time the count runs out it gives a pulse; what a pulse does depends on another setting: flip the channel's output (a clean tone, higher the smaller the number), or take a bit from one of POKEY's shift registers, which give a long, random-looking stream of bits (noise: the engine, explosions). Each channel also has a volume. The game itself only sets these numbers once a frame: the engine's pitch from the speed, a falling whistle for the tank's shell, a hiss for an explosion.

The Next has no POKEY, but it has a DAC: a port where a number becomes a voltage, so a stream of numbers is a sound wave. So the Next works out POKEY's output itself, 15 909 numbers a second, about 320 a frame, and leaves them in a ring of memory. Sending them to the DAC one by one, at exactly the right moments, would take the processor's whole time; the Next's DMA does it instead, a piece of hardware that copies a byte from memory to the port every 1/15 909 of a second on its own, round and round the ring. The processor only has to keep the ring filled a little ahead of it.

Working the wave out tick by tick would be far too slow. Instead each channel jumps from pulse to pulse: it knows how many samples away its next pulse is, and between pulses its output does not change. Where the output turns on or off, it writes "+ volume" or "− volume" into the ring; at the end one pass adds them up into the wave. This costs about 22 000 of the processor's ticks a frame, 4% of a fiftieth of a second; the busiest frames (engine, explosion and firing at once) twice that.

## Why not the Next's line interrupts

The Next can also interrupt its processor at any chosen line of the screen. The port does not use that, because it does not need to keep up with the beam. The Atari's DLI is played ahead of time, as a calculation, while the previous picture is still showing. What has to change at a particular line of the real screen (the road's colour, player 3's colour) is written into the Copper's list, and the Copper, which never misses a line, does it. The processor only has to watch which line the beam is on, to switch to the new frame below the scrolling line, where nothing changes on the screen (interrupts stay off). The sound, played sample by sample through the Next's DAC, does not need them either: the Next's DMA does that without the processor (see Sound).

## Time

All of this has to happen within a fiftieth of a second. The Next runs at 28 MHz, about sixteen times faster than the Atari, but playing the Atari's DLI cycle by cycle is slow. After four rounds of speeding up, and with the sound, a frame takes about 60% of the time it may on average, and the busiest moments (tanks, shells and missiles beside the enemies) up to about 88%. On PAL 2 frames in 60 000 played by the robot were a little late and shown twice. On NTSC, at sixty frames a second, there is less time per frame: about once a second of play a frame is late.

Where the time goes (before the sound, which is now about 6% more): about 42% playing the Atari's DLI, a quarter turning player 3 into Next sprites and the Copper's list, a quarter collisions, and only about 6% the game itself (moving the plane and the enemies, making the river, counting fuel and score). The last round sped up the DLI the most: the rows of an object that cannot be its last, and the lines it waits for its next object, now go through short loops that keep everything in the processor's registers, and the cycles of instructions nothing on screen sees are counted together with the next one it does, instead of one by one. That took the DLI from about half of the work to 42%.

The program switches the Next to 28 MHz itself. Only the speed depends on it, not what happens in the game. The DLI model counts the Atari's cycles, not the Z80's, so its result is the same however long the Z80 takes, and a frame that is late is simply shown twice. At 14 MHz an average frame would need about 1.3 frames' time and the busiest about 1.9: the game would run at about half speed, in jerks. At 7 MHz it would be unplayable. (These are scaled from 28 MHz, not measured.) Every Next and its emulators run at 28 MHz with a current core. At 28 MHz a real Next now and then makes the processor wait for memory. The core the speed was measured on (the one in the Xpeccy+ emulator) should account for that, but it has not been checked on real hardware.

## How we know it is right

After every frame the Next's copy of the Atari's memory is compared with the C++ port (which was itself checked against the original), and also with the original game running in an Atari emulator: the river, every object, the score, fuel, the collisions, the sprites' memory. And the final picture is compared dot for dot with what the C++ port draws. Hundreds of thousands of frames of games played by a simple robot player, on PAL and NTSC, are the same.
