default:
    @just --list --unsorted

config := absolute_path('config')
build := absolute_path('.build')
out := absolute_path('firmware')
draw := absolute_path('draw')

# parse build.yaml and filter targets by expression
_parse_targets $expr:
    #!/usr/bin/env bash
    filter='(.include[] | [.board, .shield, .snippet, .keymap]) | join(",")'
    yq -r "$filter" build.yaml | grep -i "${expr/#all/.*}"

# build firmware for single board, shield & keymap combination
_build_single $board $shield $snippet $keymap *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${shield:+${shield// /+}-}${board}${keymap:+-$keymap}"
    build_dir="{{ build / '$artifact' }}"

    echo "Building firmware for $artifact..."
    west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} ${snippet:+-S "$snippet"} -- \
        -DZMK_CONFIG="{{ config }}" ${shield:+-DSHIELD="$shield"} \
        ${keymap:+-DKEYMAP_FILE="{{ config }}/corne_$keymap.keymap"}

    mkdir -p "{{ out }}"
    if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
        cp "$build_dir/zephyr/zmk.uf2" "{{ out }}/$artifact.uf2"
    else
        cp "$build_dir/zephyr/zmk.bin" "{{ out }}/$artifact.bin"
    fi

# build firmware for matching targets (e.g. all, homerow, plain, left)
build expr *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$(just _parse_targets {{ expr }})

    [[ -z $targets ]] && echo "No matching targets found. Aborting..." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield snippet keymap; do
        just _build_single "$board" "$shield" "$snippet" "$keymap" {{ west_args }}
    done

# parse & plot every keymap
draw:
    #!/usr/bin/env bash
    set -euo pipefail
    for km in "{{ config }}"/corne_*.keymap; do
        name=$(basename "$km" .keymap)
        keymap -c "{{ draw }}/config.yaml" parse -z "$km" >"{{ draw }}/$name.yaml"
        keymap -c "{{ draw }}/config.yaml" draw -z corne "{{ draw }}/$name.yaml" >"{{ draw }}/$name.svg"
    done

# initialize west
init:
    west init -l config
    just update
    west zephyr-export

# update west
update:
    west update --fetch-opt=--filter=blob:none

# list build targets
list:
    @just _parse_targets all | sed 's/,*$//' | sort | column

# clear build cache and artifacts
clean:
    rm -rf {{ build }} {{ out }}

# clear all automatically generated files
clean-all: clean
    rm -rf .west zmk
