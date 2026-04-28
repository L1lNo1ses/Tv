#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
JSON_FILE="$SCRIPT_DIR/channels/arktv_custom_channels.json"
CURR_TTY="$(tty)"

MPV_SOCKET="/tmp/mpvsocket"

initialize() {
    clear > "$CURR_TTY"
    printf "\e[?25l" > "$CURR_TTY"
}

cleanup() {
    printf "\e[?25h" > "$CURR_TTY"
    clear > "$CURR_TTY"
}

trap cleanup EXIT

check_deps() {
    for cmd in jq dialog mpv; do
        command -v "$cmd" >/dev/null || {
            echo "Missing: $cmd"
            exit 1
        }
    done
}

show_categories() {
    jq -r '.[].category' "$JSON_FILE" | uniq
}

select_category() {
    local categories
    categories=($(show_categories))

    local menu=()
    local i=1

    for c in "${categories[@]}"; do
        menu+=("$i" "$c")
        ((i++))
    done

    menu+=("0" "Exit")

    choice=$(dialog --stdout \
        --title "Categories" \
        --menu "Select category:" 15 50 10 \
        "${menu[@]}")

    [[ "$choice" == "0" || -z "$choice" ]] && exit 0

    echo "${categories[$((choice-1))]}"
}

select_channel() {
    local category="$1"

    mapfile -t names < <(jq -r --arg cat "$category" '
        .[]
        | select(.category == $cat)
        | .channels[]
        | .name
    ' "$JSON_FILE")

    mapfile -t urls < <(jq -r --arg cat "$category" '
        .[]
        | select(.category == $cat)
        | .channels[]
        | .url
    ' "$JSON_FILE")

    local menu=()
    for i in "${!names[@]}"; do
        menu+=("$i" "${names[$i]}")
    done

    menu+=("x" "Back")

    choice=$(dialog --stdout \
        --title "Channels - $category" \
        --menu "Select channel:" 20 60 12 \
        "${menu[@]}")

    [[ "$choice" == "x" || -z "$choice" ]] && return

    play_channel "${urls[$choice]}"
}

play_channel() {
    local url="$1"

    clear > "$CURR_TTY"
    echo "Loading stream..." > "$CURR_TTY"

    mpv \
        --fullscreen \
        --hwdec=auto \
        --cache=yes \
        --cache-secs=20 \
        "$url"
}

main_loop() {
    check_deps
    initialize

    while true; do
        cat=$(select_category)
        select_channel "$cat"
    done
}

main_loop
