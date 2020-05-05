/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module colors;

import std.exception;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.string;

import deimos.glfw.glfw3;

import glad.gl.enums;
import glad.gl.ext;
import glad.gl.funcs;
import glad.gl.loader;
import glad.gl.types;

import glwtf.input;
import glwtf.window;

import imgui;

import window;

version (OSX)
    version = MaybeHighResolutionDisplay;
version (iOS)
    version = MaybeHighResolutionDisplay;

struct RGBAF
{
    float r = 0.0, g = 0.0, b = 0.0, a = 0.0;

    RGBAF opBinary(string op)(RGBAF rgba)
    {
        RGBAF res = this;

        mixin("res.r = res.r " ~ op ~ " rgba.r;");
        mixin("res.g = res.g " ~ op ~ " rgba.g;");
        mixin("res.b = res.b " ~ op ~ " rgba.b;");
        mixin("res.a = res.a " ~ op ~ " rgba.a;");

        return res;
    }
}

auto clamp(T1, T2, T3)(T1 value, T2 min, T3 max)
{
    return (((value) >(max)) ? (max) : (((value) <(min)) ? (min) : (value)));
}

RGBA toRGBA(RGBAF c)
{
    return RGBA(cast(ubyte)(255.0f * clamp(c.r, 0.0, 1.0)),
                cast(ubyte)(255.0f * clamp(c.g, 0.0, 1.0)),
                cast(ubyte)(255.0f * clamp(c.b, 0.0, 1.0)),
                cast(ubyte)(255.0f * clamp(c.a, 0.0, 1.0)));
}

RGBAF toRGBAF(RGBA c)
{
    return RGBAF(clamp((cast(float)c.r) / 255.0, 0.0, 1.0),
                 clamp((cast(float)c.g) / 255.0, 0.0, 1.0),
                 clamp((cast(float)c.b) / 255.0, 0.0, 1.0),
                 clamp((cast(float)c.a) / 255.0, 0.0, 1.0));
}

struct GUI
{
    this(Window window)
    {
        this.window = window;

        window.on_scroll.strongConnect(&onScroll);

        int width;
        int height;
        glfwGetFramebufferSize(window.window, &width, &height);

        // trigger initial viewport transform.
        onWindowResize(width, height);

        window.on_resize.strongConnect(&onWindowResize);

        oldColorScheme = defaultColorScheme;
        updateColorScheme();
    }

    ColorScheme oldColorScheme;

    void updateColorScheme()
    {
        auto rgbaBright = RGBAF(brightness, brightness, brightness, 0);

        foreach (ref outColor, oldColor; zip(defaultColorScheme.walkColors, oldColorScheme.walkColors))
        {
            auto oldRGBAF = toRGBAF(*oldColor);
            auto res = oldRGBAF + color + rgbaBright;
            *outColor = res.toRGBA();
        }
    }

    void render()
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // Mouse states
        ubyte mousebutton = 0;
        double mouseX;
        double mouseY;
        glfwGetCursorPos(window.window, &mouseX, &mouseY);

        version (MaybeHighResolutionDisplay)
        {
            // Scale the cursor position for high-resolution displays.
            if (mouseXToWindowFactor == 0) // need to initialize
            {
                int virtualWindowWidth, virtualWindowHeight;
                glfwGetWindowSize(window.window, &virtualWindowWidth, &virtualWindowHeight);
                if (virtualWindowWidth != 0 && virtualWindowHeight != 0)
                {
                    int frameBufferWidth, frameBufferHeight;
                    glfwGetFramebufferSize(window.window, &frameBufferWidth, &frameBufferHeight);
                    mouseXToWindowFactor = double(frameBufferWidth) / virtualWindowWidth;
                    mouseYToWindowFactor = double(frameBufferHeight) / virtualWindowHeight;
                }
            }
            mouseX *= mouseXToWindowFactor;
            mouseY *= mouseYToWindowFactor;
        }

        const scrollAreaWidth = windowWidth / 4;
        const scrollAreaHeight = windowHeight - 20;

        int mousex = cast(int)mouseX;
        int mousey = cast(int)mouseY;

        mousey = windowHeight - mousey;
        int leftButton   = glfwGetMouseButton(window.window, GLFW_MOUSE_BUTTON_LEFT);
        int rightButton  = glfwGetMouseButton(window.window, GLFW_MOUSE_BUTTON_RIGHT);
        int middleButton = glfwGetMouseButton(window.window, GLFW_MOUSE_BUTTON_MIDDLE);

        if (leftButton == GLFW_PRESS)
            mousebutton |= MouseButton.left;

        imguiBeginFrame(mousex, mousey, mousebutton, mouseScroll);

        if (mouseScroll != 0)
            mouseScroll = 0;

        imguiBeginScrollArea("Scroll area 1", 10, 10, scrollAreaWidth, scrollAreaHeight, &scrollArea1);

        imguiSeparatorLine();
        imguiSeparator();

        if (imguiSlider("Transparency Alpha", &color.a, 0.0, 1.0, 0.01f))
            updateColorScheme();

        if (imguiSlider("Brightness", &brightness, -1.0, 1.0, 0.01f))
            updateColorScheme();

        if (imguiSlider("Red Channel", &color.r, 0.0, 1.0, 0.01f))
            updateColorScheme();

        if (imguiSlider("Green Channel", &color.g, 0.0, 1.0, 0.01f))
            updateColorScheme();

        if (imguiSlider("Blue Channel", &color.b, 0.0, 1.0, 0.01f))
            updateColorScheme();

        // should not be clickable
        enforce(!imguiSlider("Disabled slider", &disabledSliderValue, 0.0, 100.0, 1.0f, Enabled.no));

        imguiIndent();
        imguiLabel("Indented");
        imguiUnindent();
        imguiLabel("Unindented");

        imguiEndScrollArea();

        imguiBeginScrollArea("Scroll area 2", 20 + (1 * scrollAreaWidth), 10, scrollAreaWidth, scrollAreaHeight, &scrollArea2);
        imguiSeparatorLine();
        imguiSeparator();

        foreach (i; 0 .. 100)
            imguiLabel("A wall of text");

        imguiEndScrollArea();

        imguiBeginScrollArea("Scroll area 3", 30 + (2 * scrollAreaWidth), 10, scrollAreaWidth, scrollAreaHeight, &scrollArea3);
        imguiLabel(lastInfo);
        imguiEndScrollArea();

        imguiEndFrame();

        const graphicsXPos = 40 + (3 * scrollAreaWidth);

        imguiDrawText(graphicsXPos, scrollAreaHeight, TextAlign.left, "Free text", RGBA(32, 192, 32, 192));
        imguiDrawText(graphicsXPos + 100, windowHeight - 40, TextAlign.right, "Free text", RGBA(32, 32, 192, 192));
        imguiDrawText(graphicsXPos + 50, windowHeight - 60, TextAlign.center, "Free text", RGBA(192, 32, 32, 192));

        imguiDrawLine(graphicsXPos, windowHeight - 80, graphicsXPos + 100, windowHeight - 60, 1.0f, RGBA(32, 192, 32, 192));
        imguiDrawLine(graphicsXPos, windowHeight - 100, graphicsXPos + 100, windowHeight - 80, 2.0, RGBA(32, 32, 192, 192));
        imguiDrawLine(graphicsXPos, windowHeight - 120, graphicsXPos + 100, windowHeight - 100, 3.0, RGBA(192, 32, 32, 192));

        imguiDrawRoundedRect(graphicsXPos, windowHeight - 240, 100, 100, 5.0, RGBA(32, 192, 32, 192));
        imguiDrawRoundedRect(graphicsXPos, windowHeight - 350, 100, 100, 10.0, RGBA(32, 32, 192, 192));
        imguiDrawRoundedRect(graphicsXPos, windowHeight - 470, 100, 100, 20.0, RGBA(192, 32, 32, 192));

        imguiDrawRect(graphicsXPos, windowHeight - 590, 100, 100, RGBA(32, 192, 32, 192));
        imguiDrawRect(graphicsXPos, windowHeight - 710, 100, 100, RGBA(32, 32, 192, 192));
        imguiDrawRect(graphicsXPos, windowHeight - 830, 100, 100, RGBA(192, 32, 32, 192));

        imguiRender(windowWidth, windowHeight);
    }

    /**
        This tells OpenGL what area of the available area we are
        rendering to. In this case, we change it to match the
        full available area. Without this function call resizing
        the window would have no effect on the rendering.
    */
    void onWindowResize(int width, int height)
    {
        // bottom-left position.
        enum int x = 0;
        enum int y = 0;

        /**
            This function defines the current viewport transform.
            It defines as a region of the window, specified by the
            bottom-left position and a width/height.

            Note about the viewport transform:
            It is the process of transforming vertex data from normalized
            device coordinate space to window space. It specifies the
            viewable region of a window.
        */
        glfwGetFramebufferSize(window.window, &width, &height);
        glViewport(x, y, width, height);

        windowWidth = width;
        windowHeight = height;
        version (MaybeHighResolutionDisplay)
        {
            mouseXToWindowFactor = 0;
            mouseYToWindowFactor = 0;
        }
    }

    void onScroll(double hOffset, double vOffset)
    {
        mouseScroll = -cast(int)vOffset;
    }

private:
    Window window;
    int windowWidth;
    int windowHeight;
version (MaybeHighResolutionDisplay)
{
    double mouseXToWindowFactor = 0;
    double mouseYToWindowFactor = 0;
}

    bool checkState1 = false;
    bool checkState2 = false;
    bool checkState3 = true;
    bool collapseState1 = true;
    bool collapseState2 = false;

    RGBAF color;
    float brightness = 0;

    float disabledSliderValue = 30.0;
    int scrollArea1 = 0;
    int scrollArea2 = 0;
    int scrollArea3 = 0;
    int mouseScroll = 0;

    char[] lastInfo;  // last clicked element information
}

int main(string[] args)
{
    int width = 1024, height = 768;

    auto window = createWindow("imgui", WindowMode.windowed, width, height);
    scope (exit) destroy(window);

    GUI gui = GUI(window);

    glfwSwapInterval(1);

    string fontPath = thisExePath().dirName().buildPath("../").buildPath("DroidSans.ttf");

    enforce(imguiInit(fontPath));

    glClearColor(0.8f, 0.8f, 0.8f, 1.0f);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_DEPTH_TEST);

    while (!glfwWindowShouldClose(window.window))
    {
        gui.render();

        /* Swap front and back buffers. */
        window.swap_buffers();

        /* Poll for and process events. */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }

    // Clean UI
    imguiDestroy();

    return 0;
}
