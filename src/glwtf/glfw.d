module glwtf.glfw;

version(DynamicGLFW) {
    public import derelict.glfw3.glfw3;
} else {
    public import deimos.glfw.glfw3;
}