#!/usr/bin/env bash

set -o errexit

RUSTFLAGS=${RUSTFLAGS:---deny warnings}

declare -A devices
devices[51]=thumbv6m-none-eabi
devices[52810]=thumbv7em-none-eabi
devices[52832]=thumbv7em-none-eabi
devices[52840]=thumbv7em-none-eabi

# Run unit tests. We'd prefer to run `cargo test --all`, but some packages
# require enabling Cargo features, which Cargo does not support in that case.
echo "Running tests with Cargo..."
cargo test -p rubble

# Check that the device crates build with all feature combinations.
# Only use `cargo check` because the PAC crates are very slow to build.
(
    cd rubble-nrf5x

    for DEVICE in "${!devices[@]}"
    do
        TARGET="${devices[$DEVICE]}"

        echo "Checking rubble-nrf5x for nRF$DEVICE ($TARGET)..."
        cargo check --features="$DEVICE" --target="$TARGET"
    done
)

# Check that the demo apps build with all supported feature combinations.
# Here we do a proper build to also make sure linking the final binary works.
for demo in demos/nrf5x*; do
    for DEVICE in "${!devices[@]}"; do
        TARGET="${devices[$DEVICE]}"

        (
            echo "Building $demo for device nRF$DEVICE, target $TARGET..."
            cd "$demo"
            cargo build --target "$TARGET" --features "$DEVICE"
            cargo build --target "$TARGET" --features "$DEVICE" --no-default-features
        )
    done
done

# Demos which only work on the nRF52... for now :)
for demo in demos/nrf52*; do
    for DEVICE in "${!devices[@]}"; do
        TARGET="${devices[$DEVICE]}"

        if [[ ! $DEVICE == "52"* ]]
        then
            echo "SKIPPING $demo for device nRF$DEVICE"
            continue
        done

        (
            echo "Building $demo for device nRF$DEVICE, target $TARGET..."
            cd "$demo"
            cargo build --target "$TARGET" --features "$DEVICE"
            cargo build --target "$TARGET" --features "$DEVICE" --no-default-features
        )
    done
done


# Lastly, check formatting. We'd like to do this earlier, but some crates copy
# module files around in their build scripts, so they can only be formatted once
# they've been built at least once.
echo "Checking code formatting..."
cargo fmt --all -- --check

# Build documentation.
(
    echo "Generating documentation..."
    cd rubble-docs
    cargo doc --no-deps -p rubble -p rubble-nrf5x
)
