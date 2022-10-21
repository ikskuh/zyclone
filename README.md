# Zyclone Game Engine

![Logo](design/zyclone.svg)

A game engine modeled after [3D Gamestudio](http://www.3dgamestudio.com/), written in [Zig](https://ziglang.org/).

The engine is designed in the spirit of Gamestudio both in API, and in usage, but also tries to be more modern when appropiate.

## Supported Platforms

- [x] Windows
- [x]Linux
- [ ] macOs (planned)
- [ ] Android (planned)
- [ ] WebAssembly (planned)

## Getting Started

1. Download the latest Zig toolchain for your operating system.
2. Clone this repository recursively (including all submodules)
3. Install dependencies for your OS
	- `libsdl2-dev` and `libgtk-3-dev` for Debian/Ubuntu systems
	- [SDL2 mingw development libraries](https://github.com/libsdl-org/SDL/releases) for Windows
4. `zig build` the example project
5. Change into the `demo` folder and run `../zig-out/bin/3rd_person`


