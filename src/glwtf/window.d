module glwtf.window;


private {
    import glwtf.glfw;
    import glwtf.input : BaseGLFWEventHandler;
    import glwtf.exception : WindowException;

    import std.string : toStringz;
    import std.exception : enforce;
    import std.typecons : Tuple;
}


struct Rect {
    int x;
    int y;
}

private string set_hint_property(string target, string name, bool getter=false) {
    string ret = `@property void ` ~ name ~ `(int hint) {
                      set_hint(` ~ target ~ `, hint);
                  }`;

    if(getter) {
        ret ~=   `@property int ` ~ name ~ `() {
                      return get_attrib(` ~ target ~ `);
                  }`;
    }

    return ret;
}


alias Tuple!(int, "major", int, "minor") OGLVT;
immutable OGLVT[] OGLVTS = [OGLVT(4, 3), OGLVT(4, 2), OGLVT(4, 1), OGLVT(4, 0),
                            OGLVT(3, 3), OGLVT(3, 2), OGLVT(3, 1), OGLVT(3, 0)];

class Window : BaseGLFWEventHandler {
    debug {
        private GLFWwindow* _window;

        @property GLFWwindow* window() {
            assert(_window !is null, "no window created yet!");
            return _window;
        }
        @property void window(GLFWwindow* window) {
            _window = window;
        }
    } else {
        GLFWwindow* window;
    }

    this() {
        super();
    }

    this(GLFWwindow* window) {
        super();

        this.window = window;
        register_callbacks(window);
    }

    void set_hint(int target, int hint) {
        glfwWindowHint(target, hint);
    }

    mixin(set_hint_property("GLFW_RED_BITS", "red_bits"));
    mixin(set_hint_property("GLFW_GREEN_BITS", "green_bits"));
    mixin(set_hint_property("GLFW_BLUE_BITS", "blue_bits"));
    mixin(set_hint_property("GLFW_ALPHA_BITS", "alpha_bits"));
    mixin(set_hint_property("GLFW_DEPTH_BITS", "depth_bits"));
    mixin(set_hint_property("GLFW_STENCIL_BITS", "stencil_bits"));
    mixin(set_hint_property("GLFW_ACCUM_RED_BITS", "accum_red_bits"));
    mixin(set_hint_property("GLFW_ACCUM_GREEN_BITS", "accum_green_bits"));
    mixin(set_hint_property("GLFW_ACCUM_BLUE_BITS", "accum_blue_bits"));
    mixin(set_hint_property("GLFW_ACCUM_ALPHA_BITS", "accum_alpha_bits"));
    mixin(set_hint_property("GLFW_AUX_BUFFERS", "aux_buffers"));
    mixin(set_hint_property("GLFW_STEREO", "stereo"));
    mixin(set_hint_property("GLFW_SAMPLES", "samples"));
    mixin(set_hint_property("GLFW_SRGB_CAPABLE", "srgb_capable"));
    mixin(set_hint_property("GLFW_CLIENT_API", "client_api", true));
    mixin(set_hint_property("GLFW_OPENGL_API", "opengl_api"));
    mixin(set_hint_property("GLFW_CONTEXT_VERSION_MAJOR", "context_version_major", true));
    mixin(set_hint_property("GLFW_CONTEXT_VERSION_MINOR", "context_version_minor", true));
    mixin(set_hint_property("GLFW_OPENGL_FORWARD_COMPAT", "opengl_forward_compat", true));
    mixin(set_hint_property("GLFW_OPENGL_DEBUG_CONTEXT", "opengl_debug_context", true));
    mixin(set_hint_property("GLFW_OPENGL_PROFILE", "opengl_profile", true));
    mixin(set_hint_property("GLFW_CONTEXT_ROBUSTNESS", "context_robustness", true));
    mixin(set_hint_property("GLFW_RESIZABLE", "resizable", true));
    mixin(set_hint_property("GLFW_VISIBLE", "visible", true));

    void create(int width, int height, string title, GLFWmonitor* monitor = null, GLFWwindow* share = null) {
        window = glfwCreateWindow(width, height, title.toStringz(), monitor, share);
        enforce!WindowException(window !is null, "Failed to create GLFW Window");
        register_callbacks(window);
    }

    auto create_highest_available_context(int width, int height, string title, GLFWmonitor* monitor = null, GLFWwindow* share = null,
                                          int opengl_profile = GLFW_OPENGL_CORE_PROFILE, bool forward_compat = true) {
        GLFWwindow* win = null;

        foreach(oglvt; OGLVTS) {
            this.context_version_major = oglvt.major;
            this.context_version_minor = oglvt.minor;
            this.opengl_profile = opengl_profile;
            this.opengl_forward_compat = forward_compat;

            win = glfwCreateWindow(width, height, title.toStringz(), monitor, share);

            if(win !is null) {
                window = win;
                register_callbacks(window);
                return oglvt;
            }
        }

        throw new WindowException("Unable to initialize OpenGL forward compatible context (Version >= 3.0).");
    }

    void destroy() {
        glfwDestroyWindow(window);
    }

    @property void title(string title) {
        glfwSetWindowTitle(window, title.toStringz());
    }

    @property void size(Rect rect) {
        glfwSetWindowSize(window, rect.x, rect.y);
    }

    @property Rect size() {
        Rect rect;
        glfwGetWindowSize(window, &rect.x, &rect.y);
        return rect;
    }

    @property int width() {
        return size.x;
    }

    @property int height() {
        return size.y;
    }

    void iconify() {
        glfwIconifyWindow(window);
    }

    void restore() {
        glfwRestoreWindow(window);
    }

//     void show() {
//         glfwShowWindow(window);
//     }
//
//     void hide() {
//         glfwHideWindow(window);
//     }

    int get_attrib(int attrib) {
        return glfwGetWindowAttrib(window, attrib);
    }

    void set_input_mode(int mode, int value) {
        glfwSetInputMode(window, mode, value);
    }

    int get_input_mode(int mode) {
        return glfwGetInputMode(window, mode);
    }

    void make_context_current() {
        glfwMakeContextCurrent(window);
    }

    void swap_buffers() {
        glfwSwapBuffers(window);
    }

    // callbacks ------
    // window
    bool delegate() on_close;

    override bool _on_close() {
        if(on_close !is null) {
            return on_close();
        }

        return true;
    }
}
