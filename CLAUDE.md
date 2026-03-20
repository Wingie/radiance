# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Radiance is GPU-accelerated video art software for live VJ performance, written in Rust. It chains together WGSL fragment shader effects with music-reactive visuals and multi-screen output for projection mapping.

## Build & Development Commands

```bash
# Build and run (dev profile has optimizations enabled)
cargo run

# Build only
cargo build

# Run tests
cargo test

# Run a single test
cargo test <test_name>

# Run benchmarks (beat tracking)
cargo bench

# Build without mpv/video support
cargo run --no-default-features
```

### libmpv Dependency (for `mpv` feature)

The default build requires libmpv. Install it:
- **macOS**: `brew install mpv` or build from https://github.com/karelrooted/libmpv
- **Linux**: Install `libmpv-dev` (apt) or `mpv-devel` (dnf)
- Without libmpv, use `--no-default-features` to build without video support.

### Beat Toolkit (Python, in `beat_toolkit/`)

```bash
cd beat_toolkit
make setup    # Install via Poetry
make check    # Lint (isort, black, flake8, mypy)
make run      # Run pytest (compiles Rust beat tracking binary first)
```

## Architecture

### Library (`src/lib/`) — Core engine

- **`graph.rs`** — Acyclic graph of nodes connected by edges. `NodeId` (128-bit) uniquely identifies nodes. This is the central data structure.
- **`context.rs`** — WGPU rendering context, texture management, render pipeline state.
- **`effect_node/`** — Shader effect system. `preprocess_shader.rs` handles `#buffershader` directive for multi-pass effects. Effects are wrapped with `effect_header.wgsl` / `effect_footer.wgsl` templates.
- **`movie_node.rs`** — Video playback via libmpv with OpenGL interop (surfman). Feature-gated behind `mpv`.
- **`image_node.rs`** — Static image input node.
- **`auto_dj.rs`** — Automatic scene sequencing, transitions, and tempo sync.
- **`beat_tracking/`** — Audio-reactive beat detection using FFT and neural network models (`ml_models.rs`).
- **`mir.rs`** — Intermediate representation for node serialization/deserialization.
- **`props.rs`** — Properties/state serialization for nodes.

### Binary (`src/bin/`) — UI and window management

- **`main.rs`** — Entry point: winit event loop, WGPU init, autosave (`autosave.json`), audio input device selection.
- **`ui/`** — EGUI-based interface:
  - `mosaic.rs` — Node tile grid layout and drag-drop.
  - `library.rs` — Effect browser.
  - Visualizer widgets: `spectrum_widget.rs`, `beat_widget.rs`, `waveform_widget.rs`.
- **`winit_output/`** — Display output and projection mapping shaders.
- **`setup/`** — Default library loading on startup.

### Shader Library (`library/`)

171 WGSL fragment shaders embedded into the binary at compile time. The build script (`build.rs`) validates all shaders using Naga during compilation.

## Key Design Details

- **Custom EGUI forks**: Dependencies use `radiance-egui`, `radiance-egui-winit`, `radiance-egui-wgpu` (custom crates.io forks for patching).
- **Custom libmpv fork**: Uses `radiance-libmpv` / `radiance-libmpv-sys`.
- **Build script (`build.rs`)**: Validates all WGSL shaders at compile time and embeds the `library/` directory into the binary.
- **Feature flags**: `mpv` (default) — enables video playback via libmpv.
- **Cross-platform**: Builds for Linux (x86_64, aarch64), macOS (universal binary), Windows. See `.github/scripts/build.sh`.
