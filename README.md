# elite — extended lite
![screenshot](doc/screenshot.png)

A lightweight text editor written in Lua — fork of [lite](https://github.com/rxi/lite)

* **[Get elite](https://github.com/matpx/elite/releases/latest)** — Download
  for Windows and Linux
* **[Get started](doc/usage.md)** — A quick overview on how to get started

## Overview
elite is a lightweight text editor written mostly in Lua — it aims to provide
something practical, pretty, *small* and fast, implemented as simply as
possible; easy to modify and extend, or to use without doing either.

## Customization
Plugins and color themes are included in the repository. Additional plugins can
be found in the `data/plugins` directory and color themes in the
`data/colors` directory. The editor can be customized by making changes to the
[user module](data/user/init.lua).

## Building
You can build the project yourself using `make`. Cross-compilation for Windows
is supported with `make OS=windows`. Use `make release` to build both platforms,
run linting, and package a zip.
Note that the project does not need to be rebuilt if you are only making changes
to the Lua portion of the code.

## Contributing
Any additional functionality that can be added through a plugin should be done
so as a plugin, after which a pull request can be made to the
[elite repository](https://github.com/matpx/elite). In hopes
of remaining lightweight, pull requests adding additional functionality to the
core will likely not be merged. Bug reports and bug fixes are welcome.

## License
This project is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.
