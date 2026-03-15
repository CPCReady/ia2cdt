# ia2CDT

![Build Status](https://github.com/CPCReady/ia2cdt/actions/workflows/build.yml/badge.svg)
![License](https://img.shields.io/github/license/CPCReady/ia2cdt)
![Latest Release](https://img.shields.io/github/v/release/CPCReady/ia2cdt)

A cross-platform command-line utility to create `.CDT` and `.TZX` tape images for the Amstrad CPC from binary files.

## Overview

**ia2CDT** transforms files into cassette tape images (`.CDT`/`.TZX`) compatible with Amstrad CPC emulators and real hardware via cassette interfaces. It supports the standard Amstrad CPC operating system cassette format with configurable baud rates, block methods, and tape filenames.

This tool is a modern, cross-platform fork of the original **2CDT** by Kevin Thacker, now maintained by [CPCReady](https://cpcready.io).

## Features

- **Cross-platform**: Builds for Windows (x86/x64), Linux (x86/x64/ARM64), and macOS (x86_64/Apple Silicon)
- **Multiple encoding methods**: Standard blocks, headerless, Spectrum ROM loader
- **Configurable baud rates**: 1000 or 2000 baud (or custom)
- **TZX block types**: Turbo Loading, Pure Data, or Standard Speed
- **Tape filename support**: Rename files on the tape (up to 16 characters)
- **Flexible addressing**: Define or override load/execution addresses and file types
- **Append support**: Add files to existing CDT/TZX images

## Installation

### Pre-built Binaries

Download the latest release for your platform from the [Releases](https://github.com/CPCReady/ia2cdt/releases) page:

| Platform | Architecture | File |
|----------|-------------|------|
| Windows | x86_64 | `ia2cdt.exe` |
| Windows | x86 | `ia2cdt.exe` |
| Linux | x86_64 | `ia2cdt` |
| Linux | x86 | `ia2cdt` |
| Linux | ARM64 | `ia2cdt` |
| macOS | x86_64 | `ia2cdt` |
| macOS | ARM64 (Apple Silicon) | `ia2cdt` |

### Build from Source

#### Prerequisites

- **Docker** (for cross-compilation to all platforms)
- Or **GCC** + **Make** (for Linux/macOS native builds)

#### Build All Platforms

```bash
./build.sh
```

This creates binaries in the `dist/` directory:

```
dist/
├── linux/x86_64/ia2cdt
├── linux/x86/ia2cdt
├── linux/arm64/ia2cdt
├── windows/x86_64/ia2cdt.exe
├── windows/x86/ia2cdt.exe
├── macos/x86_64/ia2cdt
└── macos/arm64/ia2cdt
```

#### Native Build (Linux/macOS)

```bash
make
```

The binary will be created as `bin/ia2cdt`.

#### Build Targets

```bash
make clean    # Remove object files
make cleanall # Remove object files and binary
```

## Usage

### Basic Syntax

```bash
ia2CDT [options] <input_file> <output_cdt>
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-n` | Blank CDT file before use (create new) | Append to existing |
| `-b <rate>` | Baud rate (1000-6000) | 2000 |
| `-s <0\|1>` | Speed Write: 0=1000 baud, 1=2000 baud | 1 |
| `-t <0\|1\|2>` | TZX Block Method: 0=Pure Data, 1=Turbo Loading, 2=Standard Speed | 1 |
| `-m <0\|1\|2>` | Data Method: 0=blocks, 1=headerless, 2=Spectrum | 0 |
| `-r <name>` | Tape filename (max 16 chars) | unchanged |
| `-X <addr>` | Execution address (hex: `&`, `$`, or `0x` prefix) | &1000 |
| `-L <addr>` | Load address (hex) | &1000 |
| `-F <type>` | File type: 0=BASIC, 2=BINARY | 2 |
| `-p <ms>` | Initial pause in milliseconds | 3000 |
| `-P` | Add 1ms pause for buggy emulators | No |

### Examples

#### Create a new CDT with a binary file

```bash
ia2CDT -n -r game game.bin game.cdt
```

#### Add multiple files to existing CDT

```bash
ia2CDT -r screen screen.bin game.cdt
ia2CDT -r code code.bin game.cdt
```

#### Create CDT with headerless data (single continuous block)

```bash
ia2CDT -n -m 1 -r level1 level1.bin level1.cdt
```

#### Custom load address and execution address

```bash
ia2CDT -n -L &4000 -X &8000 -r demo demo.bin demo.cdt
```

#### Higher baud rate for faster loading

```bash
ia2CDT -n -b 3000 -r game game.bin game.cdt
```

## Technical Details

### File Format

The `.CDT` format is identical to the `.TZX` format developed for Sinclair ZX Spectrum. The extension difference (`CDT` vs `TZX`) is a convention to distinguish Amstrad CPC tape images from Spectrum ones.

### CPC Tape Block Structure

When using the default block method (`-m 0`), files are split into 2048-byte blocks, each with:
- 64-byte header (filename, block number, file type, addresses, length)
- 2048-byte data block
- Checksum bytes

### Supported Methods

| Method | Description | Use Case |
|--------|-------------|----------|
| `-m 0` (blocks) | Standard CPC blocks with headers | Standard BASIC/binary files |
| `-m 1` (headerless) | Single continuous block via `CAS READ` | Large files, custom loaders |
| `-m 2` (spectrum) | Spectrum ROM loader format | Compatibility with Spectrum tools |

## License

This program is free software: you can redistribute it and/or modify it under the terms of the **GNU General Public License v2** as published by the Free Software Foundation.

See the [COPYING](COPYING) file for full license text.

## Acknowledgments

- **Kevin Thacker** - Original author of 2CDT (2000-2001)
- **CPCReady** - Modern maintenance and cross-platform build system
- **World of Spectrum** - TZX format specification

## Links

- [TZX File Format Specification](https://worldofspectrum.org/faq/reference/tzxformat.htm)
- [Amstrad CPC Wiki](https://www.cpcwiki.eu/)
- [CPCReady](https://cpcready.io) - Amstrad CPC community
