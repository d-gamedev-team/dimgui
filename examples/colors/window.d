/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module window;

/**
    Contains various helpers, common code, and initialization routines.
*/

import std.algorithm : min;
import std.exception : enforce;
import std.functional : toDelegate;
import std.stdio : stderr;
import std.string : format;

import deimos.glfw.glfw3;

import glad.gl.enums;
import glad.gl.ext;
import glad.gl.funcs;
import glad.gl.loader;
import glad.gl.types;

import glwtf.input;
import glwtf.window;

/// init
shared static this()
{
    enforce(glfwInit());
}

/// uninit
shared static ~this()
{
    glfwTerminate();
}

///
enum WindowMode
{
    fullscreen,
    windowed,
}

/**
    Create a window, an OpenGL 3.x context, and set up some other
    common routines for error handling, window resizing, etc.
*/
Window createWindow(string windowName, WindowMode windowMode = WindowMode.windowed, int width = 1024, int height = 768)
{
    auto vidMode = glfwGetVideoMode(glfwGetPrimaryMonitor());

    // constrain the window size so it isn't larger than the desktop size.
    width = min(width, vidMode.width);
    height = min(height, vidMode.height);

    // set the window to be initially inivisible since we're repositioning it.
    glfwWindowHint(GLFW_VISIBLE, 0);

    // enable debugging
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, 1);

    Window window = createWindowContext(windowName, WindowMode.windowed, width, height);

    // center the window on the screen
    glfwSetWindowPos(window.window, (vidMode.width - width) / 2, (vidMode.height - height) / 2);

    // glfw-specific error routine (not a generic GL error handler)
    register_glfw_error_callback(&glfwErrorCallback);

    // anti-aliasing number of samples.
    window.samples = 4;

    // activate an opengl context.
    window.make_context_current();

    // load all OpenGL function pointers via glad.
    enforce(gladLoadGL());

    enforce(glGenBuffers !is null);

    // only interested in GL 3.x
    enforce(GLVersion.major >= 3);

    // turn v-sync off.
    glfwSwapInterval(0);

    version (OSX)
    {
        // GL_ARM_debug_output and GL_KHR_debug are not supported under OS X 10.9.3
    }
    else
    {
        // ensure the debug output extension is supported
        enforce(GL_ARB_debug_output || GL_KHR_debug);

        // cast: workaround for 'nothrow' propagation bug (haven't been able to reduce it)
        auto hookDebugCallback = GL_ARB_debug_output ? glDebugMessageCallbackARB
                                                     : cast(typeof(glDebugMessageCallbackARB))glDebugMessageCallback;


        // hook the debug callback
        // cast: when using derelict it assumes its nothrow
        hookDebugCallback(cast(GLDEBUGPROCARB)&glErrorCallback, null);

        // enable proper stack tracing support (otherwise we'd get random failures at runtime)
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS_ARB);
    }

    // finally show the window
    glfwShowWindow(window.window);

    return window;
}

/** Create a window and an OpenGL context. */
Window createWindowContext(string windowName, WindowMode windowMode, int width, int height)
{
    auto window = new Window();
    auto monitor = windowMode == WindowMode.fullscreen ? glfwGetPrimaryMonitor() : null;
    auto context = window.create_highest_available_context(width, height, windowName, monitor, null, GLFW_OPENGL_CORE_PROFILE);

    // ensure we've loaded a proper context
    enforce(context.major >= 3);

    return window;
}

/** Just emit errors to stderr on GLFW errors. */
void glfwErrorCallback(int code, string msg)
{
    stderr.writefln("Error (%s): %s", code, msg);
}

///
class GLException : Exception
{
    @safe pure nothrow this(string msg = "", string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}

/**
    GL_ARB_debug_output or GL_KHR_debug callback.

    Throwing exceptions across language boundaries is ok as
    long as $(B GL_DEBUG_OUTPUT_SYNCHRONOUS_ARB) is enabled.
*/
extern (System)
private void glErrorCallback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, in GLchar* message, GLvoid* userParam)
{
    //string msg = format("glErrorCallback: source: %s, type: %s, id: %s, severity: %s, length: %s, message: %s, userParam: %s",
    //                     source, type, id, severity, length, message.to!string, userParam);

    //stderr.writeln(msg);
}
