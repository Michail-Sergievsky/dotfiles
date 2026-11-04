#!/bin/bash
# repack_to_webp_cbz_v12.sh
#
# Converts CBZ/CBR archives and folders with "digital" or "hybrid" in the name
# to optimized WebP-based CBZ archives.
#
# Logic:
#   - recursive search under current directory
#   - detects each page as color or black/white
#   - color pages: cwebp q85 + preset photo
#   - black/white pages: cwebp q70 without preset photo
#   - before full conversion, randomly tests up to 10 images
#   - if sample WebP size is bigger or same as sample original size, skips archive/folder
#   - after full repack, compares final CBZ with original archive/folder
#   - if output CBZ is smaller: keep output and remove original
#   - if output CBZ is bigger or same size: remove output and keep original
#
# Important:
#   - skips *_webp.cbz
#   - uses temp directory near source file, not /tmp
#   - removes macOS junk: __MACOSX, ._*, .DS_Store
#   - fallback via ImageMagick for CMYK/problem JPEG files
#   - writes only problems/warnings to separate error log
#   - error log filename contains date and time
#   - error log is created in directory where script was launched

set -u
shopt -s nullglob

COLOR_QUALITY=85
BW_QUALITY=70
BW_SATURATION_THRESHOLD="0.035"

SAMPLE_IMAGES=5

START_DIR="$(pwd)"
RUN_TS="$(date '+%Y-%m-%d_%H-%M-%S')"
ERROR_LOG="$START_DIR/repack_webp_errors_$RUN_TS.log"
ERRORS_FOUND=0

# ---------- error logging ----------

log_problem() {
    local level="$1"
    local target="$2"
    local message="$3"

    ERRORS_FOUND=1

    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level]"
        echo "Target: $target"
        echo "Problem: $message"
        echo "------------------------------------------------------------"
    } >> "$ERROR_LOG"
}

finish_message() {
    echo "------------------------------------------------------------"

    if [[ "$ERRORS_FOUND" -eq 1 && -f "$ERROR_LOG" ]]; then
        echo "⚠️  Finished with problems/warnings."
        echo "📝 Problems-only log:"
        echo "   $ERROR_LOG"
    else
        echo "✅ Finished without logged problems."
    fi

    echo "🎉 All done."
}

trap finish_message EXIT

# ---------- dependencies ----------

for cmd in zip unzip cwebp realpath find grep sort df date stat du awk cp shuf; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ Missing dependency: $cmd"
        echo "   Install with:"
        echo "   sudo pacman -S libwebp-utils zip unzip coreutils grep findutils unrar libarchive imagemagick"

        log_problem "ERROR" "dependency check" "Missing dependency: $cmd"
        exit 1
    fi
done

MAGICK_AVAILABLE=0
UNRAR_AVAILABLE=0
BSDTAR_AVAILABLE=0

command -v magick >/dev/null 2>&1 && MAGICK_AVAILABLE=1
command -v unrar  >/dev/null 2>&1 && UNRAR_AVAILABLE=1
command -v bsdtar >/dev/null 2>&1 && BSDTAR_AVAILABLE=1

if [[ "$MAGICK_AVAILABLE" -eq 0 ]]; then
    echo "⚠️  ImageMagick not found — black/white detection and CMYK JPEG fallback unavailable."
    echo "   Install with: sudo pacman -S imagemagick"
    log_problem "WARNING" "dependency check" "ImageMagick command 'magick' not found. BW detection and CMYK/problem JPEG fallback unavailable."
fi

if [[ "$UNRAR_AVAILABLE" -eq 0 && "$BSDTAR_AVAILABLE" -eq 0 ]]; then
    echo "⚠️  No unrar or bsdtar found — .cbr files will be skipped."
    log_problem "WARNING" "dependency check" "No unrar or bsdtar found. CBR archives cannot be extracted."
fi

# ---------- helpers ----------

should_process() {
    local name="$1"
    [[ "$name" =~ [Dd][Ii][Gg][Ii][Tt][Aa][Ll] || "$name" =~ [Hh][Yy][Bb][Rr][Ii][Dd] ]]
}

is_webp_output() {
    local name="$1"
    [[ "$name" =~ _[Ww][Ee][Bb][Pp]\.[Cc][Bb][Zz]$ ]]
}

file_size_bytes() {
    local file="$1"

    if [[ -f "$file" ]]; then
        stat -c '%s' "$file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

dir_size_bytes() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        du -sb "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

clean_macos_junk() {
    local dir="$1"

    echo "🧹 Removing macOS junk from: $dir"

    find "$dir" -type d -name "__MACOSX" -prune -exec rm -rf {} + 2>/dev/null || true
    find "$dir" -type f -name "._*" -delete 2>/dev/null || true
    find "$dir" -type f -name ".DS_Store" -delete 2>/dev/null || true
    find "$dir" -type f -name "*.repack_tmp_srgb.png" -delete 2>/dev/null || true
    find "$dir" -type f -size 0 -iname "*.webp" -delete 2>/dev/null || true
}

count_source_images() {
    local dir="$1"

    find "$dir" -type f \( \
        -iname "*.jpg"  -o \
        -iname "*.jpeg" -o \
        -iname "*.png" \
    \) \
    ! -name "*.repack_tmp_srgb.png" \
    | wc -l
}

count_webp_images() {
    local dir="$1"

    find "$dir" -type f -iname "*.webp" | wc -l
}

free_space_info() {
    local dir="$1"
    df -h "$dir" | tail -1
}

detect_image_mode() {
    local img="$1"
    local sat=""

    if [[ "$MAGICK_AVAILABLE" -eq 0 ]]; then
        echo "color"
        return
    fi

    sat="$(
        magick "$img" \
            -auto-orient \
            -resize 512x512\> \
            -colorspace sRGB \
            -colorspace HSL \
            -channel G \
            -separate \
            -format "%[fx:mean]" info: 2>/dev/null
    )"

    if [[ -z "$sat" ]]; then
        echo "color"
        return
    fi

    awk -v s="$sat" -v t="$BW_SATURATION_THRESHOLD" '
        BEGIN {
            if (s < t) {
                print "bw"
            } else {
                print "color"
            }
        }
    '
}

cwebp_encode_by_mode() {
    local mode="$1"
    local input="$2"
    local output="$3"

    case "$mode" in
        bw)
            cwebp -quiet -mt -q "$BW_QUALITY" "$input" -o "$output"
            ;;
        color|*)
            cwebp -quiet -preset photo -mt -q "$COLOR_QUALITY" "$input" -o "$output"
            ;;
    esac
}

encode_image_with_fallback() {
    local img="$1"
    local outimg="$2"
    local mode="$3"
    local cwebp_err=""
    local magick_err=""
    local fallback_err=""
    local tmp_png=""

    rm -f "$outimg"

    cwebp_err="$(cwebp_encode_by_mode "$mode" "$img" "$outimg" 2>&1)"

    if [[ "$?" -eq 0 && -s "$outimg" ]]; then
        return 0
    fi

    rm -f "$outimg"

    if [[ "$MAGICK_AVAILABLE" -eq 0 ]]; then
        log_problem "ERROR" "$img" "cwebp failed and ImageMagick fallback is unavailable. cwebp output: $cwebp_err"
        return 1
    fi

    tmp_png="${img%.*}.repack_tmp_srgb.png"

    magick_err="$(magick "$img" -auto-orient -colorspace sRGB "$tmp_png" 2>&1)"

    if [[ "$?" -ne 0 || ! -s "$tmp_png" ]]; then
        rm -f "$tmp_png"
        log_problem "ERROR" "$img" "ImageMagick failed to convert image to sRGB PNG. cwebp output: $cwebp_err ; magick output: $magick_err"
        return 1
    fi

    fallback_err="$(cwebp_encode_by_mode "$mode" "$tmp_png" "$outimg" 2>&1)"

    rm -f "$tmp_png"

    if [[ "$?" -eq 0 && -s "$outimg" ]]; then
        return 2
    fi

    rm -f "$outimg"

    log_problem "ERROR" "$img" "Fallback cwebp failed after ImageMagick conversion. First cwebp output: $cwebp_err ; fallback cwebp output: $fallback_err"

    return 1
}

# Return codes:
#   0 = sample says full conversion is probably useful
#   1 = sample conversion failed
#   2 = sample says conversion is not useful, skip this archive/folder
sample_conversion_check() {
    local dir="$1"
    local label="$2"
    local sample_dir="$dir/.repack_sample_test"
    local sample_count=0
    local original_total=0
    local webp_total=0
    local original_size=0
    local webp_size=0
    local mode=""
    local sample_out=""
    local sample_name=""
    local result=0

    rm -rf "$sample_dir"
    mkdir -p "$sample_dir"

    echo "🧪 Sampling up to $SAMPLE_IMAGES random images before full conversion..."

    while IFS= read -r -d '' img; do
        sample_count=$((sample_count + 1))
        original_size="$(file_size_bytes "$img")"
        original_total=$((original_total + original_size))

        mode="$(detect_image_mode "$img")"
        sample_name="sample_${sample_count}.webp"
        sample_out="$sample_dir/$sample_name"

        echo "   🧪 Sample $sample_count: $img"
        if [[ "$mode" == "bw" ]]; then
            echo "      Mode: black/white, q${BW_QUALITY}, no preset"
        else
            echo "      Mode: color, q${COLOR_QUALITY}, preset photo"
        fi

        if encode_image_with_fallback "$img" "$sample_out" "$mode"; then
            webp_size="$(file_size_bytes "$sample_out")"
            webp_total=$((webp_total + webp_size))

            echo "      Original: $original_size bytes"
            echo "      WebP:     $webp_size bytes"
        else
            echo "   ❌ Sample conversion failed: $img"
            rm -rf "$sample_dir"
            log_problem "ERROR" "$label" "Sample conversion failed. Full conversion skipped. Failed image: $img"
            return 1
        fi
    done < <(
        find "$dir" -type f \( \
            -iname "*.jpg"  -o \
            -iname "*.jpeg" -o \
            -iname "*.png" \
        \) \
        ! -name "*.repack_tmp_srgb.png" \
        ! -path "$sample_dir/*" \
        -print0 | shuf -z -n "$SAMPLE_IMAGES"
    )

    rm -rf "$sample_dir"

    if [[ "$sample_count" -eq 0 ]]; then
        echo "⚠️  No images available for sample check."
        log_problem "WARNING" "$label" "No images available for sample check."
        return 1
    fi

    echo "🧪 Sample result:"
    echo "   Sample images: $sample_count"
    echo "   Original total: $original_total bytes"
    echo "   WebP total:     $webp_total bytes"

    if (( webp_total >= original_total )); then
        echo "⏭️  Sample WebP is not smaller. Skipping full conversion."
        log_problem "WARNING" "$label" "Sample WebP was not smaller than originals. Full conversion skipped. Sample original total: $original_total bytes ; sample WebP total: $webp_total bytes"
        return 2
    fi

    echo "✅ Sample WebP is smaller. Proceeding with full conversion."
    return 0
}

convert_one_image() {
    local img="$1"
    local outimg="$2"
    local mode=""
    local result=0

    mode="$(detect_image_mode "$img")"

    if [[ "$mode" == "bw" ]]; then
        echo "   🖤 Mode: black/white, q${BW_QUALITY}, no preset"
    else
        echo "   🌈 Mode: color, q${COLOR_QUALITY}, preset photo"
    fi

    encode_image_with_fallback "$img" "$outimg" "$mode"
    result="$?"

    return "$result"
}

convert_images_in_dir() {
    local dir="$1"
    local failed=0
    local converted=0
    local converted_fallback=0
    local skipped_existing_webp=0
    local result=0

    while IFS= read -r -d '' img; do
        local outimg="${img%.*}.webp"

        if [[ -f "$outimg" ]]; then
            if [[ -s "$outimg" ]]; then
                echo "   ⏭️  WebP already exists, removing source: $img"
                rm -f "$img"
                skipped_existing_webp=$((skipped_existing_webp + 1))
                continue
            else
                echo "   ⚠️  Existing WebP is empty, recreating: $outimg"
                rm -f "$outimg"
            fi
        fi

        echo "   🖼️  Converting: $img"

        convert_one_image "$img" "$outimg"
        result="$?"

        case "$result" in
            0)
                rm -f "$img"
                converted=$((converted + 1))
                ;;
            2)
                rm -f "$img"
                converted_fallback=$((converted_fallback + 1))
                echo "   ✅ Converted with ImageMagick fallback: $outimg"
                ;;
            *)
                echo "   ❌ Failed to convert: $img"
                rm -f "$outimg"
                failed=1
                ;;
        esac
    done < <(
        find "$dir" -type f \( \
            -iname "*.jpg"  -o \
            -iname "*.jpeg" -o \
            -iname "*.png" \
        \) \
        ! -name "*.repack_tmp_srgb.png" \
        ! -path "*/.repack_sample_test/*" \
        -print0
    )

    echo "   Converted images: $converted"
    echo "   Converted with ImageMagick fallback: $converted_fallback"
    echo "   Existing WebP skipped: $skipped_existing_webp"

    return "$failed"
}

extract_archive() {
    local file="$1"
    local tmpdir="$2"
    local ext="${file##*.}"
    local abs_file
    local extract_err=""

    abs_file="$(realpath "$file")"

    case "$ext" in
        cbz|CBZ)
            extract_err="$(unzip -qq "$abs_file" -d "$tmpdir" 2>&1)"
            if [[ "$?" -ne 0 ]]; then
                log_problem "ERROR" "$file" "Failed to extract CBZ with unzip. Output: $extract_err"
                return 1
            fi
            return 0
            ;;
        cbr|CBR)
            if [[ "$UNRAR_AVAILABLE" -eq 1 ]]; then
                extract_err="$(unrar x -idq "$abs_file" "$tmpdir/" 2>&1)"
                if [[ "$?" -ne 0 ]]; then
                    log_problem "ERROR" "$file" "Failed to extract CBR with unrar. Output: $extract_err"
                    return 1
                fi
                return 0
            elif [[ "$BSDTAR_AVAILABLE" -eq 1 ]]; then
                extract_err="$(bsdtar -xf "$abs_file" -C "$tmpdir" 2>&1)"
                if [[ "$?" -ne 0 ]]; then
                    log_problem "ERROR" "$file" "Failed to extract CBR with bsdtar. Output: $extract_err"
                    return 1
                fi
                return 0
            else
                log_problem "ERROR" "$file" "Cannot extract CBR: neither unrar nor bsdtar is available."
                return 1
            fi
            ;;
        *)
            log_problem "ERROR" "$file" "Unsupported archive extension: .$ext"
            return 1
            ;;
    esac
}

make_cbz_from_dir_contents() {
    local src_dir="$1"
    local out_abs="$2"
    local zip_err=""

    zip_err="$(
        cd "$src_dir" && zip -r -9 -q "$out_abs" . 2>&1
    )"

    if [[ "$?" -ne 0 ]]; then
        log_problem "ERROR" "$src_dir" "Failed to create CBZ archive: $out_abs ; zip output: $zip_err"
        return 1
    fi

    if [[ ! -s "$out_abs" ]]; then
        log_problem "ERROR" "$src_dir" "Created CBZ archive is missing or empty: $out_abs"
        return 1
    fi

    return 0
}

safe_remove_tmpdir() {
    local tmpdir="$1"

    if [[ -n "$tmpdir" && -d "$tmpdir" && "$tmpdir" == *".repack_webp_tmp."* ]]; then
        rm -rf "$tmpdir"
    fi
}

# ---------- processors ----------

process_archive() {
    local file="$1"
    local parent
    local filename
    local base
    local ext
    local tmpdir
    local out_abs
    local img_count
    local webp_count
    local original_archive_size=0
    local output_archive_size=0
    local sample_result=0

    parent="$(dirname "$file")"
    filename="$(basename "$file")"
    base="${filename%.*}"
    ext="${filename##*.}"

    echo "------------------------------------------------------------"
    echo "🔎 Archive candidate: $file"

    if is_webp_output "$filename"; then
        echo "⏭️  Skip: already *_webp.cbz"
        return
    fi

    if ! should_process "$filename"; then
        echo "⏭️  Skip: no digital/hybrid in filename"
        return
    fi

    case "$ext" in
        cbz|CBZ|cbr|CBR)
            ;;
        *)
            echo "⏭️  Skip: unsupported archive extension .$ext"
            return
            ;;
    esac

    out_abs="$(realpath -m "$parent/${base}_webp.cbz")"

    if [[ -f "$out_abs" ]]; then
        echo "⏭️  Skip: output already exists:"
        echo "   $out_abs"
        echo "   Remove it if you want to reconvert this archive."
        return
    fi

    original_archive_size="$(file_size_bytes "$file")"

    tmpdir="$parent/.repack_webp_tmp.$base"

    if [[ -e "$tmpdir" ]]; then
        echo "⚠️  Removing old temp directory:"
        echo "   $tmpdir"
        rm -rf "$tmpdir"
    fi

    mkdir -p "$tmpdir"

    echo "💾 Free space near source:"
    echo "   $(free_space_info "$parent")"

    echo "📦 Extracting archive → $tmpdir"

    if ! extract_archive "$file" "$tmpdir"; then
        echo "❌ Failed to extract archive: $file"
        safe_remove_tmpdir "$tmpdir"
        return
    fi

    clean_macos_junk "$tmpdir"

    img_count="$(count_source_images "$tmpdir")"
    webp_count="$(count_webp_images "$tmpdir")"

    echo "📊 Extracted source images: $img_count"
    echo "📊 Existing WebP images: $webp_count"

    if [[ "$img_count" -eq 0 ]]; then
        echo "⚠️  No JPG/JPEG/PNG images after extraction."
        log_problem "WARNING" "$file" "No JPG/JPEG/PNG images found after extraction."
        safe_remove_tmpdir "$tmpdir"
        return
    fi

    sample_conversion_check "$tmpdir" "$file"
    sample_result="$?"

    case "$sample_result" in
        0)
            ;;
        2)
            echo "⏭️  Full conversion skipped by sample test."
            echo "   Keeping original archive:"
            echo "   $file"
            safe_remove_tmpdir "$tmpdir"
            return
            ;;
        *)
            echo "❌ Sample test failed."
            echo "   Keeping original archive:"
            echo "   $file"
            safe_remove_tmpdir "$tmpdir"
            return
            ;;
    esac

    if ! convert_images_in_dir "$tmpdir"; then
        echo "❌ Some images failed to convert."
        echo "   Keeping original archive:"
        echo "   $file"
        echo "   Keeping temp dir for inspection:"
        echo "   $tmpdir"

        log_problem "ERROR" "$file" "Some images failed to convert. Original archive was kept. Temp dir kept for inspection: $tmpdir"
        return
    fi

    clean_macos_junk "$tmpdir"

    echo "📦 Repacking → $out_abs"

    if make_cbz_from_dir_contents "$tmpdir" "$out_abs" && [[ -f "$out_abs" ]]; then
        output_archive_size="$(file_size_bytes "$out_abs")"

        echo "📊 Original archive size: $original_archive_size bytes"
        echo "📊 Output archive size:   $output_archive_size bytes"

        if (( output_archive_size >= original_archive_size )); then
            echo "⏭️  Output archive is not smaller. Keeping original archive."
            echo "   Removing output archive:"
            echo "   $out_abs"

            rm -f "$out_abs"
            safe_remove_tmpdir "$tmpdir"

            log_problem "WARNING" "$file" "Output archive was not smaller than original. Original kept. Output removed. Original size: $original_archive_size bytes ; output size: $output_archive_size bytes"
            return
        fi

        echo "✅ Converted archive:"
        echo "   $file"
        echo "   → $out_abs"

        safe_remove_tmpdir "$tmpdir"

        echo "🧹 Removing original archive:"
        echo "   $file"
        rm -f "$file"
    else
        echo "❌ Failed to create output archive:"
        echo "   $out_abs"
        echo "   Keeping original archive and temp dir."

        log_problem "ERROR" "$file" "Failed to create output archive: $out_abs. Original archive and temp dir kept."
    fi
}

process_folder() {
    local src_dir="$1"
    local parent
    local base
    local tmpdir
    local out_abs
    local img_count
    local webp_count
    local original_folder_size=0
    local output_archive_size=0
    local sample_result=0

    parent="$(dirname "$src_dir")"
    base="$(basename "$src_dir")"

    echo "------------------------------------------------------------"
    echo "🔎 Folder candidate: $src_dir"

    if [[ "$base" == .repack_webp_tmp.* ]]; then
        echo "⏭️  Skip: temp working directory"
        return
    fi

    if [[ "$base" == "__MACOSX" ]]; then
        echo "⏭️  Skip: macOS metadata directory"
        return
    fi

    if ! should_process "$base"; then
        echo "⏭️  Skip: no digital/hybrid in folder name"
        return
    fi

    out_abs="$(realpath -m "$parent/${base}_webp.cbz")"

    if [[ -f "$out_abs" ]]; then
        echo "⏭️  Skip: output already exists:"
        echo "   $out_abs"
        echo "   Remove it if you want to reconvert this folder."
        return
    fi

    original_folder_size="$(dir_size_bytes "$src_dir")"

    tmpdir="$parent/.repack_webp_tmp.folder.$base"

    if [[ -e "$tmpdir" ]]; then
        echo "⚠️  Removing old temp directory:"
        echo "   $tmpdir"
        rm -rf "$tmpdir"
    fi

    mkdir -p "$tmpdir"

    echo "📂 Copying folder to temp working directory:"
    echo "   $tmpdir"

    if ! cp -a "$src_dir"/. "$tmpdir"/; then
        echo "❌ Failed to copy folder to temp dir:"
        echo "   $src_dir"
        log_problem "ERROR" "$src_dir" "Failed to copy folder to temp dir: $tmpdir"
        safe_remove_tmpdir "$tmpdir"
        return
    fi

    clean_macos_junk "$tmpdir"

    img_count="$(count_source_images "$tmpdir")"
    webp_count="$(count_webp_images "$tmpdir")"

    echo "📊 Source images in folder copy: $img_count"
    echo "📊 Existing WebP images in folder copy: $webp_count"

    if [[ "$img_count" -eq 0 ]]; then
        echo "⚠️  No JPG/JPEG/PNG images in folder."
        log_problem "WARNING" "$src_dir" "No JPG/JPEG/PNG images found in folder."
        safe_remove_tmpdir "$tmpdir"
        return
    fi

    sample_conversion_check "$tmpdir" "$src_dir"
    sample_result="$?"

    case "$sample_result" in
        0)
            ;;
        2)
            echo "⏭️  Full conversion skipped by sample test."
            echo "   Keeping original folder:"
            echo "   $src_dir"
            safe_remove_tmpdir "$tmpdir"
            return
            ;;
        *)
            echo "❌ Sample test failed."
            echo "   Keeping original folder:"
            echo "   $src_dir"
            safe_remove_tmpdir "$tmpdir"
            return
            ;;
    esac

    echo "📂 Processing folder copy: $tmpdir"

    if ! convert_images_in_dir "$tmpdir"; then
        echo "❌ Some images failed to convert."
        echo "   Keeping original folder:"
        echo "   $src_dir"
        echo "   Keeping temp dir for inspection:"
        echo "   $tmpdir"

        log_problem "ERROR" "$src_dir" "Some images failed to convert. Original folder was kept. Temp dir kept for inspection: $tmpdir"
        return
    fi

    clean_macos_junk "$tmpdir"

    echo "📦 Packing folder copy → $out_abs"

    if make_cbz_from_dir_contents "$tmpdir" "$out_abs" && [[ -f "$out_abs" ]]; then
        output_archive_size="$(file_size_bytes "$out_abs")"

        echo "📊 Original folder size: $original_folder_size bytes"
        echo "📊 Output archive size: $output_archive_size bytes"

        if (( output_archive_size >= original_folder_size )); then
            echo "⏭️  Output archive is not smaller than original folder size."
            echo "   Keeping original folder, removing output archive:"
            echo "   $out_abs"

            rm -f "$out_abs"
            safe_remove_tmpdir "$tmpdir"

            log_problem "WARNING" "$src_dir" "Output archive was not smaller than original folder size. Folder kept. Output removed. Original folder size: $original_folder_size bytes ; output size: $output_archive_size bytes"
            return
        fi

        echo "✅ Converted folder:"
        echo "   $src_dir"
        echo "   → $out_abs"

        safe_remove_tmpdir "$tmpdir"

        echo "🧹 Removing original folder:"
        echo "   $src_dir"
        rm -rf "$src_dir"
    else
        echo "❌ Failed to create output archive:"
        echo "   $out_abs"
        echo "   Keeping original folder and temp dir."

        log_problem "ERROR" "$src_dir" "Failed to create output archive: $out_abs. Original folder and temp dir kept."
    fi
}

# ---------- main ----------

echo "🚀 Starting repack in: $(pwd)"
echo "🔎 Search depth: recursive under current directory"
echo "🎯 Matching names: digital OR hybrid"
echo "📚 Archive types: cbz, cbr"
echo "🖼️  Image types: jpg, jpeg, png → webp"
echo "🌈 Color pages: q${COLOR_QUALITY}, preset photo"
echo "🖤 Black/white pages: q${BW_QUALITY}, no preset"
echo "📏 BW saturation threshold: $BW_SATURATION_THRESHOLD"
echo "🧪 Pre-sample check: $SAMPLE_IMAGES random images before full conversion"
echo "🧹 macOS junk removed: __MACOSX, ._*, .DS_Store"
echo "🛡️  Per-image size compare: disabled"
echo "🛡️  Per-sample size compare: enabled"
echo "🛡️  Per-archive/folder compare: enabled"
echo "📝 Problems-only log:"
echo "   $ERROR_LOG"
echo "   Log file will be created only if problems/warnings occur."
echo "------------------------------------------------------------"

echo "📦 Searching archives recursively..."
while IFS= read -r -d '' file; do
    process_archive "${file#./}"
done < <(
    find . -type f \( \
        -iname "*.cbz" -o \
        -iname "*.cbr" \
    \) \
    ! -iname "*_webp.cbz" \
    ! -path "*/.repack_webp_tmp.*/*" \
    ! -path "*/__MACOSX/*" \
    -print0
)

echo "📂 Searching folders recursively..."
while IFS= read -r -d '' dir; do
    process_folder "${dir#./}"
done < <(
    find . -mindepth 1 -type d \
        ! -name ".repack_webp_tmp.*" \
        ! -name "__MACOSX" \
        ! -path "*/.repack_webp_tmp.*/*" \
        ! -path "*/__MACOSX/*" \
        -print0 \
        | sort -zr
)
