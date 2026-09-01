#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_image="$script_dir/눈깔콘경보.png"
overlay_dir="$script_dir/스즈미콘"
output_gif="$script_dir/눈깔콘경보.gif"

for command in magick shuf; do
  command -v "$command" >/dev/null || {
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  }
done

[[ -f "$base_image" ]] || {
  printf 'Base image not found: %s\n' "$base_image" >&2
  exit 1
}
[[ -d "$overlay_dir" ]] || {
  printf 'Overlay directory not found: %s\n' "$overlay_dir" >&2
  exit 1
}

mapfile -d '' images < <(
  find "$overlay_dir" -type f \( \
    -iname '*.png' -o -iname '*.gif' -o -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tif' -o -iname '*.tiff' \
    -o -iname '*.avif' -o -iname '*.jxl' \
  \) -print0
)

((${#images[@]})) || {
  printf 'No image files found in: %s\n' "$overlay_dir" >&2
  exit 1
}

mapfile -d '' shuffled_images < <(printf '%s\0' "${images[@]}" | shuf -z)

tmpdir=$(mktemp -d)
output_tmp=$(mktemp --suffix=.gif "$script_dir/.눈깔콘경보.XXXXXX")
cleanup() {
  rm -rf -- "$tmpdir"
  rm -f -- "$output_tmp"
}
trap cleanup EXIT

frames=()
frame_number=0
for image in "${shuffled_images[@]}"; do
  output_frame=$(printf '%s/frame-%06d.png' "$tmpdir" "$frame_number")
  # Treat animated GIFs as still images by using only their first frame.
  magick "$base_image" "${image}[0]" -geometry +254+8 -composite "$output_frame"
  frames+=("$output_frame")
  ((frame_number += 1))
done

# GIF delays are centiseconds.  50 FPS is the highest constant frame rate
# representable by GIF, with an even 2-centisecond delay per frame.
gif_inputs=()
for frame in "${frames[@]}"; do
  gif_inputs+=(-delay 2 "$frame")
done

magick -loop 0 "${gif_inputs[@]}" -layers Optimize -dither None -colors 256 "$output_tmp"
mv -f -- "$output_tmp" "$output_gif"
printf 'Created %s with %d frames.\n' "$output_gif" "${#frames[@]}"
