# ptplay

a crappy MOD player for the fox32 architecture. small (only 9k) and average speed (~200 instructions at minimum, ~1000 instructions at max)

# what it does not do

the player has some limitations, namely:
- no tremolo effect implementation
- no instrument swap behaviour
- several other ProTracker 1/2 playback quirks (i hate them so god damn much `>:(`)

# how to build

just do: `fox32asm ptplay.asm ptplay.fxf` and then add it into a RYFS image.

# how to use in your apps

include the `ptplayer.asm` source file and call the following subroutines:

- `mt_init` (r0 - the address of the module, r1 - starting playback order, r2 - 0=exit after init, 1=install VSYNC interrupt handler)
- `mt_play` (WILL clobber r29, r30, and r31 - you can save them, but sometimes it crashes for no reason. save at your own risk)
- `mt_exit` (stops playback and removes VSYNC interrupt if there was one)

# why is it so terribly coded?

i wrote it to work, not to be readable or clean. perhaps i will rewrite this at some point. there are memory corruption bugs that
i really cannot be arsed to fix at this point.