module glwtf.exception;


class GLFWException : Exception {
    this(string s, string f=__FILE__, size_t l=__LINE__) {
        super(s, f, l);
    }
}

class WindowException : GLFWException {
    this(string s, string f=__FILE__, size_t l=__LINE__) {
        super(s, f, l);
    }
}