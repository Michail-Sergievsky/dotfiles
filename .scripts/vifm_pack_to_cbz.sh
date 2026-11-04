#!/bin/bash
# pack_to_cbz_v3.sh — create .cbz archives from comic folders using zip
# After successful packing, remove original folders.
# Also generate a *_missing.txt report listing folders with no images.
# Dependencies: zip (install via: sudo pacman -S zip)

shopt -s nullglob

main_dir=$(basename "$PWD")
missing_file="${main_dir}_missing.txt"
> "$missing_file"  # clear previous report

for dir in */; do
    dir=${dir%/}
    [[ ! -d "$dir" ]] && continue

    output="${dir}.cbz"

    # Skip if already packed
    if [[ -f "$output" ]]; then
        echo "⏭️ Skipping '$dir' (already packed)"
        continue
    fi

    # Detect image files
    images=("$dir"/*.[jJ][pP][gG] "$dir"/*.[jJ][pP][eE][gG] "$dir"/*.[pP][nN][gG])
    has_images=false
    for img in "${images[@]}"; do
        if [[ -f "$img" ]]; then
            has_images=true
            break
        fi
    done

    # If no images — log to missing file
    if [[ "$has_images" == false ]]; then
        echo "⚠️ No images found in '$dir' — skipping."
        echo "$dir" >> "$missing_file"
        continue
    fi

    echo "📦 Packing: $dir → $output"
    if zip -r -9 -q "$output" "$dir"; then
        echo "✅ Created: $output"
        rm -rf "$dir"
        echo "🗑️ Removed folder: $dir"
    else
        echo "❌ Failed: $dir"
    fi
done

if [[ -s "$missing_file" ]]; then
    echo "📋 Missing issues recorded in: $missing_file"
else
    rm -f "$missing_file"
    echo "✅ No missing folders detected."
fi

echo "🎉 All done."
