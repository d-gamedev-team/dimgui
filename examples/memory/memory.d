module memory;

/**
    This example demonstrates how to properly handle memory management
    for displaying things such as text.
*/

import std.exception;
import std.file;
import std.path;
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

        const scrollAreaWidth = (windowWidth / 4) - 10;  // -10 to allow room for the scrollbar
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

        /// Improper memory management.
        displayArea1(scrollAreaWidth, scrollAreaHeight);

        /// Attempted workaround, but still improper memory management.
        char[128] buffer;
        displayArea2(scrollAreaWidth, scrollAreaHeight, buffer);

        /// Proper memory management.
        char[128][100] buffers;
        displayArea3(scrollAreaWidth, scrollAreaHeight, buffers);

        /// Alternatively you may use 'string', which is guaranteed to be immutable
        /// and will outlive any stack scope since the garbage collector will keep
        /// a reference to it.
        displayArea4(scrollAreaWidth, scrollAreaHeight);

        imguiEndFrame();

        imguiRender(windowWidth, windowHeight);
    }

    void displayArea1(int scrollAreaWidth, int scrollAreaHeight)
    {
        imguiBeginScrollArea("Improper memory management 1", 10, 10, scrollAreaWidth, scrollAreaHeight, &scrollArea1);

        imguiSeparatorLine();
        imguiSeparator();

        /// Note: improper memory management: 'buffer' is scoped to this function,
        /// but imguiLabel will keep a reference to the 'buffer' until 'imguiRender'
        /// is called. 'imguiRender' is only called after 'displayArea1' returns,
        /// after which 'buffer' will not be usable (it's memory allocated on the stack!).
        /// Result: Random text being displayed or even crashes are possible.
        char[128] buffer;
        auto text = buffer.sformat("This is my text: %s", "more text");
        imguiLabel(text);

        imguiEndScrollArea();
    }

    void displayArea2(int scrollAreaWidth, int scrollAreaHeight, ref char[128] buffer)
    {
        imguiBeginScrollArea("Improper memory management 2", 20 + (1 * scrollAreaWidth), 10, scrollAreaWidth, scrollAreaHeight, &scrollArea2);

        imguiSeparatorLine();
        imguiSeparator();

        foreach (idx; 0 .. 100)
        {
            /// Note: improper memory management: 'buffer' will be re-used in each
            /// iteration of this loop, but imguiLabel will just keep a reference
            /// to the same memory location on each call.
            /// Result: Typically the same bit of text is displayed 100 times.
            auto text = buffer.sformat("Item number %s", idx);
            imguiLabel(text);
        }

        imguiEndScrollArea();
    }

    void displayArea3(int scrollAreaWidth, int scrollAreaHeight, ref char[128][100] buffers)
    {
        imguiBeginScrollArea("Proper memory management 1", 30 + (2 * scrollAreaWidth), 10, scrollAreaWidth, scrollAreaHeight, &scrollArea3);

        imguiSeparatorLine();
        imguiSeparator();

        foreach (idx, ref buffer; buffers)
        {
            /// Note: Proper memory management: 'buffer' is unique for all the items,
            /// and imguiLabel can safely store a reference to each string since each
            /// buffer will be valid until the exit of the scope where the 'imguiRender'
            /// call is emitted.
            auto text = buffer.sformat("Item number %s", idx);
            imguiLabel(text);
        }

        imguiEndScrollArea();
    }

    void displayArea4(int scrollAreaWidth, int scrollAreaHeight)
    {
        imguiBeginScrollArea("Proper memory management 2", 40 + (3 * scrollAreaWidth), 10, scrollAreaWidth, scrollAreaHeight, &scrollArea4);

        imguiSeparatorLine();
        imguiSeparator();

        foreach (idx; 0 .. 100)
        {
            /// Note: Proper memory management: the string will not be prematurely
            /// garbage-collected since the GC will know that 'imguiLabel' will store
            /// a refererence to this string for use in a later 'imguiRender call.
            string str = "This is just some text";
            imguiLabel(str);
        }

        imguiEndScrollArea();
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

    int scrollArea1 = 0;
    int scrollArea2 = 0;
    int scrollArea3 = 0;
    int scrollArea4 = 0;
    int mouseScroll = 0;
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
