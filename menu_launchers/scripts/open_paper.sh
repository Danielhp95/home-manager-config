# Pick a paper from ~/papers and open it in zathura. Packaged as `open-paper`
# by ../default.nix, which supplies the shebang, strict mode and PATH.
PAPERS_LOCATION=~/papers

# vicinae's quick-look previews only images and text, so each PDF's first page
# is cached as a PNG and listed instead; the choice maps back to the PDF.
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
		pdftoppm -f 1 -l 1 -png -singlefile -scale-to 1000 "$pdf" "$THUMB_DIR/$base" 2>/dev/null || true
	fi

	if [ -e "$thumb" ]; then
		thumb_to_pdf["$thumb"]="$pdf"
		entries+=("$thumb")
	else
		# Thumbnailing failed (e.g. a corrupt PDF): list the PDF itself.
		entries+=("$pdf")
	fi
done < <(find "$PAPERS_LOCATION" -maxdepth 1 -type f -name '*.pdf' -print0)

# -W: the preview takes a fixed 65% of the window, so widen it for long titles.
# 1850 still fits eDP-1 (1920 logical px); vicinae doesn't clamp, it overflows.
choice=$(printf '%s\n' "${entries[@]}" | vicinae dmenu -p "Choose paper" -W 1850)

# vicinae exits 0 when dismissed too; an empty choice would open ~/papers.
if [ -n "$choice" ]; then
	exec zathura "${thumb_to_pdf[$choice]:-$choice}"
fi
