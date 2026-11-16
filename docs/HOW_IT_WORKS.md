# How River Raid works on the ZX Spectrum Next

English | [Русский](HOW_IT_WORKS.ru.md)

This is for anyone curious, no programming needed. How the game itself works (the river, enemies, bridges, why it gets harder) is told in the C++ port's [docs/HOW_IT_WORKS.md](https://github.com/djdron/river_raid/blob/main/docs/HOW_IT_WORKS.md). Here: how the Atari's picture and its collisions are made on a different computer, the ZX Spectrum Next.

## Two different machines

The Atari 800 of 1979 has a 6502 processor at 1.79 MHz; the Next has a Z80 at up to 28 MHz. Both are 8-bit computers, but their video chips work very differently.

The **Atari** draws the screen line by line, as the TV's beam goes. For moving things it has only eight "sprites": four **players** (each 8 dots wide) and four **missiles** (each 2 dots wide). Eight is far too few for River Raid's plane, jets, helicopters, ships, tanks, balloons, fuel depots and bridges, so the game cheats: it re-uses one player for every enemy down the screen. While the beam draws the screen, a small piece of code (the *display list interrupt*, DLI) wakes up before each object, moves player 3 to the object's place, gives it the object's shape and colour row by row, and when the object is finished, moves the same player down to the next object. Ten objects on screen are really one player, moved ten times during one picture.

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

The Next's video chip has nothing like that, so the Next works it out, for each line where something moves: which dots of each player and missile are lit, and what is under them.

There is a catch. The DLI reads the collision registers while the screen is still being drawn, and the Atari's chips and processor share their time very precisely. Whether a touch on the line being drawn "counts" for this object or for the next one depends on exactly at which moment of the line the processor reads the register. To get it right the Next keeps an exact clock of the Atari: it counts, for every instruction of the DLI, how many of the Atari's machine cycles it takes, and lets the "beam" draw each line at the right moment in between. This is the most delicate part of the port, and it is the same model the C++ port uses, checked against the original.

To make it fast, the Next only works out the collisions the game actually reads (ten of the sixty-four the Atari's chip keeps track of): the plane with the bank, the bullet with the bank and with objects, the objects with the bank edge, the tank with the edge, the helicopter's missile with the plane and the bank, the shell with the plane and objects. Two sprites far apart on the line are not compared dot by dot. And water is never a collision in River Raid, so when there is only water under a sprite, there is nothing to look at.

## The panel and the scrolling line

Below the river the Atari shows a panel in large letters (score, game number, fuel gauge, high score, bridge) and a line that scrolls the credits, with a rainbow Activision logo.

On the Next these are made of *tiles*: small 8×8 pictures arranged in a grid, like letters on a page. When the program starts, it builds the Atari's own letters (the ones the game makes from the computer's font and its own symbols) and turns each into two tiles. Every frame it writes the panel's letters as tiles. The scrolling line moves sideways two dots a frame: the tile layer itself is shifted, and the one tile that would show at both edges of the screen at once is made fresh every frame.

The panel's grey background is the colour the Next shows where nothing at all is drawn, so the fuel needle (a sprite) appears over the grey but under the letters, as on the Atari. The rainbow logo is five sprites.

## Time

All of this has to happen within a fiftieth of a second. The Next runs at 28 MHz, about sixteen times faster than the Atari, but playing the Atari's DLI cycle by cycle is slow. After three rounds of speeding up, a frame takes about two thirds of the time it may on average, and the busiest moments (tanks, shells and missiles beside the enemies) almost all of it. About once in a minute of play a frame is a little late and shown twice. On NTSC, at sixty frames a second, there is less time per frame and more frames are late.

## How we know it is right

After every frame the Next's copy of the Atari's memory is compared with the C++ port (which was itself checked against the original), and also with the original game running in an Atari emulator: the river, every object, the score, fuel, the collisions, the sprites' memory. And the final picture is compared dot for dot with what the C++ port draws. Hundreds of thousands of frames of games played by a simple robot player, on PAL and NTSC, are the same.
