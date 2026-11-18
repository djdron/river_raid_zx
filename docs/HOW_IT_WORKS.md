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

The Next does not play the Atari's DLI any more; it keeps only its timetable. The DLI goes down the screen object by object: it waits for the line where the next object starts, writes its rows one line each, reads the collisions on the next few lines, and moves on. If an object comes too close below the previous one, the DLI is still busy with the previous one's collisions and reaches it a few lines late: its top rows are not drawn. At the bottom of the river the rows are cut off. The Next works out this timetable with a few additions per object, and from it, for every object, which of its rows the Atari shows and on which lines.

Each object then becomes one ready-made Next sprite (two if it is taller than 16 lines). The Atari changes player 3's colour on every line (that is how enemies have stripes); a Next sprite can have a colour of its own in every dot, so the stripes are simply drawn into it. Each Atari dot becomes two dots of the sprite (the Atari's dots are wide), and double or quadruple width is the sprite drawn two or four times as wide. An object coming in from the top is drawn whole and the part above the river is cut off by the sprites' clip window.

Drawing a sprite's picture takes time, so the Next keeps the ones it has made: the next frame, the same shape in the same colours (most of the time) only moves the sprite. A new picture is drawn when the shape changes (a helicopter's rotor, an explosion) or when an object is cut off at the bottom.

The plane, its bullet, the tanks on the banks, the tank's shell and the helicopter's missile use the Atari's other players and missiles, which have one colour each and stay at one place all screen long. The game puts each at a known line (the plane always at the same height, the shell where the tank fired it...), so each is one sprite made from its rows there.

## Collisions: who touched what

On the Atari, the game never works out collisions itself. The video chip does it: while drawing, whenever a player's dot lands on a coloured dot of the playfield, or on another player's dot, it sets a bit in a collision register ("player 2 touched colour 1", "missile 2 touched player 3"). The DLI reads these registers after each object: that is how the game knows that the bullet hit this ship, that the plane flew into the bank, that a jet reached the edge and must turn.

These bits are only ever set, never cleared by the chip: they stay until the program clears them all at once (by writing to a register called HITCLR). And player 3 is every enemy in turn. Read once at the end of the frame, the registers would say only "player 3 touched something", not which ship. So after each object the DLI copies the registers into the game's memory, next to that object ("the bullet hit the object in slot 5"), clears them, and moves player 3 on to the next object. The game looks there later.

The Next's video chip has nothing like that, so the Next works it out itself, and only what the game reads: the plane with the bank, the bullet with the bank and with objects, the objects with the bank edge, the tank with the edge, the helicopter's missile with the plane and the bank, the shell with the plane and objects.

The Next does have one hardware flag of this kind: "two sprites overlapped". It is no help here. It says neither which sprites nor anything about the river (the banks are in Layer 2, not sprites). With up to sixty sprites a frame, it would be set by sprites the Atari would never have compared (the logo, the needle). And it is set only while the beam actually draws the sprites, a frame later, when the game needs to know in this one.

Every moving thing is where the game put it, so each collision is a question about a few lines. For each sprite: on its lines, do its dots touch the bank (or the edge)? For two sprites: on the lines both are on, do their dots meet? The work goes "cheap first, exact only if needed": first whether the stretches, from the first lit dot to the last, meet at all; only then the dots one by one (shapes have gaps a bullet can pass through). The bank is looked at without its houses and roads: then each line of the river is just bank, edge, water, edge, bank (twice with an island), a handful of numbers kept from when the line was made. And water is never a collision in River Raid.

Then comes the one place where the Atari's timing still matters. The game does not learn "the bullet hit something" but "the bullet hit the object in slot 5": the DLI read the chip's registers right after each object's rows and cleared them after its reads. So a collision is counted for the object whose reading window holds its line, the lines from the last clearing to the read; the timetable gives these windows. A bullet touching only an object's last row, for example, is counted by the original for no object, and so it is here. The windows are exact to the line because of the Atari's cycles in two or three places (whether a read comes before or after the line's drawing, and the DLI falling a line behind on a busy line); these few rules are all that is left of counting cycles.

What it costs: the timetable about 48 000 of the Next's processor ticks a frame, the collisions about 31 000: together about 14% of a fiftieth of a second. When the DLI still had to be played cycle by cycle with the chip's registers emulated line by line, the same came to about 210 000.

## The panel and the scrolling line

Below the river the Atari shows a panel in large letters (score, game number, fuel gauge, high score, bridge) and a line that scrolls the credits, with a rainbow Activision logo.

On the Next these are made of *tiles*: small 8×8 pictures arranged in a grid, like letters on a page. When the program starts, it builds the Atari's own letters (the ones the game makes from the computer's font and its own symbols) and turns each into two tiles. Every frame it writes the panel's letters as tiles. The scrolling line moves sideways two dots a frame: the tile layer itself is shifted, and the one tile that would show at both edges of the screen at once is made fresh every frame.

The panel's grey background is the river's own layer, with its four colours turned grey by the Copper for the panel's lines, so it is exactly as wide as the river, and the fuel needle (a sprite) appears over the grey but under the letters, as on the Atari. The rainbow logo is five sprites.

The Next's picture is 320 dots wide: everything it can draw is in there, and around it only a single colour (the border). The Atari's picture is a little wider: the river and panel by 8 of its pixels on the left, the scrolling line by about 3 of its letters. So in the attract mode the scrolling text is cut at the edges. A strip of colour in the border would not help: no picture can go there, and the planes would vanish over it.

## Sound

The Atari's sound chip, POKEY, has four channels. Each counts down a fast clock (64 000 ticks a second) from a number the game sets, and every time the count runs out it gives a pulse; what a pulse does depends on another setting: flip the channel's output (a clean tone, higher the smaller the number), or take a bit from one of POKEY's shift registers, which give a long, random-looking stream of bits (noise: the engine, explosions). Each channel also has a volume. The game itself only sets these numbers once a frame: the engine's pitch from the speed, a falling whistle for the tank's shell, a hiss for an explosion.

The Next has no POKEY, but it has a DAC: a port where a number becomes a voltage, so a stream of numbers is a sound wave. So the Next works out POKEY's output itself, 15 909 numbers a second, about 320 a frame, and leaves them in a ring of memory. Sending them to the DAC one by one, at exactly the right moments, would take the processor's whole time; the Next's DMA does it instead, a piece of hardware that copies a byte from memory to the port every 1/15 909 of a second on its own, round and round the ring. The processor only has to keep the ring filled a little ahead of it, and keep the ring where the DMA looks (the sound is as loud as the Next's mixer lets one DAC be: about half the C++ port's at the same settings, the same sound underneath; and mono, as the Atari's): the DMA reads memory through the same windows as the processor, and when the code briefly put another piece of memory in the ring's window, the DMA played that instead, a click every frame.

The pure tones (the beeps, refuelling, firing, the shell's whistle) skip all this: the Next also has AY sound chips, which make exactly that square wave themselves, so those POKEY channels are just handed to an AY with the pitch and volume converted. Only the noises (the engine, explosions, the helicopter's missile) are worked out for the DAC.

Working the wave out tick by tick would be far too slow. Instead each channel jumps from pulse to pulse: it knows how many samples away its next pulse is, and between pulses its output does not change. Where the output turns on or off, it writes "+ volume" or "− volume" into the ring; at the end one pass adds them up into the wave. This costs about 25 000 of the processor's ticks a frame, 4% of a fiftieth of a second; the busiest (engine, explosion, firing and a missile at once) more than twice that. The ring is kept about two and a half frames ahead of the DMA, so a frame with a lot of other work can make fewer numbers and leave the rest to the next frames; and when the game has more work than time, the sound gives way, not the game.

## Why not the Next's line interrupts

The Next can also interrupt its processor at any chosen line of the screen. The port does not use that, because it does not need to keep up with the beam. What the Atari's DLI did is worked out ahead of time, as a calculation, while the previous picture is still showing. What has to change at a particular line of the real screen (the road's colour) is written into the Copper's list, and the Copper, which never misses a line, does it; the list is sent to the Copper again only when it changes. The processor only has to watch which line the beam is on, to switch to the new frame below the scrolling line, where nothing changes on the screen (interrupts stay off). The sound, played sample by sample through the Next's DAC, does not need them either: the Next's DMA does that without the processor (see Sound).

## Time

All of this has to happen within a fiftieth of a second. The Next runs at 28 MHz, about sixteen times faster than the Atari. An average frame now takes about 30% of the time it may, the busiest about 50%; at the busy bridges (50 and on) on NTSC, at sixty frames a second, no frame in thousands is late (before, 43% were).

It was not always so. Playing the Atari's DLI cycle by cycle, with its collision registers emulated line by line, took about 60% of the frame on average and up to 88%; at the busy bridges a frame was often late. Then, step by step, first in the C++ port and checked against the original each time: the cycles were dropped but for a few rules; the enemies became ready-made multicolour sprites; the other sprites were taken from where the game put them instead of searched for; the edge test looks at a row's first and last dots first; the collisions are worked out from the sprites' rows; and finally the DLI's loop became a timetable, with nothing written line by line.

Where the time goes now (PAL, average): the timetable about 28%, collisions 18%, sprites 15%, sound 11%, the river's new lines into Layer 2 11%, the game itself 9%, the rest the panel and the frame's housekeeping.

The program switches the Next to 28 MHz itself. Only the speed depends on it, not what happens in the game, and a frame that is late is simply shown twice. Every Next and its emulators run at 28 MHz with a current core. At 28 MHz a real Next now and then makes the processor wait for memory; the emulator's core the speed was measured on should account for that, but it has not been checked on real hardware.

## How we know it is right

Every change to what the game does is made first in the C++ port and compared there with the original game running in an Atari emulator: after every frame the whole of the Atari's memory (the river, every object, the score, fuel, the collisions), and the river as drawn against the original's screen, dot for dot.

Then the Next: after every frame its copy of the Atari's memory is compared with the C++ port, and so are the objects it draws, the bank's colours line by line and the Copper's list; at the end the whole picture, dot for dot. Hundreds of thousands of frames of games played by a simple robot player, on PAL and NTSC, from the first bridge to bridge 200 (the robot can be made unable to crash, on both sides, to get that far), are the same.

One difference from the original is known, and left as it is. On a very busy line the Atari's DLI sometimes falls a line behind; then the rows of an object it writes late are not seen, and the Atari shows that object's rows from the frame before for a frame or two. The Next draws the new rows. It happens about twice in 100 000 frames, only at the far bridges, and changes nothing in the game.
