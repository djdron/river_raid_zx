#!/bin/sh
# The program against the original cartridge: runs of rr_oracle (the original on libatari800,
# from the C++ port's repository: deps/river_raid/oracle) compared with the program frame by
# frame (nxcheck -oracle): the attract mode, a bot game to game over and a new start, a
# two-player game, flying and refuelling; NTSC and PAL.
#
# usage: tools/check_original.sh <River_Raid.rom>
set -e
ROM=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
HERE=$(cd "$(dirname "$0")/.." && pwd)
ORACLE="$HERE/deps/river_raid/oracle"
OUT="$HERE/build/oracle"
[ -x "$ORACLE/rr_oracle" ] || (cd "$ORACLE" && sh build.sh)
status=0
run() {	# name, script, frames, standard, rr_oracle options
	name=$1; script=$2; frames=$3; std=$4; shift 4
	mkdir -p "$OUT/$name"
	(cd "$ORACLE" && ./rr_oracle "$ROM" "scripts/$script" "$frames" "$OUT/$name" "$@" > /dev/null 2>&1)
	start=38; [ "$std" = -pal ] && start=25
	"$HERE/build/tools/nxcheck" "$ROM" "$HERE/build" $((frames - start - 1)) $std -oracle "$OUT/$name" | grep -v "^  " | tail -3 || true
}
run attract attract_idle.txt 2300 -ntsc
run bot start_only.txt 8000 -ntsc -bot
run two two_players.txt 7800 -ntsc
run fly start_and_fly.txt 1000 -ntsc
run refuel refuel_first_depot.txt 2000 -ntsc
run attract_pal attract_idle.txt 3000 -pal -pal
run bot_pal start_only.txt 6000 -pal -pal -bot
run two_pal two_players.txt 7800 -pal -pal
exit $status
