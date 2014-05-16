# dimgui

![dimgui](https://raw.github.com/d-gamedev-team/dimgui/master/screenshot/imgui.png)

This is a D port of the [imgui] OpenGL GUI library.

Homepage: https://github.com/d-gamedev-team/dimgui

## Examples

Use [dub] to build and run the example project:

```
$ dub run dimgui:example
```

Note: You will need to install the [glfw] shared library in order to run the example.

## Documentation

The public API is available in the [imgui.api] module.

## Building dimgui as a static library

Run [dub] alone in the root project directory to build **dimgui** as a static library:

```
$ dub
```

## Links

- The original [imgui] github repository.

## License

Distributed under the [zlib] license.

See the accompanying file [license.txt][zlib].

[dub]: http://code.dlang.org/
[imgui]: https://github.com/AdrienHerubel/imgui
[imgui.api]: https://github.com/d-gamedev-team/dimgui/blob/master/src/imgui/api.d
[zlib]: https://raw.github.com/d-gamedev-team/dimgui/master/license.txt
[glfw]: http://www.glfw.org/
