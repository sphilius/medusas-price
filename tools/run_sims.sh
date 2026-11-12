#!/usr/bin/env bash
# run_sims.sh - dev-only: run every headless sim in tools/ with Godot 4.7.2 and print
# one line per sim (exit code = number of failed checks; 124 = it hung and was killed).
# Usage from the project root (Git Bash):  bash tools/run_sims.sh [name ...]
# With no names it runs all tools/sim_*.tscn.
# Default Godot: the WinGet install under the current user's Local AppData folder, so no
# username is written into the repo. cygpath turns Windows' C:\Users\... form into Git
# Bash's /c/Users/... form. Set GODOT to use any other Godot build.
G="${GODOT:-$(cygpath -u "${LOCALAPPDATA:-C:/missing}")/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
names=("$@")
if [ ${#names[@]} -eq 0 ]; then
	# sim_room.tscn is the shared test room the sims load, not a sim itself.
	for f in tools/sim_*.tscn; do n=$(basename "$f" .tscn); [ "$n" = sim_room ] || names+=("${n#sim_}"); done
fi
bad=0
for s in "${names[@]}"; do
	log="${TMPDIR:-/tmp}/sim_$s.txt"
	timeout 180 "$G" --headless --path . "res://tools/sim_$s.tscn" > "$log" 2>&1
	code=$?
	echo "sim_$s exit $code"
	if [ $code -ne 0 ]; then
		bad=$((bad + 1))
		grep -E "FAIL|SCRIPT ERROR" "$log" | sort | uniq -c | head -5
	fi
done
echo "$bad sim(s) failed"
exit $bad
