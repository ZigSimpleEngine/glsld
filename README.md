# glsld (fork)

> [!NOTE]
> This is a fork with WebGL-oriented diagnostics. Added on top of upstream:
>
> - WebGL shader diagnostics: files with `#version 100` or `#version 300 es` are validated with `glslangValidator` (plain GLSL validation, no SPIR-V), because `glslc` rejects ES versions below 310 for any target environment.
> - Automatic target selection: when no per-file `targetEnv` override is configured, the diagnostic backend is picked from the `#version` directive — `100` / `300 es` and below go to the WebGL path, `310 es` and desktop versions keep the existing `glslc` path. An explicit `targetEnv` always wins.
> - Self-contained `#include` expansion for the WebGL path (resolved against the file directory and configured system include directories, with `#line` mapping back to original files, plus cycle/depth diagnostics). Errors inside included files are skipped, same as the `glslc` path.
> - Version hint for includable headers: a `// #version 300 es` comment is honored when the file has no real `#version` directive (real directives always win). The WebGL backend also injects the hinted version for validation, so headers stay includable without breaking the single-`#version` rule. The hint is highlighted like a real directive, except the `//` itself which keeps the comment color.
> - Member hints for builtin types: the full swizzle product for vectors — every 1- to 4-character combination within each set (`xyzw`, `rgba`, `stpq`), truncated to the vector length (up to 1020 items for `vec4`), for all `vec`/`ivec`/`uvec`/`bvec` types — in dot-completion, `.length()` for arrays, plus hover with the resulting type (`vec3.zx -> vec2`, `int length()`). Matrices, scalars and samplers intentionally have no dot-hints (no such syntax in the language). Manual `Ctrl+Space` right after a dot routes to member completion too, not only the auto-popup on typing `.`.
> - `opengl` / `opengl4.5` choices for per-file `targetEnv`, and a `glsld.glslangValidator.path` setting (defaults to `%VULKAN_SDK%\Bin\glslangValidator.exe`, then `PATH`).
> - `build-fork.bat`: one-command build of the server, VSIX packaging as `glsld-fork`, and installation into VS Code.

> [!NOTE]
> This extension is an independent project and is not affiliated with another Visual Studio Code extension that also uses the name `glsld` (https://github.com/daiyousei-qz/glsld). I was the one who discovered the name collision only while preparing this extension for publication on the Visual Studio Code Marketplace.

glsld is a language server for GLSL, accompanied by a Visual Studio Code extension. It provides parsing, preprocessing, semantic analysis, cross-file navigation, diagnostics, and workspace-wide background indexing for shader projects.

## Features

- Context-aware code, include-path, and extension completion
- Function overload resolution and signature help
- Syntax and semantic diagnostics through `glslc`
- Hover information and inlay hints
- Go to definition and workspace-wide reference search
- Cross-file symbol discovery through include-aware background indexing
- Shared and per-file preprocessor variants
- Shader compile groups in the Visual Studio Code extension

Screenshots and extension-specific setup instructions are available in the [Visual Studio Code extension documentation](VSCodeExtension/README.md).

## Repository layout

| Path | Description |
| --- | --- |
| `glsld/Sources` | Native glsld language-server source code |
| `glsld/Database` | Built-in GLSL lexical and semantic database |
| `VSCodeExtension` | Visual Studio Code client extension |

## Building the server

Clone the repository together with its submodules:

```powershell
git clone --recursive https://github.com/LBV2012-26/glsld.git
```

### Windows Build

- Requirements: Visual Studio 2026 with C++ workload and vcpkg.

> [!NOTE]
> If you first install vcpkg, you must run `vcpkg integrate install` to make it available to Visual Studio.

Open `glsld.slnx` in Visual Studio, select the desired x64 configuration, and press F7 to build the `glsld` project. The project uses the vcpkg manifest at `glsld/vcpkg.json` for package dependencies.

The `glsld.exe` executable will be located in `glsld/Win64/glsld.exe`.

### Linux Build

- Requirements: CMake, Clang, lld and vcpkg.

> [!NOTE]
> This repo will cause GCC to fail to build due to a internal compiler error. So use Clang instead.
> Make sure VCPKG_ROOT is set to the PATH.

```bash
cd glsld
clang++ ./CMakeGenerator/Sources/main.cpp -o CMakeGen --std=c++26 && ./CMakeGen
```

The `glsld` executable will be located in `glsld/Linux/glsld`.

## Visual Studio Code extension

The extension source is located in `VSCodeExtension`. To install its dependencies and compile it:

```powershell
cd VSCodeExtension
npm ci
npm run compile
```

See the [extension README](VSCodeExtension/README.md) for configuration, features, and VSIX packaging instructions.

## Contributing

If you are considering contributing, thank you for your interest in glsld. However, this project is maintained in limited personal time, and I currently cannot allocate enough time to review external code contributions properly. For that reason, pull requests are temporarily disabled.

If you discover a bug or have an idea for an improvement, please [open an issue](https://github.com/LBV2012-26/glsld/issues) so it can be discussed first.

If you need custom behavior or project-specific functionality, you are very welcome to [fork this repository](https://github.com/LBV2012-26/glsld/fork) and adapt it to your own requirements.

## Licensing

This repository contains separately licensed components:

- The glsld language server is licensed under the GNU General Public License version 3 only (`GPL-3.0-only`).
- The Visual Studio Code extension in `VSCodeExtension` is licensed under the MIT License.

See [LICENSE.md](LICENSE.md) for the precise component boundaries and links to the complete license texts.
