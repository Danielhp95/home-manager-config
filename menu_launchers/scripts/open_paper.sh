#!/usr/bin/env bash
# Pick a paper out of ~/papers and open it in zathura. Bound to Super+Shift+P
# (hyprland/hyprland.lua).
PAPERS_LOCATION=~/papers

# vicinae's dmenu quick-look only renders real content for image/* and text
# mime types (verified in its resolveFilePreview(), src/server/src/qml/
# view-utils.cpp) — everything else, including application/pdf, falls back to
# a generic file-type icon. So instead of feeding PDF paths directly, render
# each one's first page to a cached PNG and feed *that*: the preview panel
# then shows real page content, and the selection is mapped back to the
# source PDF below. Needs poppler-utils (pdftoppm), added in home.nix.
THUMB_DIR=~/.cache/paper-thumbnails
mkdir -p "$THUMB_DIR"

declare -A thumb_to_pdf
entries=()

while IFS= read -r -d '' pdf; do
	base=$(basename "$pdf")
	base="${base%.*}"
	thumb="$THUMB_DIR/$base.png"

	# Regenerate only if missing or the source PDF changed since.
	if [ ! -e "$thumb" ] || [ "$pdf" -nt "$thumb" ]; then
		pdftoppm -f 1 -l 1 -png -singlefile -scale-to 1000 "$pdf" "$THUMB_DIR/$base" 2>/dev/null
	fi

	if [ -e "$thumb" ]; then
		thumb_to_pdf["$thumb"]="$pdf"
		entries+=("$thumb")
	else
		# Thumbnailing failed (e.g. corrupt PDF) — fall back to the PDF path
		# itself, which still gets quick-look's generic-icon treatment.
		entries+=("$pdf")
	fi
done < <(find "$PAPERS_LOCATION" -maxdepth 1 -type f -name '*.pdf' -print0)

# -W widens the window past the default 1536px (menu_launchers/default.nix):
# the quick-look panel takes a fixed 65% of it (detailRatio in vicinae's
# GenericListView.qml, not configurable), leaving only 35% for the list, and
# paper titles are long enough to truncate hard at the default size. 1850 is
# the most we can add while still fitting the laptop panel (eDP-1, 1920px);
# vicinae does not clamp a wider request to the monitor, it just overflows.
choice=$(printf '%s\n' "${entries[@]}" | vicinae dmenu -p "Choose paper" -W 1850)

# Guard on the selection, not on $?. Two reasons this is not the old
# `(($? == 0))`: the pipeline's status is printf's, which is always 0, and
# vicinae exits 0 when dismissed without a choice as well (verified). Between
# them, cancelling used to run zathura on the ~/papers directory itself.
[ -n "$choice" ] && exec zathura "${thumb_to_pdf[$choice]:-$choice}"
