module glad.gl.ext;


private import glad.gl.types;
private import glad.gl.enums;
private import glad.gl.funcs;
bool GL_ARB_debug_output;
bool GL_KHR_debug;
nothrow @nogc extern(System) {
alias fp_glDebugMessageControlARB = void function(GLenum, GLenum, GLenum, GLsizei, const(GLuint)*, GLboolean);
alias fp_glDebugMessageInsertARB = void function(GLenum, GLenum, GLuint, GLenum, GLsizei, const(GLchar)*);
alias fp_glDebugMessageCallbackARB = void function(GLDEBUGPROCARB, const(void)*);
alias fp_glGetDebugMessageLogARB = GLuint function(GLuint, GLsizei, GLenum*, GLenum*, GLuint*, GLenum*, GLsizei*, GLchar*);
alias fp_glDebugMessageControlKHR = void function(GLenum, GLenum, GLenum, GLsizei, const(GLuint)*, GLboolean);
alias fp_glDebugMessageInsertKHR = void function(GLenum, GLenum, GLuint, GLenum, GLsizei, const(GLchar)*);
alias fp_glDebugMessageCallbackKHR = void function(GLDEBUGPROCKHR, const(void)*);
alias fp_glGetDebugMessageLogKHR = GLuint function(GLuint, GLsizei, GLenum*, GLenum*, GLuint*, GLenum*, GLsizei*, GLchar*);
alias fp_glPushDebugGroupKHR = void function(GLenum, GLuint, GLsizei, const(GLchar)*);
alias fp_glPopDebugGroupKHR = void function();
alias fp_glObjectLabelKHR = void function(GLenum, GLuint, GLsizei, const(GLchar)*);
alias fp_glGetObjectLabelKHR = void function(GLenum, GLuint, GLsizei, GLsizei*, GLchar*);
alias fp_glObjectPtrLabelKHR = void function(const(void)*, GLsizei, const(GLchar)*);
alias fp_glGetObjectPtrLabelKHR = void function(const(void)*, GLsizei, GLsizei*, GLchar*);
alias fp_glGetPointervKHR = void function(GLenum, void**);
}
__gshared {
fp_glDebugMessageCallbackARB glDebugMessageCallbackARB;
fp_glGetPointervKHR glGetPointervKHR;
fp_glObjectPtrLabelKHR glObjectPtrLabelKHR;
fp_glDebugMessageCallbackKHR glDebugMessageCallbackKHR;
fp_glDebugMessageControlARB glDebugMessageControlARB;
fp_glGetDebugMessageLogARB glGetDebugMessageLogARB;
fp_glGetObjectPtrLabelKHR glGetObjectPtrLabelKHR;
fp_glDebugMessageInsertARB glDebugMessageInsertARB;
fp_glDebugMessageControlKHR glDebugMessageControlKHR;
fp_glObjectLabelKHR glObjectLabelKHR;
fp_glGetDebugMessageLogKHR glGetDebugMessageLogKHR;
fp_glDebugMessageInsertKHR glDebugMessageInsertKHR;
fp_glPopDebugGroupKHR glPopDebugGroupKHR;
fp_glGetObjectLabelKHR glGetObjectLabelKHR;
fp_glPushDebugGroupKHR glPushDebugGroupKHR;
}
