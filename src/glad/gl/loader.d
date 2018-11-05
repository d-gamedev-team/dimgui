module glad.gl.loader;


private import glad.gl.funcs;
private import glad.gl.ext;
private import glad.gl.enums;
private import glad.gl.types;
alias Loader = void* delegate(const(char)*);

version(Windows) {
    private import core.sys.windows.windows;
} else {
    private import core.sys.posix.dlfcn;
}

version(Windows) {
    private __gshared HMODULE libGL;
} else {
    private __gshared void* libGL;
}
extern(System) private @nogc alias gladGetProcAddressPtrType = void* function(const(char)*);
private __gshared gladGetProcAddressPtrType gladGetProcAddressPtr;

private
bool open_gl() @nogc {
    version(Windows) {
        libGL = LoadLibraryA("opengl32.dll");
        if(libGL !is null) {
            gladGetProcAddressPtr = cast(typeof(gladGetProcAddressPtr))GetProcAddress(
                libGL, "wglGetProcAddress");
            return gladGetProcAddressPtr !is null;
        }

        return false;
    } else {
        version(OSX) {
            enum const(char)*[] NAMES = [
                "../Frameworks/OpenGL.framework/OpenGL",
                "/Library/Frameworks/OpenGL.framework/OpenGL",
                "/System/Library/Frameworks/OpenGL.framework/OpenGL",
                "/System/Library/Frameworks/OpenGL.framework/Versions/Current/OpenGL"
            ];
        } else {
            enum const(char)*[] NAMES = ["libGL.so.1", "libGL.so"];
        }

        foreach(name; NAMES) {
            libGL = dlopen(name, RTLD_NOW | RTLD_GLOBAL);
            if(libGL !is null) {
                version(OSX) {
                    return true;
                } else {
                    gladGetProcAddressPtr = cast(typeof(gladGetProcAddressPtr))dlsym(libGL,
                        "glXGetProcAddressARB");
                    return gladGetProcAddressPtr !is null;
                }
            }
        }

        return false;
    }
}

private
void* get_proc(const(char)* namez) @nogc {
    if(libGL is null) return null;
    void* result;

    if(gladGetProcAddressPtr !is null) {
        result = gladGetProcAddressPtr(namez);
    }
    if(result is null) {
        version(Windows) {
            result = GetProcAddress(libGL, namez);
        } else {
            result = dlsym(libGL, namez);
        }
    }

    return result;
}

private
void close_gl() @nogc {
    version(Windows) {
        if(libGL !is null) {
            FreeLibrary(libGL);
            libGL = null;
        }
    } else {
        if(libGL !is null) {
            dlclose(libGL);
            libGL = null;
        }
    }
}

bool gladLoadGL() {
    bool status = false;

    if(open_gl()) {
        status = gladLoadGL(x => get_proc(x));
        close_gl();
    }

    return status;
}

static struct GLVersion { static int major = 0; static int minor = 0; }
private extern(C) char* strstr(const(char)*, const(char)*) @nogc;
private extern(C) int strcmp(const(char)*, const(char)*) @nogc;
private extern(C) int strncmp(const(char)*, const(char)*, size_t) @nogc;
private extern(C) size_t strlen(const(char)*) @nogc;
private bool has_ext(const(char)* ext) @nogc {
    if(GLVersion.major < 3) {
        const(char)* extensions = cast(const(char)*)glGetString(GL_EXTENSIONS);
        const(char)* loc;
        const(char)* terminator;

        if(extensions is null || ext is null) {
            return false;
        }

        while(1) {
            loc = strstr(extensions, ext);
            if(loc is null) {
                return false;
            }

            terminator = loc + strlen(ext);
            if((loc is extensions || *(loc - 1) == ' ') &&
                (*terminator == ' ' || *terminator == '\0')) {
                return true;
            }
            extensions = terminator;
        }
    } else {
        int num;
        glGetIntegerv(GL_NUM_EXTENSIONS, &num);

        for(uint i=0; i < cast(uint)num; i++) {
            if(strcmp(cast(const(char)*)glGetStringi(GL_EXTENSIONS, i), ext) == 0) {
                return true;
            }
        }
    }

    return false;
}
bool gladLoadGL(Loader load) {
	glGetString = cast(typeof(glGetString))load("glGetString");
	if(glGetString is null) { return false; }
	if(glGetString(GL_VERSION) is null) { return false; }

	find_coreGL();
	load_GL_VERSION_1_0(load);
	load_GL_VERSION_1_1(load);
	load_GL_VERSION_1_2(load);
	load_GL_VERSION_1_3(load);
	load_GL_VERSION_1_4(load);
	load_GL_VERSION_1_5(load);
	load_GL_VERSION_2_0(load);
	load_GL_VERSION_2_1(load);
	load_GL_VERSION_3_0(load);
	load_GL_VERSION_3_1(load);
	load_GL_VERSION_3_2(load);
	load_GL_VERSION_3_3(load);
	load_GL_VERSION_4_0(load);
	load_GL_VERSION_4_1(load);
	load_GL_VERSION_4_2(load);
	load_GL_VERSION_4_3(load);
	load_GL_VERSION_4_4(load);
	load_GL_VERSION_4_5(load);
	load_GL_VERSION_4_6(load);

	find_extensionsGL();
	load_GL_ARB_debug_output(load);
	load_GL_KHR_debug(load);
	return GLVersion.major != 0 || GLVersion.minor != 0;
}

private {

void find_coreGL() {

    // Thank you @elmindreda
    // https://github.com/elmindreda/greg/blob/master/templates/greg.c.in#L176
    // https://github.com/glfw/glfw/blob/master/src/context.c#L36
    int i;
    const(char)* glversion;
    const(char)*[] prefixes = [
        "OpenGL ES-CM ".ptr,
        "OpenGL ES-CL ".ptr,
        "OpenGL ES ".ptr,
    ];

    glversion = cast(const(char)*)glGetString(GL_VERSION);
    if (glversion is null) return;

    foreach(prefix; prefixes) {
        size_t length = strlen(prefix);
        if (strncmp(glversion, prefix, length) == 0) {
            glversion += length;
            break;
        }
    }

    int major = glversion[0] - '0';
    int minor = glversion[2] - '0';
    GLVersion.major = major; GLVersion.minor = minor;
	GL_VERSION_1_0 = (major == 1 && minor >= 0) || major > 1;
	GL_VERSION_1_1 = (major == 1 && minor >= 1) || major > 1;
	GL_VERSION_1_2 = (major == 1 && minor >= 2) || major > 1;
	GL_VERSION_1_3 = (major == 1 && minor >= 3) || major > 1;
	GL_VERSION_1_4 = (major == 1 && minor >= 4) || major > 1;
	GL_VERSION_1_5 = (major == 1 && minor >= 5) || major > 1;
	GL_VERSION_2_0 = (major == 2 && minor >= 0) || major > 2;
	GL_VERSION_2_1 = (major == 2 && minor >= 1) || major > 2;
	GL_VERSION_3_0 = (major == 3 && minor >= 0) || major > 3;
	GL_VERSION_3_1 = (major == 3 && minor >= 1) || major > 3;
	GL_VERSION_3_2 = (major == 3 && minor >= 2) || major > 3;
	GL_VERSION_3_3 = (major == 3 && minor >= 3) || major > 3;
	GL_VERSION_4_0 = (major == 4 && minor >= 0) || major > 4;
	GL_VERSION_4_1 = (major == 4 && minor >= 1) || major > 4;
	GL_VERSION_4_2 = (major == 4 && minor >= 2) || major > 4;
	GL_VERSION_4_3 = (major == 4 && minor >= 3) || major > 4;
	GL_VERSION_4_4 = (major == 4 && minor >= 4) || major > 4;
	GL_VERSION_4_5 = (major == 4 && minor >= 5) || major > 4;
	GL_VERSION_4_6 = (major == 4 && minor >= 6) || major > 4;
	return;
}

void find_extensionsGL() {
	GL_ARB_debug_output = has_ext("GL_ARB_debug_output");
	GL_KHR_debug = has_ext("GL_KHR_debug");
	return;
}

void load_GL_VERSION_1_0(Loader load) {
	if(!GL_VERSION_1_0) return;
	glCullFace = cast(typeof(glCullFace))load("glCullFace");
	glFrontFace = cast(typeof(glFrontFace))load("glFrontFace");
	glHint = cast(typeof(glHint))load("glHint");
	glLineWidth = cast(typeof(glLineWidth))load("glLineWidth");
	glPointSize = cast(typeof(glPointSize))load("glPointSize");
	glPolygonMode = cast(typeof(glPolygonMode))load("glPolygonMode");
	glScissor = cast(typeof(glScissor))load("glScissor");
	glTexParameterf = cast(typeof(glTexParameterf))load("glTexParameterf");
	glTexParameterfv = cast(typeof(glTexParameterfv))load("glTexParameterfv");
	glTexParameteri = cast(typeof(glTexParameteri))load("glTexParameteri");
	glTexParameteriv = cast(typeof(glTexParameteriv))load("glTexParameteriv");
	glTexImage1D = cast(typeof(glTexImage1D))load("glTexImage1D");
	glTexImage2D = cast(typeof(glTexImage2D))load("glTexImage2D");
	glDrawBuffer = cast(typeof(glDrawBuffer))load("glDrawBuffer");
	glClear = cast(typeof(glClear))load("glClear");
	glClearColor = cast(typeof(glClearColor))load("glClearColor");
	glClearStencil = cast(typeof(glClearStencil))load("glClearStencil");
	glClearDepth = cast(typeof(glClearDepth))load("glClearDepth");
	glStencilMask = cast(typeof(glStencilMask))load("glStencilMask");
	glColorMask = cast(typeof(glColorMask))load("glColorMask");
	glDepthMask = cast(typeof(glDepthMask))load("glDepthMask");
	glDisable = cast(typeof(glDisable))load("glDisable");
	glEnable = cast(typeof(glEnable))load("glEnable");
	glFinish = cast(typeof(glFinish))load("glFinish");
	glFlush = cast(typeof(glFlush))load("glFlush");
	glBlendFunc = cast(typeof(glBlendFunc))load("glBlendFunc");
	glLogicOp = cast(typeof(glLogicOp))load("glLogicOp");
	glStencilFunc = cast(typeof(glStencilFunc))load("glStencilFunc");
	glStencilOp = cast(typeof(glStencilOp))load("glStencilOp");
	glDepthFunc = cast(typeof(glDepthFunc))load("glDepthFunc");
	glPixelStoref = cast(typeof(glPixelStoref))load("glPixelStoref");
	glPixelStorei = cast(typeof(glPixelStorei))load("glPixelStorei");
	glReadBuffer = cast(typeof(glReadBuffer))load("glReadBuffer");
	glReadPixels = cast(typeof(glReadPixels))load("glReadPixels");
	glGetBooleanv = cast(typeof(glGetBooleanv))load("glGetBooleanv");
	glGetDoublev = cast(typeof(glGetDoublev))load("glGetDoublev");
	glGetError = cast(typeof(glGetError))load("glGetError");
	glGetFloatv = cast(typeof(glGetFloatv))load("glGetFloatv");
	glGetIntegerv = cast(typeof(glGetIntegerv))load("glGetIntegerv");
	glGetString = cast(typeof(glGetString))load("glGetString");
	glGetTexImage = cast(typeof(glGetTexImage))load("glGetTexImage");
	glGetTexParameterfv = cast(typeof(glGetTexParameterfv))load("glGetTexParameterfv");
	glGetTexParameteriv = cast(typeof(glGetTexParameteriv))load("glGetTexParameteriv");
	glGetTexLevelParameterfv = cast(typeof(glGetTexLevelParameterfv))load("glGetTexLevelParameterfv");
	glGetTexLevelParameteriv = cast(typeof(glGetTexLevelParameteriv))load("glGetTexLevelParameteriv");
	glIsEnabled = cast(typeof(glIsEnabled))load("glIsEnabled");
	glDepthRange = cast(typeof(glDepthRange))load("glDepthRange");
	glViewport = cast(typeof(glViewport))load("glViewport");
	glNewList = cast(typeof(glNewList))load("glNewList");
	glEndList = cast(typeof(glEndList))load("glEndList");
	glCallList = cast(typeof(glCallList))load("glCallList");
	glCallLists = cast(typeof(glCallLists))load("glCallLists");
	glDeleteLists = cast(typeof(glDeleteLists))load("glDeleteLists");
	glGenLists = cast(typeof(glGenLists))load("glGenLists");
	glListBase = cast(typeof(glListBase))load("glListBase");
	glBegin = cast(typeof(glBegin))load("glBegin");
	glBitmap = cast(typeof(glBitmap))load("glBitmap");
	glColor3b = cast(typeof(glColor3b))load("glColor3b");
	glColor3bv = cast(typeof(glColor3bv))load("glColor3bv");
	glColor3d = cast(typeof(glColor3d))load("glColor3d");
	glColor3dv = cast(typeof(glColor3dv))load("glColor3dv");
	glColor3f = cast(typeof(glColor3f))load("glColor3f");
	glColor3fv = cast(typeof(glColor3fv))load("glColor3fv");
	glColor3i = cast(typeof(glColor3i))load("glColor3i");
	glColor3iv = cast(typeof(glColor3iv))load("glColor3iv");
	glColor3s = cast(typeof(glColor3s))load("glColor3s");
	glColor3sv = cast(typeof(glColor3sv))load("glColor3sv");
	glColor3ub = cast(typeof(glColor3ub))load("glColor3ub");
	glColor3ubv = cast(typeof(glColor3ubv))load("glColor3ubv");
	glColor3ui = cast(typeof(glColor3ui))load("glColor3ui");
	glColor3uiv = cast(typeof(glColor3uiv))load("glColor3uiv");
	glColor3us = cast(typeof(glColor3us))load("glColor3us");
	glColor3usv = cast(typeof(glColor3usv))load("glColor3usv");
	glColor4b = cast(typeof(glColor4b))load("glColor4b");
	glColor4bv = cast(typeof(glColor4bv))load("glColor4bv");
	glColor4d = cast(typeof(glColor4d))load("glColor4d");
	glColor4dv = cast(typeof(glColor4dv))load("glColor4dv");
	glColor4f = cast(typeof(glColor4f))load("glColor4f");
	glColor4fv = cast(typeof(glColor4fv))load("glColor4fv");
	glColor4i = cast(typeof(glColor4i))load("glColor4i");
	glColor4iv = cast(typeof(glColor4iv))load("glColor4iv");
	glColor4s = cast(typeof(glColor4s))load("glColor4s");
	glColor4sv = cast(typeof(glColor4sv))load("glColor4sv");
	glColor4ub = cast(typeof(glColor4ub))load("glColor4ub");
	glColor4ubv = cast(typeof(glColor4ubv))load("glColor4ubv");
	glColor4ui = cast(typeof(glColor4ui))load("glColor4ui");
	glColor4uiv = cast(typeof(glColor4uiv))load("glColor4uiv");
	glColor4us = cast(typeof(glColor4us))load("glColor4us");
	glColor4usv = cast(typeof(glColor4usv))load("glColor4usv");
	glEdgeFlag = cast(typeof(glEdgeFlag))load("glEdgeFlag");
	glEdgeFlagv = cast(typeof(glEdgeFlagv))load("glEdgeFlagv");
	glEnd = cast(typeof(glEnd))load("glEnd");
	glIndexd = cast(typeof(glIndexd))load("glIndexd");
	glIndexdv = cast(typeof(glIndexdv))load("glIndexdv");
	glIndexf = cast(typeof(glIndexf))load("glIndexf");
	glIndexfv = cast(typeof(glIndexfv))load("glIndexfv");
	glIndexi = cast(typeof(glIndexi))load("glIndexi");
	glIndexiv = cast(typeof(glIndexiv))load("glIndexiv");
	glIndexs = cast(typeof(glIndexs))load("glIndexs");
	glIndexsv = cast(typeof(glIndexsv))load("glIndexsv");
	glNormal3b = cast(typeof(glNormal3b))load("glNormal3b");
	glNormal3bv = cast(typeof(glNormal3bv))load("glNormal3bv");
	glNormal3d = cast(typeof(glNormal3d))load("glNormal3d");
	glNormal3dv = cast(typeof(glNormal3dv))load("glNormal3dv");
	glNormal3f = cast(typeof(glNormal3f))load("glNormal3f");
	glNormal3fv = cast(typeof(glNormal3fv))load("glNormal3fv");
	glNormal3i = cast(typeof(glNormal3i))load("glNormal3i");
	glNormal3iv = cast(typeof(glNormal3iv))load("glNormal3iv");
	glNormal3s = cast(typeof(glNormal3s))load("glNormal3s");
	glNormal3sv = cast(typeof(glNormal3sv))load("glNormal3sv");
	glRasterPos2d = cast(typeof(glRasterPos2d))load("glRasterPos2d");
	glRasterPos2dv = cast(typeof(glRasterPos2dv))load("glRasterPos2dv");
	glRasterPos2f = cast(typeof(glRasterPos2f))load("glRasterPos2f");
	glRasterPos2fv = cast(typeof(glRasterPos2fv))load("glRasterPos2fv");
	glRasterPos2i = cast(typeof(glRasterPos2i))load("glRasterPos2i");
	glRasterPos2iv = cast(typeof(glRasterPos2iv))load("glRasterPos2iv");
	glRasterPos2s = cast(typeof(glRasterPos2s))load("glRasterPos2s");
	glRasterPos2sv = cast(typeof(glRasterPos2sv))load("glRasterPos2sv");
	glRasterPos3d = cast(typeof(glRasterPos3d))load("glRasterPos3d");
	glRasterPos3dv = cast(typeof(glRasterPos3dv))load("glRasterPos3dv");
	glRasterPos3f = cast(typeof(glRasterPos3f))load("glRasterPos3f");
	glRasterPos3fv = cast(typeof(glRasterPos3fv))load("glRasterPos3fv");
	glRasterPos3i = cast(typeof(glRasterPos3i))load("glRasterPos3i");
	glRasterPos3iv = cast(typeof(glRasterPos3iv))load("glRasterPos3iv");
	glRasterPos3s = cast(typeof(glRasterPos3s))load("glRasterPos3s");
	glRasterPos3sv = cast(typeof(glRasterPos3sv))load("glRasterPos3sv");
	glRasterPos4d = cast(typeof(glRasterPos4d))load("glRasterPos4d");
	glRasterPos4dv = cast(typeof(glRasterPos4dv))load("glRasterPos4dv");
	glRasterPos4f = cast(typeof(glRasterPos4f))load("glRasterPos4f");
	glRasterPos4fv = cast(typeof(glRasterPos4fv))load("glRasterPos4fv");
	glRasterPos4i = cast(typeof(glRasterPos4i))load("glRasterPos4i");
	glRasterPos4iv = cast(typeof(glRasterPos4iv))load("glRasterPos4iv");
	glRasterPos4s = cast(typeof(glRasterPos4s))load("glRasterPos4s");
	glRasterPos4sv = cast(typeof(glRasterPos4sv))load("glRasterPos4sv");
	glRectd = cast(typeof(glRectd))load("glRectd");
	glRectdv = cast(typeof(glRectdv))load("glRectdv");
	glRectf = cast(typeof(glRectf))load("glRectf");
	glRectfv = cast(typeof(glRectfv))load("glRectfv");
	glRecti = cast(typeof(glRecti))load("glRecti");
	glRectiv = cast(typeof(glRectiv))load("glRectiv");
	glRects = cast(typeof(glRects))load("glRects");
	glRectsv = cast(typeof(glRectsv))load("glRectsv");
	glTexCoord1d = cast(typeof(glTexCoord1d))load("glTexCoord1d");
	glTexCoord1dv = cast(typeof(glTexCoord1dv))load("glTexCoord1dv");
	glTexCoord1f = cast(typeof(glTexCoord1f))load("glTexCoord1f");
	glTexCoord1fv = cast(typeof(glTexCoord1fv))load("glTexCoord1fv");
	glTexCoord1i = cast(typeof(glTexCoord1i))load("glTexCoord1i");
	glTexCoord1iv = cast(typeof(glTexCoord1iv))load("glTexCoord1iv");
	glTexCoord1s = cast(typeof(glTexCoord1s))load("glTexCoord1s");
	glTexCoord1sv = cast(typeof(glTexCoord1sv))load("glTexCoord1sv");
	glTexCoord2d = cast(typeof(glTexCoord2d))load("glTexCoord2d");
	glTexCoord2dv = cast(typeof(glTexCoord2dv))load("glTexCoord2dv");
	glTexCoord2f = cast(typeof(glTexCoord2f))load("glTexCoord2f");
	glTexCoord2fv = cast(typeof(glTexCoord2fv))load("glTexCoord2fv");
	glTexCoord2i = cast(typeof(glTexCoord2i))load("glTexCoord2i");
	glTexCoord2iv = cast(typeof(glTexCoord2iv))load("glTexCoord2iv");
	glTexCoord2s = cast(typeof(glTexCoord2s))load("glTexCoord2s");
	glTexCoord2sv = cast(typeof(glTexCoord2sv))load("glTexCoord2sv");
	glTexCoord3d = cast(typeof(glTexCoord3d))load("glTexCoord3d");
	glTexCoord3dv = cast(typeof(glTexCoord3dv))load("glTexCoord3dv");
	glTexCoord3f = cast(typeof(glTexCoord3f))load("glTexCoord3f");
	glTexCoord3fv = cast(typeof(glTexCoord3fv))load("glTexCoord3fv");
	glTexCoord3i = cast(typeof(glTexCoord3i))load("glTexCoord3i");
	glTexCoord3iv = cast(typeof(glTexCoord3iv))load("glTexCoord3iv");
	glTexCoord3s = cast(typeof(glTexCoord3s))load("glTexCoord3s");
	glTexCoord3sv = cast(typeof(glTexCoord3sv))load("glTexCoord3sv");
	glTexCoord4d = cast(typeof(glTexCoord4d))load("glTexCoord4d");
	glTexCoord4dv = cast(typeof(glTexCoord4dv))load("glTexCoord4dv");
	glTexCoord4f = cast(typeof(glTexCoord4f))load("glTexCoord4f");
	glTexCoord4fv = cast(typeof(glTexCoord4fv))load("glTexCoord4fv");
	glTexCoord4i = cast(typeof(glTexCoord4i))load("glTexCoord4i");
	glTexCoord4iv = cast(typeof(glTexCoord4iv))load("glTexCoord4iv");
	glTexCoord4s = cast(typeof(glTexCoord4s))load("glTexCoord4s");
	glTexCoord4sv = cast(typeof(glTexCoord4sv))load("glTexCoord4sv");
	glVertex2d = cast(typeof(glVertex2d))load("glVertex2d");
	glVertex2dv = cast(typeof(glVertex2dv))load("glVertex2dv");
	glVertex2f = cast(typeof(glVertex2f))load("glVertex2f");
	glVertex2fv = cast(typeof(glVertex2fv))load("glVertex2fv");
	glVertex2i = cast(typeof(glVertex2i))load("glVertex2i");
	glVertex2iv = cast(typeof(glVertex2iv))load("glVertex2iv");
	glVertex2s = cast(typeof(glVertex2s))load("glVertex2s");
	glVertex2sv = cast(typeof(glVertex2sv))load("glVertex2sv");
	glVertex3d = cast(typeof(glVertex3d))load("glVertex3d");
	glVertex3dv = cast(typeof(glVertex3dv))load("glVertex3dv");
	glVertex3f = cast(typeof(glVertex3f))load("glVertex3f");
	glVertex3fv = cast(typeof(glVertex3fv))load("glVertex3fv");
	glVertex3i = cast(typeof(glVertex3i))load("glVertex3i");
	glVertex3iv = cast(typeof(glVertex3iv))load("glVertex3iv");
	glVertex3s = cast(typeof(glVertex3s))load("glVertex3s");
	glVertex3sv = cast(typeof(glVertex3sv))load("glVertex3sv");
	glVertex4d = cast(typeof(glVertex4d))load("glVertex4d");
	glVertex4dv = cast(typeof(glVertex4dv))load("glVertex4dv");
	glVertex4f = cast(typeof(glVertex4f))load("glVertex4f");
	glVertex4fv = cast(typeof(glVertex4fv))load("glVertex4fv");
	glVertex4i = cast(typeof(glVertex4i))load("glVertex4i");
	glVertex4iv = cast(typeof(glVertex4iv))load("glVertex4iv");
	glVertex4s = cast(typeof(glVertex4s))load("glVertex4s");
	glVertex4sv = cast(typeof(glVertex4sv))load("glVertex4sv");
	glClipPlane = cast(typeof(glClipPlane))load("glClipPlane");
	glColorMaterial = cast(typeof(glColorMaterial))load("glColorMaterial");
	glFogf = cast(typeof(glFogf))load("glFogf");
	glFogfv = cast(typeof(glFogfv))load("glFogfv");
	glFogi = cast(typeof(glFogi))load("glFogi");
	glFogiv = cast(typeof(glFogiv))load("glFogiv");
	glLightf = cast(typeof(glLightf))load("glLightf");
	glLightfv = cast(typeof(glLightfv))load("glLightfv");
	glLighti = cast(typeof(glLighti))load("glLighti");
	glLightiv = cast(typeof(glLightiv))load("glLightiv");
	glLightModelf = cast(typeof(glLightModelf))load("glLightModelf");
	glLightModelfv = cast(typeof(glLightModelfv))load("glLightModelfv");
	glLightModeli = cast(typeof(glLightModeli))load("glLightModeli");
	glLightModeliv = cast(typeof(glLightModeliv))load("glLightModeliv");
	glLineStipple = cast(typeof(glLineStipple))load("glLineStipple");
	glMaterialf = cast(typeof(glMaterialf))load("glMaterialf");
	glMaterialfv = cast(typeof(glMaterialfv))load("glMaterialfv");
	glMateriali = cast(typeof(glMateriali))load("glMateriali");
	glMaterialiv = cast(typeof(glMaterialiv))load("glMaterialiv");
	glPolygonStipple = cast(typeof(glPolygonStipple))load("glPolygonStipple");
	glShadeModel = cast(typeof(glShadeModel))load("glShadeModel");
	glTexEnvf = cast(typeof(glTexEnvf))load("glTexEnvf");
	glTexEnvfv = cast(typeof(glTexEnvfv))load("glTexEnvfv");
	glTexEnvi = cast(typeof(glTexEnvi))load("glTexEnvi");
	glTexEnviv = cast(typeof(glTexEnviv))load("glTexEnviv");
	glTexGend = cast(typeof(glTexGend))load("glTexGend");
	glTexGendv = cast(typeof(glTexGendv))load("glTexGendv");
	glTexGenf = cast(typeof(glTexGenf))load("glTexGenf");
	glTexGenfv = cast(typeof(glTexGenfv))load("glTexGenfv");
	glTexGeni = cast(typeof(glTexGeni))load("glTexGeni");
	glTexGeniv = cast(typeof(glTexGeniv))load("glTexGeniv");
	glFeedbackBuffer = cast(typeof(glFeedbackBuffer))load("glFeedbackBuffer");
	glSelectBuffer = cast(typeof(glSelectBuffer))load("glSelectBuffer");
	glRenderMode = cast(typeof(glRenderMode))load("glRenderMode");
	glInitNames = cast(typeof(glInitNames))load("glInitNames");
	glLoadName = cast(typeof(glLoadName))load("glLoadName");
	glPassThrough = cast(typeof(glPassThrough))load("glPassThrough");
	glPopName = cast(typeof(glPopName))load("glPopName");
	glPushName = cast(typeof(glPushName))load("glPushName");
	glClearAccum = cast(typeof(glClearAccum))load("glClearAccum");
	glClearIndex = cast(typeof(glClearIndex))load("glClearIndex");
	glIndexMask = cast(typeof(glIndexMask))load("glIndexMask");
	glAccum = cast(typeof(glAccum))load("glAccum");
	glPopAttrib = cast(typeof(glPopAttrib))load("glPopAttrib");
	glPushAttrib = cast(typeof(glPushAttrib))load("glPushAttrib");
	glMap1d = cast(typeof(glMap1d))load("glMap1d");
	glMap1f = cast(typeof(glMap1f))load("glMap1f");
	glMap2d = cast(typeof(glMap2d))load("glMap2d");
	glMap2f = cast(typeof(glMap2f))load("glMap2f");
	glMapGrid1d = cast(typeof(glMapGrid1d))load("glMapGrid1d");
	glMapGrid1f = cast(typeof(glMapGrid1f))load("glMapGrid1f");
	glMapGrid2d = cast(typeof(glMapGrid2d))load("glMapGrid2d");
	glMapGrid2f = cast(typeof(glMapGrid2f))load("glMapGrid2f");
	glEvalCoord1d = cast(typeof(glEvalCoord1d))load("glEvalCoord1d");
	glEvalCoord1dv = cast(typeof(glEvalCoord1dv))load("glEvalCoord1dv");
	glEvalCoord1f = cast(typeof(glEvalCoord1f))load("glEvalCoord1f");
	glEvalCoord1fv = cast(typeof(glEvalCoord1fv))load("glEvalCoord1fv");
	glEvalCoord2d = cast(typeof(glEvalCoord2d))load("glEvalCoord2d");
	glEvalCoord2dv = cast(typeof(glEvalCoord2dv))load("glEvalCoord2dv");
	glEvalCoord2f = cast(typeof(glEvalCoord2f))load("glEvalCoord2f");
	glEvalCoord2fv = cast(typeof(glEvalCoord2fv))load("glEvalCoord2fv");
	glEvalMesh1 = cast(typeof(glEvalMesh1))load("glEvalMesh1");
	glEvalPoint1 = cast(typeof(glEvalPoint1))load("glEvalPoint1");
	glEvalMesh2 = cast(typeof(glEvalMesh2))load("glEvalMesh2");
	glEvalPoint2 = cast(typeof(glEvalPoint2))load("glEvalPoint2");
	glAlphaFunc = cast(typeof(glAlphaFunc))load("glAlphaFunc");
	glPixelZoom = cast(typeof(glPixelZoom))load("glPixelZoom");
	glPixelTransferf = cast(typeof(glPixelTransferf))load("glPixelTransferf");
	glPixelTransferi = cast(typeof(glPixelTransferi))load("glPixelTransferi");
	glPixelMapfv = cast(typeof(glPixelMapfv))load("glPixelMapfv");
	glPixelMapuiv = cast(typeof(glPixelMapuiv))load("glPixelMapuiv");
	glPixelMapusv = cast(typeof(glPixelMapusv))load("glPixelMapusv");
	glCopyPixels = cast(typeof(glCopyPixels))load("glCopyPixels");
	glDrawPixels = cast(typeof(glDrawPixels))load("glDrawPixels");
	glGetClipPlane = cast(typeof(glGetClipPlane))load("glGetClipPlane");
	glGetLightfv = cast(typeof(glGetLightfv))load("glGetLightfv");
	glGetLightiv = cast(typeof(glGetLightiv))load("glGetLightiv");
	glGetMapdv = cast(typeof(glGetMapdv))load("glGetMapdv");
	glGetMapfv = cast(typeof(glGetMapfv))load("glGetMapfv");
	glGetMapiv = cast(typeof(glGetMapiv))load("glGetMapiv");
	glGetMaterialfv = cast(typeof(glGetMaterialfv))load("glGetMaterialfv");
	glGetMaterialiv = cast(typeof(glGetMaterialiv))load("glGetMaterialiv");
	glGetPixelMapfv = cast(typeof(glGetPixelMapfv))load("glGetPixelMapfv");
	glGetPixelMapuiv = cast(typeof(glGetPixelMapuiv))load("glGetPixelMapuiv");
	glGetPixelMapusv = cast(typeof(glGetPixelMapusv))load("glGetPixelMapusv");
	glGetPolygonStipple = cast(typeof(glGetPolygonStipple))load("glGetPolygonStipple");
	glGetTexEnvfv = cast(typeof(glGetTexEnvfv))load("glGetTexEnvfv");
	glGetTexEnviv = cast(typeof(glGetTexEnviv))load("glGetTexEnviv");
	glGetTexGendv = cast(typeof(glGetTexGendv))load("glGetTexGendv");
	glGetTexGenfv = cast(typeof(glGetTexGenfv))load("glGetTexGenfv");
	glGetTexGeniv = cast(typeof(glGetTexGeniv))load("glGetTexGeniv");
	glIsList = cast(typeof(glIsList))load("glIsList");
	glFrustum = cast(typeof(glFrustum))load("glFrustum");
	glLoadIdentity = cast(typeof(glLoadIdentity))load("glLoadIdentity");
	glLoadMatrixf = cast(typeof(glLoadMatrixf))load("glLoadMatrixf");
	glLoadMatrixd = cast(typeof(glLoadMatrixd))load("glLoadMatrixd");
	glMatrixMode = cast(typeof(glMatrixMode))load("glMatrixMode");
	glMultMatrixf = cast(typeof(glMultMatrixf))load("glMultMatrixf");
	glMultMatrixd = cast(typeof(glMultMatrixd))load("glMultMatrixd");
	glOrtho = cast(typeof(glOrtho))load("glOrtho");
	glPopMatrix = cast(typeof(glPopMatrix))load("glPopMatrix");
	glPushMatrix = cast(typeof(glPushMatrix))load("glPushMatrix");
	glRotated = cast(typeof(glRotated))load("glRotated");
	glRotatef = cast(typeof(glRotatef))load("glRotatef");
	glScaled = cast(typeof(glScaled))load("glScaled");
	glScalef = cast(typeof(glScalef))load("glScalef");
	glTranslated = cast(typeof(glTranslated))load("glTranslated");
	glTranslatef = cast(typeof(glTranslatef))load("glTranslatef");
	return;
}

void load_GL_VERSION_1_1(Loader load) {
	if(!GL_VERSION_1_1) return;
	glDrawArrays = cast(typeof(glDrawArrays))load("glDrawArrays");
	glDrawElements = cast(typeof(glDrawElements))load("glDrawElements");
	glGetPointerv = cast(typeof(glGetPointerv))load("glGetPointerv");
	glPolygonOffset = cast(typeof(glPolygonOffset))load("glPolygonOffset");
	glCopyTexImage1D = cast(typeof(glCopyTexImage1D))load("glCopyTexImage1D");
	glCopyTexImage2D = cast(typeof(glCopyTexImage2D))load("glCopyTexImage2D");
	glCopyTexSubImage1D = cast(typeof(glCopyTexSubImage1D))load("glCopyTexSubImage1D");
	glCopyTexSubImage2D = cast(typeof(glCopyTexSubImage2D))load("glCopyTexSubImage2D");
	glTexSubImage1D = cast(typeof(glTexSubImage1D))load("glTexSubImage1D");
	glTexSubImage2D = cast(typeof(glTexSubImage2D))load("glTexSubImage2D");
	glBindTexture = cast(typeof(glBindTexture))load("glBindTexture");
	glDeleteTextures = cast(typeof(glDeleteTextures))load("glDeleteTextures");
	glGenTextures = cast(typeof(glGenTextures))load("glGenTextures");
	glIsTexture = cast(typeof(glIsTexture))load("glIsTexture");
	glArrayElement = cast(typeof(glArrayElement))load("glArrayElement");
	glColorPointer = cast(typeof(glColorPointer))load("glColorPointer");
	glDisableClientState = cast(typeof(glDisableClientState))load("glDisableClientState");
	glEdgeFlagPointer = cast(typeof(glEdgeFlagPointer))load("glEdgeFlagPointer");
	glEnableClientState = cast(typeof(glEnableClientState))load("glEnableClientState");
	glIndexPointer = cast(typeof(glIndexPointer))load("glIndexPointer");
	glInterleavedArrays = cast(typeof(glInterleavedArrays))load("glInterleavedArrays");
	glNormalPointer = cast(typeof(glNormalPointer))load("glNormalPointer");
	glTexCoordPointer = cast(typeof(glTexCoordPointer))load("glTexCoordPointer");
	glVertexPointer = cast(typeof(glVertexPointer))load("glVertexPointer");
	glAreTexturesResident = cast(typeof(glAreTexturesResident))load("glAreTexturesResident");
	glPrioritizeTextures = cast(typeof(glPrioritizeTextures))load("glPrioritizeTextures");
	glIndexub = cast(typeof(glIndexub))load("glIndexub");
	glIndexubv = cast(typeof(glIndexubv))load("glIndexubv");
	glPopClientAttrib = cast(typeof(glPopClientAttrib))load("glPopClientAttrib");
	glPushClientAttrib = cast(typeof(glPushClientAttrib))load("glPushClientAttrib");
	return;
}

void load_GL_VERSION_1_2(Loader load) {
	if(!GL_VERSION_1_2) return;
	glDrawRangeElements = cast(typeof(glDrawRangeElements))load("glDrawRangeElements");
	glTexImage3D = cast(typeof(glTexImage3D))load("glTexImage3D");
	glTexSubImage3D = cast(typeof(glTexSubImage3D))load("glTexSubImage3D");
	glCopyTexSubImage3D = cast(typeof(glCopyTexSubImage3D))load("glCopyTexSubImage3D");
	return;
}

void load_GL_VERSION_1_3(Loader load) {
	if(!GL_VERSION_1_3) return;
	glActiveTexture = cast(typeof(glActiveTexture))load("glActiveTexture");
	glSampleCoverage = cast(typeof(glSampleCoverage))load("glSampleCoverage");
	glCompressedTexImage3D = cast(typeof(glCompressedTexImage3D))load("glCompressedTexImage3D");
	glCompressedTexImage2D = cast(typeof(glCompressedTexImage2D))load("glCompressedTexImage2D");
	glCompressedTexImage1D = cast(typeof(glCompressedTexImage1D))load("glCompressedTexImage1D");
	glCompressedTexSubImage3D = cast(typeof(glCompressedTexSubImage3D))load("glCompressedTexSubImage3D");
	glCompressedTexSubImage2D = cast(typeof(glCompressedTexSubImage2D))load("glCompressedTexSubImage2D");
	glCompressedTexSubImage1D = cast(typeof(glCompressedTexSubImage1D))load("glCompressedTexSubImage1D");
	glGetCompressedTexImage = cast(typeof(glGetCompressedTexImage))load("glGetCompressedTexImage");
	glClientActiveTexture = cast(typeof(glClientActiveTexture))load("glClientActiveTexture");
	glMultiTexCoord1d = cast(typeof(glMultiTexCoord1d))load("glMultiTexCoord1d");
	glMultiTexCoord1dv = cast(typeof(glMultiTexCoord1dv))load("glMultiTexCoord1dv");
	glMultiTexCoord1f = cast(typeof(glMultiTexCoord1f))load("glMultiTexCoord1f");
	glMultiTexCoord1fv = cast(typeof(glMultiTexCoord1fv))load("glMultiTexCoord1fv");
	glMultiTexCoord1i = cast(typeof(glMultiTexCoord1i))load("glMultiTexCoord1i");
	glMultiTexCoord1iv = cast(typeof(glMultiTexCoord1iv))load("glMultiTexCoord1iv");
	glMultiTexCoord1s = cast(typeof(glMultiTexCoord1s))load("glMultiTexCoord1s");
	glMultiTexCoord1sv = cast(typeof(glMultiTexCoord1sv))load("glMultiTexCoord1sv");
	glMultiTexCoord2d = cast(typeof(glMultiTexCoord2d))load("glMultiTexCoord2d");
	glMultiTexCoord2dv = cast(typeof(glMultiTexCoord2dv))load("glMultiTexCoord2dv");
	glMultiTexCoord2f = cast(typeof(glMultiTexCoord2f))load("glMultiTexCoord2f");
	glMultiTexCoord2fv = cast(typeof(glMultiTexCoord2fv))load("glMultiTexCoord2fv");
	glMultiTexCoord2i = cast(typeof(glMultiTexCoord2i))load("glMultiTexCoord2i");
	glMultiTexCoord2iv = cast(typeof(glMultiTexCoord2iv))load("glMultiTexCoord2iv");
	glMultiTexCoord2s = cast(typeof(glMultiTexCoord2s))load("glMultiTexCoord2s");
	glMultiTexCoord2sv = cast(typeof(glMultiTexCoord2sv))load("glMultiTexCoord2sv");
	glMultiTexCoord3d = cast(typeof(glMultiTexCoord3d))load("glMultiTexCoord3d");
	glMultiTexCoord3dv = cast(typeof(glMultiTexCoord3dv))load("glMultiTexCoord3dv");
	glMultiTexCoord3f = cast(typeof(glMultiTexCoord3f))load("glMultiTexCoord3f");
	glMultiTexCoord3fv = cast(typeof(glMultiTexCoord3fv))load("glMultiTexCoord3fv");
	glMultiTexCoord3i = cast(typeof(glMultiTexCoord3i))load("glMultiTexCoord3i");
	glMultiTexCoord3iv = cast(typeof(glMultiTexCoord3iv))load("glMultiTexCoord3iv");
	glMultiTexCoord3s = cast(typeof(glMultiTexCoord3s))load("glMultiTexCoord3s");
	glMultiTexCoord3sv = cast(typeof(glMultiTexCoord3sv))load("glMultiTexCoord3sv");
	glMultiTexCoord4d = cast(typeof(glMultiTexCoord4d))load("glMultiTexCoord4d");
	glMultiTexCoord4dv = cast(typeof(glMultiTexCoord4dv))load("glMultiTexCoord4dv");
	glMultiTexCoord4f = cast(typeof(glMultiTexCoord4f))load("glMultiTexCoord4f");
	glMultiTexCoord4fv = cast(typeof(glMultiTexCoord4fv))load("glMultiTexCoord4fv");
	glMultiTexCoord4i = cast(typeof(glMultiTexCoord4i))load("glMultiTexCoord4i");
	glMultiTexCoord4iv = cast(typeof(glMultiTexCoord4iv))load("glMultiTexCoord4iv");
	glMultiTexCoord4s = cast(typeof(glMultiTexCoord4s))load("glMultiTexCoord4s");
	glMultiTexCoord4sv = cast(typeof(glMultiTexCoord4sv))load("glMultiTexCoord4sv");
	glLoadTransposeMatrixf = cast(typeof(glLoadTransposeMatrixf))load("glLoadTransposeMatrixf");
	glLoadTransposeMatrixd = cast(typeof(glLoadTransposeMatrixd))load("glLoadTransposeMatrixd");
	glMultTransposeMatrixf = cast(typeof(glMultTransposeMatrixf))load("glMultTransposeMatrixf");
	glMultTransposeMatrixd = cast(typeof(glMultTransposeMatrixd))load("glMultTransposeMatrixd");
	return;
}

void load_GL_VERSION_1_4(Loader load) {
	if(!GL_VERSION_1_4) return;
	glBlendFuncSeparate = cast(typeof(glBlendFuncSeparate))load("glBlendFuncSeparate");
	glMultiDrawArrays = cast(typeof(glMultiDrawArrays))load("glMultiDrawArrays");
	glMultiDrawElements = cast(typeof(glMultiDrawElements))load("glMultiDrawElements");
	glPointParameterf = cast(typeof(glPointParameterf))load("glPointParameterf");
	glPointParameterfv = cast(typeof(glPointParameterfv))load("glPointParameterfv");
	glPointParameteri = cast(typeof(glPointParameteri))load("glPointParameteri");
	glPointParameteriv = cast(typeof(glPointParameteriv))load("glPointParameteriv");
	glFogCoordf = cast(typeof(glFogCoordf))load("glFogCoordf");
	glFogCoordfv = cast(typeof(glFogCoordfv))load("glFogCoordfv");
	glFogCoordd = cast(typeof(glFogCoordd))load("glFogCoordd");
	glFogCoorddv = cast(typeof(glFogCoorddv))load("glFogCoorddv");
	glFogCoordPointer = cast(typeof(glFogCoordPointer))load("glFogCoordPointer");
	glSecondaryColor3b = cast(typeof(glSecondaryColor3b))load("glSecondaryColor3b");
	glSecondaryColor3bv = cast(typeof(glSecondaryColor3bv))load("glSecondaryColor3bv");
	glSecondaryColor3d = cast(typeof(glSecondaryColor3d))load("glSecondaryColor3d");
	glSecondaryColor3dv = cast(typeof(glSecondaryColor3dv))load("glSecondaryColor3dv");
	glSecondaryColor3f = cast(typeof(glSecondaryColor3f))load("glSecondaryColor3f");
	glSecondaryColor3fv = cast(typeof(glSecondaryColor3fv))load("glSecondaryColor3fv");
	glSecondaryColor3i = cast(typeof(glSecondaryColor3i))load("glSecondaryColor3i");
	glSecondaryColor3iv = cast(typeof(glSecondaryColor3iv))load("glSecondaryColor3iv");
	glSecondaryColor3s = cast(typeof(glSecondaryColor3s))load("glSecondaryColor3s");
	glSecondaryColor3sv = cast(typeof(glSecondaryColor3sv))load("glSecondaryColor3sv");
	glSecondaryColor3ub = cast(typeof(glSecondaryColor3ub))load("glSecondaryColor3ub");
	glSecondaryColor3ubv = cast(typeof(glSecondaryColor3ubv))load("glSecondaryColor3ubv");
	glSecondaryColor3ui = cast(typeof(glSecondaryColor3ui))load("glSecondaryColor3ui");
	glSecondaryColor3uiv = cast(typeof(glSecondaryColor3uiv))load("glSecondaryColor3uiv");
	glSecondaryColor3us = cast(typeof(glSecondaryColor3us))load("glSecondaryColor3us");
	glSecondaryColor3usv = cast(typeof(glSecondaryColor3usv))load("glSecondaryColor3usv");
	glSecondaryColorPointer = cast(typeof(glSecondaryColorPointer))load("glSecondaryColorPointer");
	glWindowPos2d = cast(typeof(glWindowPos2d))load("glWindowPos2d");
	glWindowPos2dv = cast(typeof(glWindowPos2dv))load("glWindowPos2dv");
	glWindowPos2f = cast(typeof(glWindowPos2f))load("glWindowPos2f");
	glWindowPos2fv = cast(typeof(glWindowPos2fv))load("glWindowPos2fv");
	glWindowPos2i = cast(typeof(glWindowPos2i))load("glWindowPos2i");
	glWindowPos2iv = cast(typeof(glWindowPos2iv))load("glWindowPos2iv");
	glWindowPos2s = cast(typeof(glWindowPos2s))load("glWindowPos2s");
	glWindowPos2sv = cast(typeof(glWindowPos2sv))load("glWindowPos2sv");
	glWindowPos3d = cast(typeof(glWindowPos3d))load("glWindowPos3d");
	glWindowPos3dv = cast(typeof(glWindowPos3dv))load("glWindowPos3dv");
	glWindowPos3f = cast(typeof(glWindowPos3f))load("glWindowPos3f");
	glWindowPos3fv = cast(typeof(glWindowPos3fv))load("glWindowPos3fv");
	glWindowPos3i = cast(typeof(glWindowPos3i))load("glWindowPos3i");
	glWindowPos3iv = cast(typeof(glWindowPos3iv))load("glWindowPos3iv");
	glWindowPos3s = cast(typeof(glWindowPos3s))load("glWindowPos3s");
	glWindowPos3sv = cast(typeof(glWindowPos3sv))load("glWindowPos3sv");
	glBlendColor = cast(typeof(glBlendColor))load("glBlendColor");
	glBlendEquation = cast(typeof(glBlendEquation))load("glBlendEquation");
	return;
}

void load_GL_VERSION_1_5(Loader load) {
	if(!GL_VERSION_1_5) return;
	glGenQueries = cast(typeof(glGenQueries))load("glGenQueries");
	glDeleteQueries = cast(typeof(glDeleteQueries))load("glDeleteQueries");
	glIsQuery = cast(typeof(glIsQuery))load("glIsQuery");
	glBeginQuery = cast(typeof(glBeginQuery))load("glBeginQuery");
	glEndQuery = cast(typeof(glEndQuery))load("glEndQuery");
	glGetQueryiv = cast(typeof(glGetQueryiv))load("glGetQueryiv");
	glGetQueryObjectiv = cast(typeof(glGetQueryObjectiv))load("glGetQueryObjectiv");
	glGetQueryObjectuiv = cast(typeof(glGetQueryObjectuiv))load("glGetQueryObjectuiv");
	glBindBuffer = cast(typeof(glBindBuffer))load("glBindBuffer");
	glDeleteBuffers = cast(typeof(glDeleteBuffers))load("glDeleteBuffers");
	glGenBuffers = cast(typeof(glGenBuffers))load("glGenBuffers");
	glIsBuffer = cast(typeof(glIsBuffer))load("glIsBuffer");
	glBufferData = cast(typeof(glBufferData))load("glBufferData");
	glBufferSubData = cast(typeof(glBufferSubData))load("glBufferSubData");
	glGetBufferSubData = cast(typeof(glGetBufferSubData))load("glGetBufferSubData");
	glMapBuffer = cast(typeof(glMapBuffer))load("glMapBuffer");
	glUnmapBuffer = cast(typeof(glUnmapBuffer))load("glUnmapBuffer");
	glGetBufferParameteriv = cast(typeof(glGetBufferParameteriv))load("glGetBufferParameteriv");
	glGetBufferPointerv = cast(typeof(glGetBufferPointerv))load("glGetBufferPointerv");
	return;
}

void load_GL_VERSION_2_0(Loader load) {
	if(!GL_VERSION_2_0) return;
	glBlendEquationSeparate = cast(typeof(glBlendEquationSeparate))load("glBlendEquationSeparate");
	glDrawBuffers = cast(typeof(glDrawBuffers))load("glDrawBuffers");
	glStencilOpSeparate = cast(typeof(glStencilOpSeparate))load("glStencilOpSeparate");
	glStencilFuncSeparate = cast(typeof(glStencilFuncSeparate))load("glStencilFuncSeparate");
	glStencilMaskSeparate = cast(typeof(glStencilMaskSeparate))load("glStencilMaskSeparate");
	glAttachShader = cast(typeof(glAttachShader))load("glAttachShader");
	glBindAttribLocation = cast(typeof(glBindAttribLocation))load("glBindAttribLocation");
	glCompileShader = cast(typeof(glCompileShader))load("glCompileShader");
	glCreateProgram = cast(typeof(glCreateProgram))load("glCreateProgram");
	glCreateShader = cast(typeof(glCreateShader))load("glCreateShader");
	glDeleteProgram = cast(typeof(glDeleteProgram))load("glDeleteProgram");
	glDeleteShader = cast(typeof(glDeleteShader))load("glDeleteShader");
	glDetachShader = cast(typeof(glDetachShader))load("glDetachShader");
	glDisableVertexAttribArray = cast(typeof(glDisableVertexAttribArray))load("glDisableVertexAttribArray");
	glEnableVertexAttribArray = cast(typeof(glEnableVertexAttribArray))load("glEnableVertexAttribArray");
	glGetActiveAttrib = cast(typeof(glGetActiveAttrib))load("glGetActiveAttrib");
	glGetActiveUniform = cast(typeof(glGetActiveUniform))load("glGetActiveUniform");
	glGetAttachedShaders = cast(typeof(glGetAttachedShaders))load("glGetAttachedShaders");
	glGetAttribLocation = cast(typeof(glGetAttribLocation))load("glGetAttribLocation");
	glGetProgramiv = cast(typeof(glGetProgramiv))load("glGetProgramiv");
	glGetProgramInfoLog = cast(typeof(glGetProgramInfoLog))load("glGetProgramInfoLog");
	glGetShaderiv = cast(typeof(glGetShaderiv))load("glGetShaderiv");
	glGetShaderInfoLog = cast(typeof(glGetShaderInfoLog))load("glGetShaderInfoLog");
	glGetShaderSource = cast(typeof(glGetShaderSource))load("glGetShaderSource");
	glGetUniformLocation = cast(typeof(glGetUniformLocation))load("glGetUniformLocation");
	glGetUniformfv = cast(typeof(glGetUniformfv))load("glGetUniformfv");
	glGetUniformiv = cast(typeof(glGetUniformiv))load("glGetUniformiv");
	glGetVertexAttribdv = cast(typeof(glGetVertexAttribdv))load("glGetVertexAttribdv");
	glGetVertexAttribfv = cast(typeof(glGetVertexAttribfv))load("glGetVertexAttribfv");
	glGetVertexAttribiv = cast(typeof(glGetVertexAttribiv))load("glGetVertexAttribiv");
	glGetVertexAttribPointerv = cast(typeof(glGetVertexAttribPointerv))load("glGetVertexAttribPointerv");
	glIsProgram = cast(typeof(glIsProgram))load("glIsProgram");
	glIsShader = cast(typeof(glIsShader))load("glIsShader");
	glLinkProgram = cast(typeof(glLinkProgram))load("glLinkProgram");
	glShaderSource = cast(typeof(glShaderSource))load("glShaderSource");
	glUseProgram = cast(typeof(glUseProgram))load("glUseProgram");
	glUniform1f = cast(typeof(glUniform1f))load("glUniform1f");
	glUniform2f = cast(typeof(glUniform2f))load("glUniform2f");
	glUniform3f = cast(typeof(glUniform3f))load("glUniform3f");
	glUniform4f = cast(typeof(glUniform4f))load("glUniform4f");
	glUniform1i = cast(typeof(glUniform1i))load("glUniform1i");
	glUniform2i = cast(typeof(glUniform2i))load("glUniform2i");
	glUniform3i = cast(typeof(glUniform3i))load("glUniform3i");
	glUniform4i = cast(typeof(glUniform4i))load("glUniform4i");
	glUniform1fv = cast(typeof(glUniform1fv))load("glUniform1fv");
	glUniform2fv = cast(typeof(glUniform2fv))load("glUniform2fv");
	glUniform3fv = cast(typeof(glUniform3fv))load("glUniform3fv");
	glUniform4fv = cast(typeof(glUniform4fv))load("glUniform4fv");
	glUniform1iv = cast(typeof(glUniform1iv))load("glUniform1iv");
	glUniform2iv = cast(typeof(glUniform2iv))load("glUniform2iv");
	glUniform3iv = cast(typeof(glUniform3iv))load("glUniform3iv");
	glUniform4iv = cast(typeof(glUniform4iv))load("glUniform4iv");
	glUniformMatrix2fv = cast(typeof(glUniformMatrix2fv))load("glUniformMatrix2fv");
	glUniformMatrix3fv = cast(typeof(glUniformMatrix3fv))load("glUniformMatrix3fv");
	glUniformMatrix4fv = cast(typeof(glUniformMatrix4fv))load("glUniformMatrix4fv");
	glValidateProgram = cast(typeof(glValidateProgram))load("glValidateProgram");
	glVertexAttrib1d = cast(typeof(glVertexAttrib1d))load("glVertexAttrib1d");
	glVertexAttrib1dv = cast(typeof(glVertexAttrib1dv))load("glVertexAttrib1dv");
	glVertexAttrib1f = cast(typeof(glVertexAttrib1f))load("glVertexAttrib1f");
	glVertexAttrib1fv = cast(typeof(glVertexAttrib1fv))load("glVertexAttrib1fv");
	glVertexAttrib1s = cast(typeof(glVertexAttrib1s))load("glVertexAttrib1s");
	glVertexAttrib1sv = cast(typeof(glVertexAttrib1sv))load("glVertexAttrib1sv");
	glVertexAttrib2d = cast(typeof(glVertexAttrib2d))load("glVertexAttrib2d");
	glVertexAttrib2dv = cast(typeof(glVertexAttrib2dv))load("glVertexAttrib2dv");
	glVertexAttrib2f = cast(typeof(glVertexAttrib2f))load("glVertexAttrib2f");
	glVertexAttrib2fv = cast(typeof(glVertexAttrib2fv))load("glVertexAttrib2fv");
	glVertexAttrib2s = cast(typeof(glVertexAttrib2s))load("glVertexAttrib2s");
	glVertexAttrib2sv = cast(typeof(glVertexAttrib2sv))load("glVertexAttrib2sv");
	glVertexAttrib3d = cast(typeof(glVertexAttrib3d))load("glVertexAttrib3d");
	glVertexAttrib3dv = cast(typeof(glVertexAttrib3dv))load("glVertexAttrib3dv");
	glVertexAttrib3f = cast(typeof(glVertexAttrib3f))load("glVertexAttrib3f");
	glVertexAttrib3fv = cast(typeof(glVertexAttrib3fv))load("glVertexAttrib3fv");
	glVertexAttrib3s = cast(typeof(glVertexAttrib3s))load("glVertexAttrib3s");
	glVertexAttrib3sv = cast(typeof(glVertexAttrib3sv))load("glVertexAttrib3sv");
	glVertexAttrib4Nbv = cast(typeof(glVertexAttrib4Nbv))load("glVertexAttrib4Nbv");
	glVertexAttrib4Niv = cast(typeof(glVertexAttrib4Niv))load("glVertexAttrib4Niv");
	glVertexAttrib4Nsv = cast(typeof(glVertexAttrib4Nsv))load("glVertexAttrib4Nsv");
	glVertexAttrib4Nub = cast(typeof(glVertexAttrib4Nub))load("glVertexAttrib4Nub");
	glVertexAttrib4Nubv = cast(typeof(glVertexAttrib4Nubv))load("glVertexAttrib4Nubv");
	glVertexAttrib4Nuiv = cast(typeof(glVertexAttrib4Nuiv))load("glVertexAttrib4Nuiv");
	glVertexAttrib4Nusv = cast(typeof(glVertexAttrib4Nusv))load("glVertexAttrib4Nusv");
	glVertexAttrib4bv = cast(typeof(glVertexAttrib4bv))load("glVertexAttrib4bv");
	glVertexAttrib4d = cast(typeof(glVertexAttrib4d))load("glVertexAttrib4d");
	glVertexAttrib4dv = cast(typeof(glVertexAttrib4dv))load("glVertexAttrib4dv");
	glVertexAttrib4f = cast(typeof(glVertexAttrib4f))load("glVertexAttrib4f");
	glVertexAttrib4fv = cast(typeof(glVertexAttrib4fv))load("glVertexAttrib4fv");
	glVertexAttrib4iv = cast(typeof(glVertexAttrib4iv))load("glVertexAttrib4iv");
	glVertexAttrib4s = cast(typeof(glVertexAttrib4s))load("glVertexAttrib4s");
	glVertexAttrib4sv = cast(typeof(glVertexAttrib4sv))load("glVertexAttrib4sv");
	glVertexAttrib4ubv = cast(typeof(glVertexAttrib4ubv))load("glVertexAttrib4ubv");
	glVertexAttrib4uiv = cast(typeof(glVertexAttrib4uiv))load("glVertexAttrib4uiv");
	glVertexAttrib4usv = cast(typeof(glVertexAttrib4usv))load("glVertexAttrib4usv");
	glVertexAttribPointer = cast(typeof(glVertexAttribPointer))load("glVertexAttribPointer");
	return;
}

void load_GL_VERSION_2_1(Loader load) {
	if(!GL_VERSION_2_1) return;
	glUniformMatrix2x3fv = cast(typeof(glUniformMatrix2x3fv))load("glUniformMatrix2x3fv");
	glUniformMatrix3x2fv = cast(typeof(glUniformMatrix3x2fv))load("glUniformMatrix3x2fv");
	glUniformMatrix2x4fv = cast(typeof(glUniformMatrix2x4fv))load("glUniformMatrix2x4fv");
	glUniformMatrix4x2fv = cast(typeof(glUniformMatrix4x2fv))load("glUniformMatrix4x2fv");
	glUniformMatrix3x4fv = cast(typeof(glUniformMatrix3x4fv))load("glUniformMatrix3x4fv");
	glUniformMatrix4x3fv = cast(typeof(glUniformMatrix4x3fv))load("glUniformMatrix4x3fv");
	return;
}

void load_GL_VERSION_3_0(Loader load) {
	if(!GL_VERSION_3_0) return;
	glColorMaski = cast(typeof(glColorMaski))load("glColorMaski");
	glGetBooleani_v = cast(typeof(glGetBooleani_v))load("glGetBooleani_v");
	glGetIntegeri_v = cast(typeof(glGetIntegeri_v))load("glGetIntegeri_v");
	glEnablei = cast(typeof(glEnablei))load("glEnablei");
	glDisablei = cast(typeof(glDisablei))load("glDisablei");
	glIsEnabledi = cast(typeof(glIsEnabledi))load("glIsEnabledi");
	glBeginTransformFeedback = cast(typeof(glBeginTransformFeedback))load("glBeginTransformFeedback");
	glEndTransformFeedback = cast(typeof(glEndTransformFeedback))load("glEndTransformFeedback");
	glBindBufferRange = cast(typeof(glBindBufferRange))load("glBindBufferRange");
	glBindBufferBase = cast(typeof(glBindBufferBase))load("glBindBufferBase");
	glTransformFeedbackVaryings = cast(typeof(glTransformFeedbackVaryings))load("glTransformFeedbackVaryings");
	glGetTransformFeedbackVarying = cast(typeof(glGetTransformFeedbackVarying))load("glGetTransformFeedbackVarying");
	glClampColor = cast(typeof(glClampColor))load("glClampColor");
	glBeginConditionalRender = cast(typeof(glBeginConditionalRender))load("glBeginConditionalRender");
	glEndConditionalRender = cast(typeof(glEndConditionalRender))load("glEndConditionalRender");
	glVertexAttribIPointer = cast(typeof(glVertexAttribIPointer))load("glVertexAttribIPointer");
	glGetVertexAttribIiv = cast(typeof(glGetVertexAttribIiv))load("glGetVertexAttribIiv");
	glGetVertexAttribIuiv = cast(typeof(glGetVertexAttribIuiv))load("glGetVertexAttribIuiv");
	glVertexAttribI1i = cast(typeof(glVertexAttribI1i))load("glVertexAttribI1i");
	glVertexAttribI2i = cast(typeof(glVertexAttribI2i))load("glVertexAttribI2i");
	glVertexAttribI3i = cast(typeof(glVertexAttribI3i))load("glVertexAttribI3i");
	glVertexAttribI4i = cast(typeof(glVertexAttribI4i))load("glVertexAttribI4i");
	glVertexAttribI1ui = cast(typeof(glVertexAttribI1ui))load("glVertexAttribI1ui");
	glVertexAttribI2ui = cast(typeof(glVertexAttribI2ui))load("glVertexAttribI2ui");
	glVertexAttribI3ui = cast(typeof(glVertexAttribI3ui))load("glVertexAttribI3ui");
	glVertexAttribI4ui = cast(typeof(glVertexAttribI4ui))load("glVertexAttribI4ui");
	glVertexAttribI1iv = cast(typeof(glVertexAttribI1iv))load("glVertexAttribI1iv");
	glVertexAttribI2iv = cast(typeof(glVertexAttribI2iv))load("glVertexAttribI2iv");
	glVertexAttribI3iv = cast(typeof(glVertexAttribI3iv))load("glVertexAttribI3iv");
	glVertexAttribI4iv = cast(typeof(glVertexAttribI4iv))load("glVertexAttribI4iv");
	glVertexAttribI1uiv = cast(typeof(glVertexAttribI1uiv))load("glVertexAttribI1uiv");
	glVertexAttribI2uiv = cast(typeof(glVertexAttribI2uiv))load("glVertexAttribI2uiv");
	glVertexAttribI3uiv = cast(typeof(glVertexAttribI3uiv))load("glVertexAttribI3uiv");
	glVertexAttribI4uiv = cast(typeof(glVertexAttribI4uiv))load("glVertexAttribI4uiv");
	glVertexAttribI4bv = cast(typeof(glVertexAttribI4bv))load("glVertexAttribI4bv");
	glVertexAttribI4sv = cast(typeof(glVertexAttribI4sv))load("glVertexAttribI4sv");
	glVertexAttribI4ubv = cast(typeof(glVertexAttribI4ubv))load("glVertexAttribI4ubv");
	glVertexAttribI4usv = cast(typeof(glVertexAttribI4usv))load("glVertexAttribI4usv");
	glGetUniformuiv = cast(typeof(glGetUniformuiv))load("glGetUniformuiv");
	glBindFragDataLocation = cast(typeof(glBindFragDataLocation))load("glBindFragDataLocation");
	glGetFragDataLocation = cast(typeof(glGetFragDataLocation))load("glGetFragDataLocation");
	glUniform1ui = cast(typeof(glUniform1ui))load("glUniform1ui");
	glUniform2ui = cast(typeof(glUniform2ui))load("glUniform2ui");
	glUniform3ui = cast(typeof(glUniform3ui))load("glUniform3ui");
	glUniform4ui = cast(typeof(glUniform4ui))load("glUniform4ui");
	glUniform1uiv = cast(typeof(glUniform1uiv))load("glUniform1uiv");
	glUniform2uiv = cast(typeof(glUniform2uiv))load("glUniform2uiv");
	glUniform3uiv = cast(typeof(glUniform3uiv))load("glUniform3uiv");
	glUniform4uiv = cast(typeof(glUniform4uiv))load("glUniform4uiv");
	glTexParameterIiv = cast(typeof(glTexParameterIiv))load("glTexParameterIiv");
	glTexParameterIuiv = cast(typeof(glTexParameterIuiv))load("glTexParameterIuiv");
	glGetTexParameterIiv = cast(typeof(glGetTexParameterIiv))load("glGetTexParameterIiv");
	glGetTexParameterIuiv = cast(typeof(glGetTexParameterIuiv))load("glGetTexParameterIuiv");
	glClearBufferiv = cast(typeof(glClearBufferiv))load("glClearBufferiv");
	glClearBufferuiv = cast(typeof(glClearBufferuiv))load("glClearBufferuiv");
	glClearBufferfv = cast(typeof(glClearBufferfv))load("glClearBufferfv");
	glClearBufferfi = cast(typeof(glClearBufferfi))load("glClearBufferfi");
	glGetStringi = cast(typeof(glGetStringi))load("glGetStringi");
	glIsRenderbuffer = cast(typeof(glIsRenderbuffer))load("glIsRenderbuffer");
	glBindRenderbuffer = cast(typeof(glBindRenderbuffer))load("glBindRenderbuffer");
	glDeleteRenderbuffers = cast(typeof(glDeleteRenderbuffers))load("glDeleteRenderbuffers");
	glGenRenderbuffers = cast(typeof(glGenRenderbuffers))load("glGenRenderbuffers");
	glRenderbufferStorage = cast(typeof(glRenderbufferStorage))load("glRenderbufferStorage");
	glGetRenderbufferParameteriv = cast(typeof(glGetRenderbufferParameteriv))load("glGetRenderbufferParameteriv");
	glIsFramebuffer = cast(typeof(glIsFramebuffer))load("glIsFramebuffer");
	glBindFramebuffer = cast(typeof(glBindFramebuffer))load("glBindFramebuffer");
	glDeleteFramebuffers = cast(typeof(glDeleteFramebuffers))load("glDeleteFramebuffers");
	glGenFramebuffers = cast(typeof(glGenFramebuffers))load("glGenFramebuffers");
	glCheckFramebufferStatus = cast(typeof(glCheckFramebufferStatus))load("glCheckFramebufferStatus");
	glFramebufferTexture1D = cast(typeof(glFramebufferTexture1D))load("glFramebufferTexture1D");
	glFramebufferTexture2D = cast(typeof(glFramebufferTexture2D))load("glFramebufferTexture2D");
	glFramebufferTexture3D = cast(typeof(glFramebufferTexture3D))load("glFramebufferTexture3D");
	glFramebufferRenderbuffer = cast(typeof(glFramebufferRenderbuffer))load("glFramebufferRenderbuffer");
	glGetFramebufferAttachmentParameteriv = cast(typeof(glGetFramebufferAttachmentParameteriv))load("glGetFramebufferAttachmentParameteriv");
	glGenerateMipmap = cast(typeof(glGenerateMipmap))load("glGenerateMipmap");
	glBlitFramebuffer = cast(typeof(glBlitFramebuffer))load("glBlitFramebuffer");
	glRenderbufferStorageMultisample = cast(typeof(glRenderbufferStorageMultisample))load("glRenderbufferStorageMultisample");
	glFramebufferTextureLayer = cast(typeof(glFramebufferTextureLayer))load("glFramebufferTextureLayer");
	glMapBufferRange = cast(typeof(glMapBufferRange))load("glMapBufferRange");
	glFlushMappedBufferRange = cast(typeof(glFlushMappedBufferRange))load("glFlushMappedBufferRange");
	glBindVertexArray = cast(typeof(glBindVertexArray))load("glBindVertexArray");
	glDeleteVertexArrays = cast(typeof(glDeleteVertexArrays))load("glDeleteVertexArrays");
	glGenVertexArrays = cast(typeof(glGenVertexArrays))load("glGenVertexArrays");
	glIsVertexArray = cast(typeof(glIsVertexArray))load("glIsVertexArray");
	return;
}

void load_GL_VERSION_3_1(Loader load) {
	if(!GL_VERSION_3_1) return;
	glDrawArraysInstanced = cast(typeof(glDrawArraysInstanced))load("glDrawArraysInstanced");
	glDrawElementsInstanced = cast(typeof(glDrawElementsInstanced))load("glDrawElementsInstanced");
	glTexBuffer = cast(typeof(glTexBuffer))load("glTexBuffer");
	glPrimitiveRestartIndex = cast(typeof(glPrimitiveRestartIndex))load("glPrimitiveRestartIndex");
	glCopyBufferSubData = cast(typeof(glCopyBufferSubData))load("glCopyBufferSubData");
	glGetUniformIndices = cast(typeof(glGetUniformIndices))load("glGetUniformIndices");
	glGetActiveUniformsiv = cast(typeof(glGetActiveUniformsiv))load("glGetActiveUniformsiv");
	glGetActiveUniformName = cast(typeof(glGetActiveUniformName))load("glGetActiveUniformName");
	glGetUniformBlockIndex = cast(typeof(glGetUniformBlockIndex))load("glGetUniformBlockIndex");
	glGetActiveUniformBlockiv = cast(typeof(glGetActiveUniformBlockiv))load("glGetActiveUniformBlockiv");
	glGetActiveUniformBlockName = cast(typeof(glGetActiveUniformBlockName))load("glGetActiveUniformBlockName");
	glUniformBlockBinding = cast(typeof(glUniformBlockBinding))load("glUniformBlockBinding");
	glBindBufferRange = cast(typeof(glBindBufferRange))load("glBindBufferRange");
	glBindBufferBase = cast(typeof(glBindBufferBase))load("glBindBufferBase");
	glGetIntegeri_v = cast(typeof(glGetIntegeri_v))load("glGetIntegeri_v");
	return;
}

void load_GL_VERSION_3_2(Loader load) {
	if(!GL_VERSION_3_2) return;
	glDrawElementsBaseVertex = cast(typeof(glDrawElementsBaseVertex))load("glDrawElementsBaseVertex");
	glDrawRangeElementsBaseVertex = cast(typeof(glDrawRangeElementsBaseVertex))load("glDrawRangeElementsBaseVertex");
	glDrawElementsInstancedBaseVertex = cast(typeof(glDrawElementsInstancedBaseVertex))load("glDrawElementsInstancedBaseVertex");
	glMultiDrawElementsBaseVertex = cast(typeof(glMultiDrawElementsBaseVertex))load("glMultiDrawElementsBaseVertex");
	glProvokingVertex = cast(typeof(glProvokingVertex))load("glProvokingVertex");
	glFenceSync = cast(typeof(glFenceSync))load("glFenceSync");
	glIsSync = cast(typeof(glIsSync))load("glIsSync");
	glDeleteSync = cast(typeof(glDeleteSync))load("glDeleteSync");
	glClientWaitSync = cast(typeof(glClientWaitSync))load("glClientWaitSync");
	glWaitSync = cast(typeof(glWaitSync))load("glWaitSync");
	glGetInteger64v = cast(typeof(glGetInteger64v))load("glGetInteger64v");
	glGetSynciv = cast(typeof(glGetSynciv))load("glGetSynciv");
	glGetInteger64i_v = cast(typeof(glGetInteger64i_v))load("glGetInteger64i_v");
	glGetBufferParameteri64v = cast(typeof(glGetBufferParameteri64v))load("glGetBufferParameteri64v");
	glFramebufferTexture = cast(typeof(glFramebufferTexture))load("glFramebufferTexture");
	glTexImage2DMultisample = cast(typeof(glTexImage2DMultisample))load("glTexImage2DMultisample");
	glTexImage3DMultisample = cast(typeof(glTexImage3DMultisample))load("glTexImage3DMultisample");
	glGetMultisamplefv = cast(typeof(glGetMultisamplefv))load("glGetMultisamplefv");
	glSampleMaski = cast(typeof(glSampleMaski))load("glSampleMaski");
	return;
}

void load_GL_VERSION_3_3(Loader load) {
	if(!GL_VERSION_3_3) return;
	glBindFragDataLocationIndexed = cast(typeof(glBindFragDataLocationIndexed))load("glBindFragDataLocationIndexed");
	glGetFragDataIndex = cast(typeof(glGetFragDataIndex))load("glGetFragDataIndex");
	glGenSamplers = cast(typeof(glGenSamplers))load("glGenSamplers");
	glDeleteSamplers = cast(typeof(glDeleteSamplers))load("glDeleteSamplers");
	glIsSampler = cast(typeof(glIsSampler))load("glIsSampler");
	glBindSampler = cast(typeof(glBindSampler))load("glBindSampler");
	glSamplerParameteri = cast(typeof(glSamplerParameteri))load("glSamplerParameteri");
	glSamplerParameteriv = cast(typeof(glSamplerParameteriv))load("glSamplerParameteriv");
	glSamplerParameterf = cast(typeof(glSamplerParameterf))load("glSamplerParameterf");
	glSamplerParameterfv = cast(typeof(glSamplerParameterfv))load("glSamplerParameterfv");
	glSamplerParameterIiv = cast(typeof(glSamplerParameterIiv))load("glSamplerParameterIiv");
	glSamplerParameterIuiv = cast(typeof(glSamplerParameterIuiv))load("glSamplerParameterIuiv");
	glGetSamplerParameteriv = cast(typeof(glGetSamplerParameteriv))load("glGetSamplerParameteriv");
	glGetSamplerParameterIiv = cast(typeof(glGetSamplerParameterIiv))load("glGetSamplerParameterIiv");
	glGetSamplerParameterfv = cast(typeof(glGetSamplerParameterfv))load("glGetSamplerParameterfv");
	glGetSamplerParameterIuiv = cast(typeof(glGetSamplerParameterIuiv))load("glGetSamplerParameterIuiv");
	glQueryCounter = cast(typeof(glQueryCounter))load("glQueryCounter");
	glGetQueryObjecti64v = cast(typeof(glGetQueryObjecti64v))load("glGetQueryObjecti64v");
	glGetQueryObjectui64v = cast(typeof(glGetQueryObjectui64v))load("glGetQueryObjectui64v");
	glVertexAttribDivisor = cast(typeof(glVertexAttribDivisor))load("glVertexAttribDivisor");
	glVertexAttribP1ui = cast(typeof(glVertexAttribP1ui))load("glVertexAttribP1ui");
	glVertexAttribP1uiv = cast(typeof(glVertexAttribP1uiv))load("glVertexAttribP1uiv");
	glVertexAttribP2ui = cast(typeof(glVertexAttribP2ui))load("glVertexAttribP2ui");
	glVertexAttribP2uiv = cast(typeof(glVertexAttribP2uiv))load("glVertexAttribP2uiv");
	glVertexAttribP3ui = cast(typeof(glVertexAttribP3ui))load("glVertexAttribP3ui");
	glVertexAttribP3uiv = cast(typeof(glVertexAttribP3uiv))load("glVertexAttribP3uiv");
	glVertexAttribP4ui = cast(typeof(glVertexAttribP4ui))load("glVertexAttribP4ui");
	glVertexAttribP4uiv = cast(typeof(glVertexAttribP4uiv))load("glVertexAttribP4uiv");
	glVertexP2ui = cast(typeof(glVertexP2ui))load("glVertexP2ui");
	glVertexP2uiv = cast(typeof(glVertexP2uiv))load("glVertexP2uiv");
	glVertexP3ui = cast(typeof(glVertexP3ui))load("glVertexP3ui");
	glVertexP3uiv = cast(typeof(glVertexP3uiv))load("glVertexP3uiv");
	glVertexP4ui = cast(typeof(glVertexP4ui))load("glVertexP4ui");
	glVertexP4uiv = cast(typeof(glVertexP4uiv))load("glVertexP4uiv");
	glTexCoordP1ui = cast(typeof(glTexCoordP1ui))load("glTexCoordP1ui");
	glTexCoordP1uiv = cast(typeof(glTexCoordP1uiv))load("glTexCoordP1uiv");
	glTexCoordP2ui = cast(typeof(glTexCoordP2ui))load("glTexCoordP2ui");
	glTexCoordP2uiv = cast(typeof(glTexCoordP2uiv))load("glTexCoordP2uiv");
	glTexCoordP3ui = cast(typeof(glTexCoordP3ui))load("glTexCoordP3ui");
	glTexCoordP3uiv = cast(typeof(glTexCoordP3uiv))load("glTexCoordP3uiv");
	glTexCoordP4ui = cast(typeof(glTexCoordP4ui))load("glTexCoordP4ui");
	glTexCoordP4uiv = cast(typeof(glTexCoordP4uiv))load("glTexCoordP4uiv");
	glMultiTexCoordP1ui = cast(typeof(glMultiTexCoordP1ui))load("glMultiTexCoordP1ui");
	glMultiTexCoordP1uiv = cast(typeof(glMultiTexCoordP1uiv))load("glMultiTexCoordP1uiv");
	glMultiTexCoordP2ui = cast(typeof(glMultiTexCoordP2ui))load("glMultiTexCoordP2ui");
	glMultiTexCoordP2uiv = cast(typeof(glMultiTexCoordP2uiv))load("glMultiTexCoordP2uiv");
	glMultiTexCoordP3ui = cast(typeof(glMultiTexCoordP3ui))load("glMultiTexCoordP3ui");
	glMultiTexCoordP3uiv = cast(typeof(glMultiTexCoordP3uiv))load("glMultiTexCoordP3uiv");
	glMultiTexCoordP4ui = cast(typeof(glMultiTexCoordP4ui))load("glMultiTexCoordP4ui");
	glMultiTexCoordP4uiv = cast(typeof(glMultiTexCoordP4uiv))load("glMultiTexCoordP4uiv");
	glNormalP3ui = cast(typeof(glNormalP3ui))load("glNormalP3ui");
	glNormalP3uiv = cast(typeof(glNormalP3uiv))load("glNormalP3uiv");
	glColorP3ui = cast(typeof(glColorP3ui))load("glColorP3ui");
	glColorP3uiv = cast(typeof(glColorP3uiv))load("glColorP3uiv");
	glColorP4ui = cast(typeof(glColorP4ui))load("glColorP4ui");
	glColorP4uiv = cast(typeof(glColorP4uiv))load("glColorP4uiv");
	glSecondaryColorP3ui = cast(typeof(glSecondaryColorP3ui))load("glSecondaryColorP3ui");
	glSecondaryColorP3uiv = cast(typeof(glSecondaryColorP3uiv))load("glSecondaryColorP3uiv");
	return;
}

void load_GL_VERSION_4_0(Loader load) {
	if(!GL_VERSION_4_0) return;
	glMinSampleShading = cast(typeof(glMinSampleShading))load("glMinSampleShading");
	glBlendEquationi = cast(typeof(glBlendEquationi))load("glBlendEquationi");
	glBlendEquationSeparatei = cast(typeof(glBlendEquationSeparatei))load("glBlendEquationSeparatei");
	glBlendFunci = cast(typeof(glBlendFunci))load("glBlendFunci");
	glBlendFuncSeparatei = cast(typeof(glBlendFuncSeparatei))load("glBlendFuncSeparatei");
	glDrawArraysIndirect = cast(typeof(glDrawArraysIndirect))load("glDrawArraysIndirect");
	glDrawElementsIndirect = cast(typeof(glDrawElementsIndirect))load("glDrawElementsIndirect");
	glUniform1d = cast(typeof(glUniform1d))load("glUniform1d");
	glUniform2d = cast(typeof(glUniform2d))load("glUniform2d");
	glUniform3d = cast(typeof(glUniform3d))load("glUniform3d");
	glUniform4d = cast(typeof(glUniform4d))load("glUniform4d");
	glUniform1dv = cast(typeof(glUniform1dv))load("glUniform1dv");
	glUniform2dv = cast(typeof(glUniform2dv))load("glUniform2dv");
	glUniform3dv = cast(typeof(glUniform3dv))load("glUniform3dv");
	glUniform4dv = cast(typeof(glUniform4dv))load("glUniform4dv");
	glUniformMatrix2dv = cast(typeof(glUniformMatrix2dv))load("glUniformMatrix2dv");
	glUniformMatrix3dv = cast(typeof(glUniformMatrix3dv))load("glUniformMatrix3dv");
	glUniformMatrix4dv = cast(typeof(glUniformMatrix4dv))load("glUniformMatrix4dv");
	glUniformMatrix2x3dv = cast(typeof(glUniformMatrix2x3dv))load("glUniformMatrix2x3dv");
	glUniformMatrix2x4dv = cast(typeof(glUniformMatrix2x4dv))load("glUniformMatrix2x4dv");
	glUniformMatrix3x2dv = cast(typeof(glUniformMatrix3x2dv))load("glUniformMatrix3x2dv");
	glUniformMatrix3x4dv = cast(typeof(glUniformMatrix3x4dv))load("glUniformMatrix3x4dv");
	glUniformMatrix4x2dv = cast(typeof(glUniformMatrix4x2dv))load("glUniformMatrix4x2dv");
	glUniformMatrix4x3dv = cast(typeof(glUniformMatrix4x3dv))load("glUniformMatrix4x3dv");
	glGetUniformdv = cast(typeof(glGetUniformdv))load("glGetUniformdv");
	glGetSubroutineUniformLocation = cast(typeof(glGetSubroutineUniformLocation))load("glGetSubroutineUniformLocation");
	glGetSubroutineIndex = cast(typeof(glGetSubroutineIndex))load("glGetSubroutineIndex");
	glGetActiveSubroutineUniformiv = cast(typeof(glGetActiveSubroutineUniformiv))load("glGetActiveSubroutineUniformiv");
	glGetActiveSubroutineUniformName = cast(typeof(glGetActiveSubroutineUniformName))load("glGetActiveSubroutineUniformName");
	glGetActiveSubroutineName = cast(typeof(glGetActiveSubroutineName))load("glGetActiveSubroutineName");
	glUniformSubroutinesuiv = cast(typeof(glUniformSubroutinesuiv))load("glUniformSubroutinesuiv");
	glGetUniformSubroutineuiv = cast(typeof(glGetUniformSubroutineuiv))load("glGetUniformSubroutineuiv");
	glGetProgramStageiv = cast(typeof(glGetProgramStageiv))load("glGetProgramStageiv");
	glPatchParameteri = cast(typeof(glPatchParameteri))load("glPatchParameteri");
	glPatchParameterfv = cast(typeof(glPatchParameterfv))load("glPatchParameterfv");
	glBindTransformFeedback = cast(typeof(glBindTransformFeedback))load("glBindTransformFeedback");
	glDeleteTransformFeedbacks = cast(typeof(glDeleteTransformFeedbacks))load("glDeleteTransformFeedbacks");
	glGenTransformFeedbacks = cast(typeof(glGenTransformFeedbacks))load("glGenTransformFeedbacks");
	glIsTransformFeedback = cast(typeof(glIsTransformFeedback))load("glIsTransformFeedback");
	glPauseTransformFeedback = cast(typeof(glPauseTransformFeedback))load("glPauseTransformFeedback");
	glResumeTransformFeedback = cast(typeof(glResumeTransformFeedback))load("glResumeTransformFeedback");
	glDrawTransformFeedback = cast(typeof(glDrawTransformFeedback))load("glDrawTransformFeedback");
	glDrawTransformFeedbackStream = cast(typeof(glDrawTransformFeedbackStream))load("glDrawTransformFeedbackStream");
	glBeginQueryIndexed = cast(typeof(glBeginQueryIndexed))load("glBeginQueryIndexed");
	glEndQueryIndexed = cast(typeof(glEndQueryIndexed))load("glEndQueryIndexed");
	glGetQueryIndexediv = cast(typeof(glGetQueryIndexediv))load("glGetQueryIndexediv");
	return;
}

void load_GL_VERSION_4_1(Loader load) {
	if(!GL_VERSION_4_1) return;
	glReleaseShaderCompiler = cast(typeof(glReleaseShaderCompiler))load("glReleaseShaderCompiler");
	glShaderBinary = cast(typeof(glShaderBinary))load("glShaderBinary");
	glGetShaderPrecisionFormat = cast(typeof(glGetShaderPrecisionFormat))load("glGetShaderPrecisionFormat");
	glDepthRangef = cast(typeof(glDepthRangef))load("glDepthRangef");
	glClearDepthf = cast(typeof(glClearDepthf))load("glClearDepthf");
	glGetProgramBinary = cast(typeof(glGetProgramBinary))load("glGetProgramBinary");
	glProgramBinary = cast(typeof(glProgramBinary))load("glProgramBinary");
	glProgramParameteri = cast(typeof(glProgramParameteri))load("glProgramParameteri");
	glUseProgramStages = cast(typeof(glUseProgramStages))load("glUseProgramStages");
	glActiveShaderProgram = cast(typeof(glActiveShaderProgram))load("glActiveShaderProgram");
	glCreateShaderProgramv = cast(typeof(glCreateShaderProgramv))load("glCreateShaderProgramv");
	glBindProgramPipeline = cast(typeof(glBindProgramPipeline))load("glBindProgramPipeline");
	glDeleteProgramPipelines = cast(typeof(glDeleteProgramPipelines))load("glDeleteProgramPipelines");
	glGenProgramPipelines = cast(typeof(glGenProgramPipelines))load("glGenProgramPipelines");
	glIsProgramPipeline = cast(typeof(glIsProgramPipeline))load("glIsProgramPipeline");
	glGetProgramPipelineiv = cast(typeof(glGetProgramPipelineiv))load("glGetProgramPipelineiv");
	glProgramParameteri = cast(typeof(glProgramParameteri))load("glProgramParameteri");
	glProgramUniform1i = cast(typeof(glProgramUniform1i))load("glProgramUniform1i");
	glProgramUniform1iv = cast(typeof(glProgramUniform1iv))load("glProgramUniform1iv");
	glProgramUniform1f = cast(typeof(glProgramUniform1f))load("glProgramUniform1f");
	glProgramUniform1fv = cast(typeof(glProgramUniform1fv))load("glProgramUniform1fv");
	glProgramUniform1d = cast(typeof(glProgramUniform1d))load("glProgramUniform1d");
	glProgramUniform1dv = cast(typeof(glProgramUniform1dv))load("glProgramUniform1dv");
	glProgramUniform1ui = cast(typeof(glProgramUniform1ui))load("glProgramUniform1ui");
	glProgramUniform1uiv = cast(typeof(glProgramUniform1uiv))load("glProgramUniform1uiv");
	glProgramUniform2i = cast(typeof(glProgramUniform2i))load("glProgramUniform2i");
	glProgramUniform2iv = cast(typeof(glProgramUniform2iv))load("glProgramUniform2iv");
	glProgramUniform2f = cast(typeof(glProgramUniform2f))load("glProgramUniform2f");
	glProgramUniform2fv = cast(typeof(glProgramUniform2fv))load("glProgramUniform2fv");
	glProgramUniform2d = cast(typeof(glProgramUniform2d))load("glProgramUniform2d");
	glProgramUniform2dv = cast(typeof(glProgramUniform2dv))load("glProgramUniform2dv");
	glProgramUniform2ui = cast(typeof(glProgramUniform2ui))load("glProgramUniform2ui");
	glProgramUniform2uiv = cast(typeof(glProgramUniform2uiv))load("glProgramUniform2uiv");
	glProgramUniform3i = cast(typeof(glProgramUniform3i))load("glProgramUniform3i");
	glProgramUniform3iv = cast(typeof(glProgramUniform3iv))load("glProgramUniform3iv");
	glProgramUniform3f = cast(typeof(glProgramUniform3f))load("glProgramUniform3f");
	glProgramUniform3fv = cast(typeof(glProgramUniform3fv))load("glProgramUniform3fv");
	glProgramUniform3d = cast(typeof(glProgramUniform3d))load("glProgramUniform3d");
	glProgramUniform3dv = cast(typeof(glProgramUniform3dv))load("glProgramUniform3dv");
	glProgramUniform3ui = cast(typeof(glProgramUniform3ui))load("glProgramUniform3ui");
	glProgramUniform3uiv = cast(typeof(glProgramUniform3uiv))load("glProgramUniform3uiv");
	glProgramUniform4i = cast(typeof(glProgramUniform4i))load("glProgramUniform4i");
	glProgramUniform4iv = cast(typeof(glProgramUniform4iv))load("glProgramUniform4iv");
	glProgramUniform4f = cast(typeof(glProgramUniform4f))load("glProgramUniform4f");
	glProgramUniform4fv = cast(typeof(glProgramUniform4fv))load("glProgramUniform4fv");
	glProgramUniform4d = cast(typeof(glProgramUniform4d))load("glProgramUniform4d");
	glProgramUniform4dv = cast(typeof(glProgramUniform4dv))load("glProgramUniform4dv");
	glProgramUniform4ui = cast(typeof(glProgramUniform4ui))load("glProgramUniform4ui");
	glProgramUniform4uiv = cast(typeof(glProgramUniform4uiv))load("glProgramUniform4uiv");
	glProgramUniformMatrix2fv = cast(typeof(glProgramUniformMatrix2fv))load("glProgramUniformMatrix2fv");
	glProgramUniformMatrix3fv = cast(typeof(glProgramUniformMatrix3fv))load("glProgramUniformMatrix3fv");
	glProgramUniformMatrix4fv = cast(typeof(glProgramUniformMatrix4fv))load("glProgramUniformMatrix4fv");
	glProgramUniformMatrix2dv = cast(typeof(glProgramUniformMatrix2dv))load("glProgramUniformMatrix2dv");
	glProgramUniformMatrix3dv = cast(typeof(glProgramUniformMatrix3dv))load("glProgramUniformMatrix3dv");
	glProgramUniformMatrix4dv = cast(typeof(glProgramUniformMatrix4dv))load("glProgramUniformMatrix4dv");
	glProgramUniformMatrix2x3fv = cast(typeof(glProgramUniformMatrix2x3fv))load("glProgramUniformMatrix2x3fv");
	glProgramUniformMatrix3x2fv = cast(typeof(glProgramUniformMatrix3x2fv))load("glProgramUniformMatrix3x2fv");
	glProgramUniformMatrix2x4fv = cast(typeof(glProgramUniformMatrix2x4fv))load("glProgramUniformMatrix2x4fv");
	glProgramUniformMatrix4x2fv = cast(typeof(glProgramUniformMatrix4x2fv))load("glProgramUniformMatrix4x2fv");
	glProgramUniformMatrix3x4fv = cast(typeof(glProgramUniformMatrix3x4fv))load("glProgramUniformMatrix3x4fv");
	glProgramUniformMatrix4x3fv = cast(typeof(glProgramUniformMatrix4x3fv))load("glProgramUniformMatrix4x3fv");
	glProgramUniformMatrix2x3dv = cast(typeof(glProgramUniformMatrix2x3dv))load("glProgramUniformMatrix2x3dv");
	glProgramUniformMatrix3x2dv = cast(typeof(glProgramUniformMatrix3x2dv))load("glProgramUniformMatrix3x2dv");
	glProgramUniformMatrix2x4dv = cast(typeof(glProgramUniformMatrix2x4dv))load("glProgramUniformMatrix2x4dv");
	glProgramUniformMatrix4x2dv = cast(typeof(glProgramUniformMatrix4x2dv))load("glProgramUniformMatrix4x2dv");
	glProgramUniformMatrix3x4dv = cast(typeof(glProgramUniformMatrix3x4dv))load("glProgramUniformMatrix3x4dv");
	glProgramUniformMatrix4x3dv = cast(typeof(glProgramUniformMatrix4x3dv))load("glProgramUniformMatrix4x3dv");
	glValidateProgramPipeline = cast(typeof(glValidateProgramPipeline))load("glValidateProgramPipeline");
	glGetProgramPipelineInfoLog = cast(typeof(glGetProgramPipelineInfoLog))load("glGetProgramPipelineInfoLog");
	glVertexAttribL1d = cast(typeof(glVertexAttribL1d))load("glVertexAttribL1d");
	glVertexAttribL2d = cast(typeof(glVertexAttribL2d))load("glVertexAttribL2d");
	glVertexAttribL3d = cast(typeof(glVertexAttribL3d))load("glVertexAttribL3d");
	glVertexAttribL4d = cast(typeof(glVertexAttribL4d))load("glVertexAttribL4d");
	glVertexAttribL1dv = cast(typeof(glVertexAttribL1dv))load("glVertexAttribL1dv");
	glVertexAttribL2dv = cast(typeof(glVertexAttribL2dv))load("glVertexAttribL2dv");
	glVertexAttribL3dv = cast(typeof(glVertexAttribL3dv))load("glVertexAttribL3dv");
	glVertexAttribL4dv = cast(typeof(glVertexAttribL4dv))load("glVertexAttribL4dv");
	glVertexAttribLPointer = cast(typeof(glVertexAttribLPointer))load("glVertexAttribLPointer");
	glGetVertexAttribLdv = cast(typeof(glGetVertexAttribLdv))load("glGetVertexAttribLdv");
	glViewportArrayv = cast(typeof(glViewportArrayv))load("glViewportArrayv");
	glViewportIndexedf = cast(typeof(glViewportIndexedf))load("glViewportIndexedf");
	glViewportIndexedfv = cast(typeof(glViewportIndexedfv))load("glViewportIndexedfv");
	glScissorArrayv = cast(typeof(glScissorArrayv))load("glScissorArrayv");
	glScissorIndexed = cast(typeof(glScissorIndexed))load("glScissorIndexed");
	glScissorIndexedv = cast(typeof(glScissorIndexedv))load("glScissorIndexedv");
	glDepthRangeArrayv = cast(typeof(glDepthRangeArrayv))load("glDepthRangeArrayv");
	glDepthRangeIndexed = cast(typeof(glDepthRangeIndexed))load("glDepthRangeIndexed");
	glGetFloati_v = cast(typeof(glGetFloati_v))load("glGetFloati_v");
	glGetDoublei_v = cast(typeof(glGetDoublei_v))load("glGetDoublei_v");
	return;
}

void load_GL_VERSION_4_2(Loader load) {
	if(!GL_VERSION_4_2) return;
	glDrawArraysInstancedBaseInstance = cast(typeof(glDrawArraysInstancedBaseInstance))load("glDrawArraysInstancedBaseInstance");
	glDrawElementsInstancedBaseInstance = cast(typeof(glDrawElementsInstancedBaseInstance))load("glDrawElementsInstancedBaseInstance");
	glDrawElementsInstancedBaseVertexBaseInstance = cast(typeof(glDrawElementsInstancedBaseVertexBaseInstance))load("glDrawElementsInstancedBaseVertexBaseInstance");
	glGetInternalformativ = cast(typeof(glGetInternalformativ))load("glGetInternalformativ");
	glGetActiveAtomicCounterBufferiv = cast(typeof(glGetActiveAtomicCounterBufferiv))load("glGetActiveAtomicCounterBufferiv");
	glBindImageTexture = cast(typeof(glBindImageTexture))load("glBindImageTexture");
	glMemoryBarrier = cast(typeof(glMemoryBarrier))load("glMemoryBarrier");
	glTexStorage1D = cast(typeof(glTexStorage1D))load("glTexStorage1D");
	glTexStorage2D = cast(typeof(glTexStorage2D))load("glTexStorage2D");
	glTexStorage3D = cast(typeof(glTexStorage3D))load("glTexStorage3D");
	glDrawTransformFeedbackInstanced = cast(typeof(glDrawTransformFeedbackInstanced))load("glDrawTransformFeedbackInstanced");
	glDrawTransformFeedbackStreamInstanced = cast(typeof(glDrawTransformFeedbackStreamInstanced))load("glDrawTransformFeedbackStreamInstanced");
	return;
}

void load_GL_VERSION_4_3(Loader load) {
	if(!GL_VERSION_4_3) return;
	glClearBufferData = cast(typeof(glClearBufferData))load("glClearBufferData");
	glClearBufferSubData = cast(typeof(glClearBufferSubData))load("glClearBufferSubData");
	glDispatchCompute = cast(typeof(glDispatchCompute))load("glDispatchCompute");
	glDispatchComputeIndirect = cast(typeof(glDispatchComputeIndirect))load("glDispatchComputeIndirect");
	glCopyImageSubData = cast(typeof(glCopyImageSubData))load("glCopyImageSubData");
	glFramebufferParameteri = cast(typeof(glFramebufferParameteri))load("glFramebufferParameteri");
	glGetFramebufferParameteriv = cast(typeof(glGetFramebufferParameteriv))load("glGetFramebufferParameteriv");
	glGetInternalformati64v = cast(typeof(glGetInternalformati64v))load("glGetInternalformati64v");
	glInvalidateTexSubImage = cast(typeof(glInvalidateTexSubImage))load("glInvalidateTexSubImage");
	glInvalidateTexImage = cast(typeof(glInvalidateTexImage))load("glInvalidateTexImage");
	glInvalidateBufferSubData = cast(typeof(glInvalidateBufferSubData))load("glInvalidateBufferSubData");
	glInvalidateBufferData = cast(typeof(glInvalidateBufferData))load("glInvalidateBufferData");
	glInvalidateFramebuffer = cast(typeof(glInvalidateFramebuffer))load("glInvalidateFramebuffer");
	glInvalidateSubFramebuffer = cast(typeof(glInvalidateSubFramebuffer))load("glInvalidateSubFramebuffer");
	glMultiDrawArraysIndirect = cast(typeof(glMultiDrawArraysIndirect))load("glMultiDrawArraysIndirect");
	glMultiDrawElementsIndirect = cast(typeof(glMultiDrawElementsIndirect))load("glMultiDrawElementsIndirect");
	glGetProgramInterfaceiv = cast(typeof(glGetProgramInterfaceiv))load("glGetProgramInterfaceiv");
	glGetProgramResourceIndex = cast(typeof(glGetProgramResourceIndex))load("glGetProgramResourceIndex");
	glGetProgramResourceName = cast(typeof(glGetProgramResourceName))load("glGetProgramResourceName");
	glGetProgramResourceiv = cast(typeof(glGetProgramResourceiv))load("glGetProgramResourceiv");
	glGetProgramResourceLocation = cast(typeof(glGetProgramResourceLocation))load("glGetProgramResourceLocation");
	glGetProgramResourceLocationIndex = cast(typeof(glGetProgramResourceLocationIndex))load("glGetProgramResourceLocationIndex");
	glShaderStorageBlockBinding = cast(typeof(glShaderStorageBlockBinding))load("glShaderStorageBlockBinding");
	glTexBufferRange = cast(typeof(glTexBufferRange))load("glTexBufferRange");
	glTexStorage2DMultisample = cast(typeof(glTexStorage2DMultisample))load("glTexStorage2DMultisample");
	glTexStorage3DMultisample = cast(typeof(glTexStorage3DMultisample))load("glTexStorage3DMultisample");
	glTextureView = cast(typeof(glTextureView))load("glTextureView");
	glBindVertexBuffer = cast(typeof(glBindVertexBuffer))load("glBindVertexBuffer");
	glVertexAttribFormat = cast(typeof(glVertexAttribFormat))load("glVertexAttribFormat");
	glVertexAttribIFormat = cast(typeof(glVertexAttribIFormat))load("glVertexAttribIFormat");
	glVertexAttribLFormat = cast(typeof(glVertexAttribLFormat))load("glVertexAttribLFormat");
	glVertexAttribBinding = cast(typeof(glVertexAttribBinding))load("glVertexAttribBinding");
	glVertexBindingDivisor = cast(typeof(glVertexBindingDivisor))load("glVertexBindingDivisor");
	glDebugMessageControl = cast(typeof(glDebugMessageControl))load("glDebugMessageControl");
	glDebugMessageInsert = cast(typeof(glDebugMessageInsert))load("glDebugMessageInsert");
	glDebugMessageCallback = cast(typeof(glDebugMessageCallback))load("glDebugMessageCallback");
	glGetDebugMessageLog = cast(typeof(glGetDebugMessageLog))load("glGetDebugMessageLog");
	glPushDebugGroup = cast(typeof(glPushDebugGroup))load("glPushDebugGroup");
	glPopDebugGroup = cast(typeof(glPopDebugGroup))load("glPopDebugGroup");
	glObjectLabel = cast(typeof(glObjectLabel))load("glObjectLabel");
	glGetObjectLabel = cast(typeof(glGetObjectLabel))load("glGetObjectLabel");
	glObjectPtrLabel = cast(typeof(glObjectPtrLabel))load("glObjectPtrLabel");
	glGetObjectPtrLabel = cast(typeof(glGetObjectPtrLabel))load("glGetObjectPtrLabel");
	glGetPointerv = cast(typeof(glGetPointerv))load("glGetPointerv");
	return;
}

void load_GL_VERSION_4_4(Loader load) {
	if(!GL_VERSION_4_4) return;
	glBufferStorage = cast(typeof(glBufferStorage))load("glBufferStorage");
	glClearTexImage = cast(typeof(glClearTexImage))load("glClearTexImage");
	glClearTexSubImage = cast(typeof(glClearTexSubImage))load("glClearTexSubImage");
	glBindBuffersBase = cast(typeof(glBindBuffersBase))load("glBindBuffersBase");
	glBindBuffersRange = cast(typeof(glBindBuffersRange))load("glBindBuffersRange");
	glBindTextures = cast(typeof(glBindTextures))load("glBindTextures");
	glBindSamplers = cast(typeof(glBindSamplers))load("glBindSamplers");
	glBindImageTextures = cast(typeof(glBindImageTextures))load("glBindImageTextures");
	glBindVertexBuffers = cast(typeof(glBindVertexBuffers))load("glBindVertexBuffers");
	return;
}

void load_GL_VERSION_4_5(Loader load) {
	if(!GL_VERSION_4_5) return;
	glClipControl = cast(typeof(glClipControl))load("glClipControl");
	glCreateTransformFeedbacks = cast(typeof(glCreateTransformFeedbacks))load("glCreateTransformFeedbacks");
	glTransformFeedbackBufferBase = cast(typeof(glTransformFeedbackBufferBase))load("glTransformFeedbackBufferBase");
	glTransformFeedbackBufferRange = cast(typeof(glTransformFeedbackBufferRange))load("glTransformFeedbackBufferRange");
	glGetTransformFeedbackiv = cast(typeof(glGetTransformFeedbackiv))load("glGetTransformFeedbackiv");
	glGetTransformFeedbacki_v = cast(typeof(glGetTransformFeedbacki_v))load("glGetTransformFeedbacki_v");
	glGetTransformFeedbacki64_v = cast(typeof(glGetTransformFeedbacki64_v))load("glGetTransformFeedbacki64_v");
	glCreateBuffers = cast(typeof(glCreateBuffers))load("glCreateBuffers");
	glNamedBufferStorage = cast(typeof(glNamedBufferStorage))load("glNamedBufferStorage");
	glNamedBufferData = cast(typeof(glNamedBufferData))load("glNamedBufferData");
	glNamedBufferSubData = cast(typeof(glNamedBufferSubData))load("glNamedBufferSubData");
	glCopyNamedBufferSubData = cast(typeof(glCopyNamedBufferSubData))load("glCopyNamedBufferSubData");
	glClearNamedBufferData = cast(typeof(glClearNamedBufferData))load("glClearNamedBufferData");
	glClearNamedBufferSubData = cast(typeof(glClearNamedBufferSubData))load("glClearNamedBufferSubData");
	glMapNamedBuffer = cast(typeof(glMapNamedBuffer))load("glMapNamedBuffer");
	glMapNamedBufferRange = cast(typeof(glMapNamedBufferRange))load("glMapNamedBufferRange");
	glUnmapNamedBuffer = cast(typeof(glUnmapNamedBuffer))load("glUnmapNamedBuffer");
	glFlushMappedNamedBufferRange = cast(typeof(glFlushMappedNamedBufferRange))load("glFlushMappedNamedBufferRange");
	glGetNamedBufferParameteriv = cast(typeof(glGetNamedBufferParameteriv))load("glGetNamedBufferParameteriv");
	glGetNamedBufferParameteri64v = cast(typeof(glGetNamedBufferParameteri64v))load("glGetNamedBufferParameteri64v");
	glGetNamedBufferPointerv = cast(typeof(glGetNamedBufferPointerv))load("glGetNamedBufferPointerv");
	glGetNamedBufferSubData = cast(typeof(glGetNamedBufferSubData))load("glGetNamedBufferSubData");
	glCreateFramebuffers = cast(typeof(glCreateFramebuffers))load("glCreateFramebuffers");
	glNamedFramebufferRenderbuffer = cast(typeof(glNamedFramebufferRenderbuffer))load("glNamedFramebufferRenderbuffer");
	glNamedFramebufferParameteri = cast(typeof(glNamedFramebufferParameteri))load("glNamedFramebufferParameteri");
	glNamedFramebufferTexture = cast(typeof(glNamedFramebufferTexture))load("glNamedFramebufferTexture");
	glNamedFramebufferTextureLayer = cast(typeof(glNamedFramebufferTextureLayer))load("glNamedFramebufferTextureLayer");
	glNamedFramebufferDrawBuffer = cast(typeof(glNamedFramebufferDrawBuffer))load("glNamedFramebufferDrawBuffer");
	glNamedFramebufferDrawBuffers = cast(typeof(glNamedFramebufferDrawBuffers))load("glNamedFramebufferDrawBuffers");
	glNamedFramebufferReadBuffer = cast(typeof(glNamedFramebufferReadBuffer))load("glNamedFramebufferReadBuffer");
	glInvalidateNamedFramebufferData = cast(typeof(glInvalidateNamedFramebufferData))load("glInvalidateNamedFramebufferData");
	glInvalidateNamedFramebufferSubData = cast(typeof(glInvalidateNamedFramebufferSubData))load("glInvalidateNamedFramebufferSubData");
	glClearNamedFramebufferiv = cast(typeof(glClearNamedFramebufferiv))load("glClearNamedFramebufferiv");
	glClearNamedFramebufferuiv = cast(typeof(glClearNamedFramebufferuiv))load("glClearNamedFramebufferuiv");
	glClearNamedFramebufferfv = cast(typeof(glClearNamedFramebufferfv))load("glClearNamedFramebufferfv");
	glClearNamedFramebufferfi = cast(typeof(glClearNamedFramebufferfi))load("glClearNamedFramebufferfi");
	glBlitNamedFramebuffer = cast(typeof(glBlitNamedFramebuffer))load("glBlitNamedFramebuffer");
	glCheckNamedFramebufferStatus = cast(typeof(glCheckNamedFramebufferStatus))load("glCheckNamedFramebufferStatus");
	glGetNamedFramebufferParameteriv = cast(typeof(glGetNamedFramebufferParameteriv))load("glGetNamedFramebufferParameteriv");
	glGetNamedFramebufferAttachmentParameteriv = cast(typeof(glGetNamedFramebufferAttachmentParameteriv))load("glGetNamedFramebufferAttachmentParameteriv");
	glCreateRenderbuffers = cast(typeof(glCreateRenderbuffers))load("glCreateRenderbuffers");
	glNamedRenderbufferStorage = cast(typeof(glNamedRenderbufferStorage))load("glNamedRenderbufferStorage");
	glNamedRenderbufferStorageMultisample = cast(typeof(glNamedRenderbufferStorageMultisample))load("glNamedRenderbufferStorageMultisample");
	glGetNamedRenderbufferParameteriv = cast(typeof(glGetNamedRenderbufferParameteriv))load("glGetNamedRenderbufferParameteriv");
	glCreateTextures = cast(typeof(glCreateTextures))load("glCreateTextures");
	glTextureBuffer = cast(typeof(glTextureBuffer))load("glTextureBuffer");
	glTextureBufferRange = cast(typeof(glTextureBufferRange))load("glTextureBufferRange");
	glTextureStorage1D = cast(typeof(glTextureStorage1D))load("glTextureStorage1D");
	glTextureStorage2D = cast(typeof(glTextureStorage2D))load("glTextureStorage2D");
	glTextureStorage3D = cast(typeof(glTextureStorage3D))load("glTextureStorage3D");
	glTextureStorage2DMultisample = cast(typeof(glTextureStorage2DMultisample))load("glTextureStorage2DMultisample");
	glTextureStorage3DMultisample = cast(typeof(glTextureStorage3DMultisample))load("glTextureStorage3DMultisample");
	glTextureSubImage1D = cast(typeof(glTextureSubImage1D))load("glTextureSubImage1D");
	glTextureSubImage2D = cast(typeof(glTextureSubImage2D))load("glTextureSubImage2D");
	glTextureSubImage3D = cast(typeof(glTextureSubImage3D))load("glTextureSubImage3D");
	glCompressedTextureSubImage1D = cast(typeof(glCompressedTextureSubImage1D))load("glCompressedTextureSubImage1D");
	glCompressedTextureSubImage2D = cast(typeof(glCompressedTextureSubImage2D))load("glCompressedTextureSubImage2D");
	glCompressedTextureSubImage3D = cast(typeof(glCompressedTextureSubImage3D))load("glCompressedTextureSubImage3D");
	glCopyTextureSubImage1D = cast(typeof(glCopyTextureSubImage1D))load("glCopyTextureSubImage1D");
	glCopyTextureSubImage2D = cast(typeof(glCopyTextureSubImage2D))load("glCopyTextureSubImage2D");
	glCopyTextureSubImage3D = cast(typeof(glCopyTextureSubImage3D))load("glCopyTextureSubImage3D");
	glTextureParameterf = cast(typeof(glTextureParameterf))load("glTextureParameterf");
	glTextureParameterfv = cast(typeof(glTextureParameterfv))load("glTextureParameterfv");
	glTextureParameteri = cast(typeof(glTextureParameteri))load("glTextureParameteri");
	glTextureParameterIiv = cast(typeof(glTextureParameterIiv))load("glTextureParameterIiv");
	glTextureParameterIuiv = cast(typeof(glTextureParameterIuiv))load("glTextureParameterIuiv");
	glTextureParameteriv = cast(typeof(glTextureParameteriv))load("glTextureParameteriv");
	glGenerateTextureMipmap = cast(typeof(glGenerateTextureMipmap))load("glGenerateTextureMipmap");
	glBindTextureUnit = cast(typeof(glBindTextureUnit))load("glBindTextureUnit");
	glGetTextureImage = cast(typeof(glGetTextureImage))load("glGetTextureImage");
	glGetCompressedTextureImage = cast(typeof(glGetCompressedTextureImage))load("glGetCompressedTextureImage");
	glGetTextureLevelParameterfv = cast(typeof(glGetTextureLevelParameterfv))load("glGetTextureLevelParameterfv");
	glGetTextureLevelParameteriv = cast(typeof(glGetTextureLevelParameteriv))load("glGetTextureLevelParameteriv");
	glGetTextureParameterfv = cast(typeof(glGetTextureParameterfv))load("glGetTextureParameterfv");
	glGetTextureParameterIiv = cast(typeof(glGetTextureParameterIiv))load("glGetTextureParameterIiv");
	glGetTextureParameterIuiv = cast(typeof(glGetTextureParameterIuiv))load("glGetTextureParameterIuiv");
	glGetTextureParameteriv = cast(typeof(glGetTextureParameteriv))load("glGetTextureParameteriv");
	glCreateVertexArrays = cast(typeof(glCreateVertexArrays))load("glCreateVertexArrays");
	glDisableVertexArrayAttrib = cast(typeof(glDisableVertexArrayAttrib))load("glDisableVertexArrayAttrib");
	glEnableVertexArrayAttrib = cast(typeof(glEnableVertexArrayAttrib))load("glEnableVertexArrayAttrib");
	glVertexArrayElementBuffer = cast(typeof(glVertexArrayElementBuffer))load("glVertexArrayElementBuffer");
	glVertexArrayVertexBuffer = cast(typeof(glVertexArrayVertexBuffer))load("glVertexArrayVertexBuffer");
	glVertexArrayVertexBuffers = cast(typeof(glVertexArrayVertexBuffers))load("glVertexArrayVertexBuffers");
	glVertexArrayAttribBinding = cast(typeof(glVertexArrayAttribBinding))load("glVertexArrayAttribBinding");
	glVertexArrayAttribFormat = cast(typeof(glVertexArrayAttribFormat))load("glVertexArrayAttribFormat");
	glVertexArrayAttribIFormat = cast(typeof(glVertexArrayAttribIFormat))load("glVertexArrayAttribIFormat");
	glVertexArrayAttribLFormat = cast(typeof(glVertexArrayAttribLFormat))load("glVertexArrayAttribLFormat");
	glVertexArrayBindingDivisor = cast(typeof(glVertexArrayBindingDivisor))load("glVertexArrayBindingDivisor");
	glGetVertexArrayiv = cast(typeof(glGetVertexArrayiv))load("glGetVertexArrayiv");
	glGetVertexArrayIndexediv = cast(typeof(glGetVertexArrayIndexediv))load("glGetVertexArrayIndexediv");
	glGetVertexArrayIndexed64iv = cast(typeof(glGetVertexArrayIndexed64iv))load("glGetVertexArrayIndexed64iv");
	glCreateSamplers = cast(typeof(glCreateSamplers))load("glCreateSamplers");
	glCreateProgramPipelines = cast(typeof(glCreateProgramPipelines))load("glCreateProgramPipelines");
	glCreateQueries = cast(typeof(glCreateQueries))load("glCreateQueries");
	glGetQueryBufferObjecti64v = cast(typeof(glGetQueryBufferObjecti64v))load("glGetQueryBufferObjecti64v");
	glGetQueryBufferObjectiv = cast(typeof(glGetQueryBufferObjectiv))load("glGetQueryBufferObjectiv");
	glGetQueryBufferObjectui64v = cast(typeof(glGetQueryBufferObjectui64v))load("glGetQueryBufferObjectui64v");
	glGetQueryBufferObjectuiv = cast(typeof(glGetQueryBufferObjectuiv))load("glGetQueryBufferObjectuiv");
	glMemoryBarrierByRegion = cast(typeof(glMemoryBarrierByRegion))load("glMemoryBarrierByRegion");
	glGetTextureSubImage = cast(typeof(glGetTextureSubImage))load("glGetTextureSubImage");
	glGetCompressedTextureSubImage = cast(typeof(glGetCompressedTextureSubImage))load("glGetCompressedTextureSubImage");
	glGetGraphicsResetStatus = cast(typeof(glGetGraphicsResetStatus))load("glGetGraphicsResetStatus");
	glGetnCompressedTexImage = cast(typeof(glGetnCompressedTexImage))load("glGetnCompressedTexImage");
	glGetnTexImage = cast(typeof(glGetnTexImage))load("glGetnTexImage");
	glGetnUniformdv = cast(typeof(glGetnUniformdv))load("glGetnUniformdv");
	glGetnUniformfv = cast(typeof(glGetnUniformfv))load("glGetnUniformfv");
	glGetnUniformiv = cast(typeof(glGetnUniformiv))load("glGetnUniformiv");
	glGetnUniformuiv = cast(typeof(glGetnUniformuiv))load("glGetnUniformuiv");
	glReadnPixels = cast(typeof(glReadnPixels))load("glReadnPixels");
	glGetnMapdv = cast(typeof(glGetnMapdv))load("glGetnMapdv");
	glGetnMapfv = cast(typeof(glGetnMapfv))load("glGetnMapfv");
	glGetnMapiv = cast(typeof(glGetnMapiv))load("glGetnMapiv");
	glGetnPixelMapfv = cast(typeof(glGetnPixelMapfv))load("glGetnPixelMapfv");
	glGetnPixelMapuiv = cast(typeof(glGetnPixelMapuiv))load("glGetnPixelMapuiv");
	glGetnPixelMapusv = cast(typeof(glGetnPixelMapusv))load("glGetnPixelMapusv");
	glGetnPolygonStipple = cast(typeof(glGetnPolygonStipple))load("glGetnPolygonStipple");
	glGetnColorTable = cast(typeof(glGetnColorTable))load("glGetnColorTable");
	glGetnConvolutionFilter = cast(typeof(glGetnConvolutionFilter))load("glGetnConvolutionFilter");
	glGetnSeparableFilter = cast(typeof(glGetnSeparableFilter))load("glGetnSeparableFilter");
	glGetnHistogram = cast(typeof(glGetnHistogram))load("glGetnHistogram");
	glGetnMinmax = cast(typeof(glGetnMinmax))load("glGetnMinmax");
	glTextureBarrier = cast(typeof(glTextureBarrier))load("glTextureBarrier");
	return;
}

void load_GL_VERSION_4_6(Loader load) {
	if(!GL_VERSION_4_6) return;
	glSpecializeShader = cast(typeof(glSpecializeShader))load("glSpecializeShader");
	glMultiDrawArraysIndirectCount = cast(typeof(glMultiDrawArraysIndirectCount))load("glMultiDrawArraysIndirectCount");
	glMultiDrawElementsIndirectCount = cast(typeof(glMultiDrawElementsIndirectCount))load("glMultiDrawElementsIndirectCount");
	glPolygonOffsetClamp = cast(typeof(glPolygonOffsetClamp))load("glPolygonOffsetClamp");
	return;
}

void load_GL_ARB_debug_output(Loader load) {
	if(!GL_ARB_debug_output) return;
	glDebugMessageControlARB = cast(typeof(glDebugMessageControlARB))load("glDebugMessageControlARB");
	glDebugMessageInsertARB = cast(typeof(glDebugMessageInsertARB))load("glDebugMessageInsertARB");
	glDebugMessageCallbackARB = cast(typeof(glDebugMessageCallbackARB))load("glDebugMessageCallbackARB");
	glGetDebugMessageLogARB = cast(typeof(glGetDebugMessageLogARB))load("glGetDebugMessageLogARB");
	return;
}
void load_GL_KHR_debug(Loader load) {
	if(!GL_KHR_debug) return;
	glDebugMessageControl = cast(typeof(glDebugMessageControl))load("glDebugMessageControl");
	glDebugMessageInsert = cast(typeof(glDebugMessageInsert))load("glDebugMessageInsert");
	glDebugMessageCallback = cast(typeof(glDebugMessageCallback))load("glDebugMessageCallback");
	glGetDebugMessageLog = cast(typeof(glGetDebugMessageLog))load("glGetDebugMessageLog");
	glPushDebugGroup = cast(typeof(glPushDebugGroup))load("glPushDebugGroup");
	glPopDebugGroup = cast(typeof(glPopDebugGroup))load("glPopDebugGroup");
	glObjectLabel = cast(typeof(glObjectLabel))load("glObjectLabel");
	glGetObjectLabel = cast(typeof(glGetObjectLabel))load("glGetObjectLabel");
	glObjectPtrLabel = cast(typeof(glObjectPtrLabel))load("glObjectPtrLabel");
	glGetObjectPtrLabel = cast(typeof(glGetObjectPtrLabel))load("glGetObjectPtrLabel");
	glGetPointerv = cast(typeof(glGetPointerv))load("glGetPointerv");
	glDebugMessageControlKHR = cast(typeof(glDebugMessageControlKHR))load("glDebugMessageControlKHR");
	glDebugMessageInsertKHR = cast(typeof(glDebugMessageInsertKHR))load("glDebugMessageInsertKHR");
	glDebugMessageCallbackKHR = cast(typeof(glDebugMessageCallbackKHR))load("glDebugMessageCallbackKHR");
	glGetDebugMessageLogKHR = cast(typeof(glGetDebugMessageLogKHR))load("glGetDebugMessageLogKHR");
	glPushDebugGroupKHR = cast(typeof(glPushDebugGroupKHR))load("glPushDebugGroupKHR");
	glPopDebugGroupKHR = cast(typeof(glPopDebugGroupKHR))load("glPopDebugGroupKHR");
	glObjectLabelKHR = cast(typeof(glObjectLabelKHR))load("glObjectLabelKHR");
	glGetObjectLabelKHR = cast(typeof(glGetObjectLabelKHR))load("glGetObjectLabelKHR");
	glObjectPtrLabelKHR = cast(typeof(glObjectPtrLabelKHR))load("glObjectPtrLabelKHR");
	glGetObjectPtrLabelKHR = cast(typeof(glGetObjectPtrLabelKHR))load("glGetObjectPtrLabelKHR");
	glGetPointervKHR = cast(typeof(glGetPointervKHR))load("glGetPointervKHR");
	return;
}

} /* private */

