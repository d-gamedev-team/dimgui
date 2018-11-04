/*
 * Copyright (c) 2009-2010 Mikko Mononen memon@inside.org
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */
module imgui.gl3_renderer;

import core.stdc.stdlib;
import core.stdc.string;

import std.math;
import std.stdio;

import glad.gl.all;
import glad.gl.loader;

import imgui.api;
import imgui.engine;
import imgui.stdb_truetype;

private:
// Draw up to 65536 unicode glyphs.  What this will actually do is draw *only glyphs the
// font supports* until it will run out of glyphs or texture space (determined by
// g_font_texture_size).  The actual number of glyphs will be in thousands (ASCII is
// guaranteed, the rest will depend mainly on what the font supports, e.g. if it
// supports common European characters such as á or š they will be there because they
// are "early" in Unicode)
//
// Note that g_cdata uses memory of stbtt_bakedchar.sizeof * MAX_CHARACTER_COUNT which
// at the moment is 20 * 65536 or 1.25 MiB.
enum MAX_CHARACTER_COUNT = 1024 * 16 * 4;
enum FIRST_CHARACTER     = 32;



/** Globals start. */

// A 1024x1024 font texture takes 1MiB of memory, and should be enough for thousands of
// glyphs (at the fixed 15.0f size imgui uses).
//
// Some examples:
//
// =================================================== ============ =============================
// Font                                                Texture size Glyps fit
// =================================================== ============ =============================
// GentiumPlus-R                                       512x512      2550 (all glyphs in the font)
// GentiumPlus-R                                       256x256      709
// DroidSans (the small version included for examples) 512x512      903 (all glyphs in the font)
// DroidSans (the small version included for examples) 256x256      497
// =================================================== ============ =============================
//
// This was measured after the optimization to reuse null character glyph, which is in
// BakeFontBitmap in stdb_truetype.d
__gshared uint g_font_texture_size = 1024;
__gshared float[TEMP_COORD_COUNT * 2] g_tempCoords;
__gshared float[TEMP_COORD_COUNT * 2] g_tempNormals;
__gshared float[TEMP_COORD_COUNT * 12 + (TEMP_COORD_COUNT - 2) * 6] g_tempVertices;
__gshared float[TEMP_COORD_COUNT * 12 + (TEMP_COORD_COUNT - 2) * 6] g_tempTextureCoords;
__gshared float[TEMP_COORD_COUNT * 24 + (TEMP_COORD_COUNT - 2) * 12] g_tempColors;
__gshared float[CIRCLE_VERTS * 2] g_circleVerts;
__gshared uint g_max_character_count = MAX_CHARACTER_COUNT;
__gshared stbtt_bakedchar[MAX_CHARACTER_COUNT] g_cdata;
__gshared GLuint g_ftex     = 0;
__gshared GLuint g_whitetex = 0;
__gshared GLuint g_vao      = 0;
__gshared GLuint[3] g_vbos  = [0, 0, 0];
__gshared GLuint g_program = 0;
__gshared GLuint g_programViewportLocation = 0;
__gshared GLuint g_programTextureLocation  = 0;

/** Globals end. */

enum TEMP_COORD_COUNT = 100;
enum int CIRCLE_VERTS = 8 * 4;
immutable float[4] g_tabStops = [150, 210, 270, 330];

package:

uint maxCharacterCount() @trusted nothrow @nogc
{
    return g_max_character_count;
}

void imguifree(void* ptr, void* /*userptr*/)
{
    free(ptr);
}

void* imguimalloc(size_t size, void* /*userptr*/)
{
    return malloc(size);
}

uint toPackedRGBA(RGBA color)
{
    return (color.r) | (color.g << 8) | (color.b << 16) | (color.a << 24);
}

void drawPolygon(const(float)* coords, uint numCoords, float r, uint col)
{
    if (numCoords > TEMP_COORD_COUNT)
        numCoords = TEMP_COORD_COUNT;

    for (uint i = 0, j = numCoords - 1; i < numCoords; j = i++)
    {
        const(float)* v0 = &coords[j * 2];
        const(float)* v1 = &coords[i * 2];
        float dx        = v1[0] - v0[0];
        float dy        = v1[1] - v0[1];
        float d         = sqrt(dx * dx + dy * dy);

        if (d > 0)
        {
            d   = 1.0f / d;
            dx *= d;
            dy *= d;
        }
        g_tempNormals[j * 2 + 0] = dy;
        g_tempNormals[j * 2 + 1] = -dx;
    }

    const float[4] colf      = [cast(float)(col & 0xff) / 255.0, cast(float)((col >> 8) & 0xff) / 255.0, cast(float)((col >> 16) & 0xff) / 255.0, cast(float)((col >> 24) & 0xff) / 255.0];
    const float[4] colTransf = [cast(float)(col & 0xff) / 255.0, cast(float)((col >> 8) & 0xff) / 255.0, cast(float)((col >> 16) & 0xff) / 255.0, 0];

    for (uint i = 0, j = numCoords - 1; i < numCoords; j = i++)
    {
        float dlx0 = g_tempNormals[j * 2 + 0];
        float dly0 = g_tempNormals[j * 2 + 1];
        float dlx1 = g_tempNormals[i * 2 + 0];
        float dly1 = g_tempNormals[i * 2 + 1];
        float dmx  = (dlx0 + dlx1) * 0.5f;
        float dmy  = (dly0 + dly1) * 0.5f;
        float dmr2 = dmx * dmx + dmy * dmy;

        if (dmr2 > 0.000001f)
        {
            float scale = 1.0f / dmr2;

            if (scale > 10.0f)
                scale = 10.0f;
            dmx *= scale;
            dmy *= scale;
        }
        g_tempCoords[i * 2 + 0] = coords[i * 2 + 0] + dmx * r;
        g_tempCoords[i * 2 + 1] = coords[i * 2 + 1] + dmy * r;
    }

    int vSize  = numCoords * 12 + (numCoords - 2) * 6;
    int uvSize = numCoords * 2 * 6 + (numCoords - 2) * 2 * 3;
    int cSize  = numCoords * 4 * 6 + (numCoords - 2) * 4 * 3;
    float* v   = g_tempVertices.ptr;
    float* uv  = g_tempTextureCoords.ptr;
    memset(uv, 0, uvSize * float.sizeof);
    float* c = g_tempColors.ptr;
    memset(c, 1, cSize * float.sizeof);

    float* ptrV = v;
    float* ptrC = c;

    for (uint i = 0, j = numCoords - 1; i < numCoords; j = i++)
    {
        *ptrV       = coords[i * 2];
        *(ptrV + 1) = coords[i * 2 + 1];
        ptrV       += 2;
        *ptrV       = coords[j * 2];
        *(ptrV + 1) = coords[j * 2 + 1];
        ptrV       += 2;
        *ptrV       = g_tempCoords[j * 2];
        *(ptrV + 1) = g_tempCoords[j * 2 + 1];
        ptrV       += 2;
        *ptrV       = g_tempCoords[j * 2];
        *(ptrV + 1) = g_tempCoords[j * 2 + 1];
        ptrV       += 2;
        *ptrV       = g_tempCoords[i * 2];
        *(ptrV + 1) = g_tempCoords[i * 2 + 1];
        ptrV       += 2;
        *ptrV       = coords[i * 2];
        *(ptrV + 1) = coords[i * 2 + 1];
        ptrV       += 2;

        *ptrC       = colf[0];
        *(ptrC + 1) = colf[1];
        *(ptrC + 2) = colf[2];
        *(ptrC + 3) = colf[3];
        ptrC       += 4;
        *ptrC       = colf[0];
        *(ptrC + 1) = colf[1];
        *(ptrC + 2) = colf[2];
        *(ptrC + 3) = colf[3];
        ptrC       += 4;
        *ptrC       = colTransf[0];
        *(ptrC + 1) = colTransf[1];
        *(ptrC + 2) = colTransf[2];
        *(ptrC + 3) = colTransf[3];
        ptrC       += 4;
        *ptrC       = colTransf[0];
        *(ptrC + 1) = colTransf[1];
        *(ptrC + 2) = colTransf[2];
        *(ptrC + 3) = colTransf[3];
        ptrC       += 4;
        *ptrC       = colTransf[0];
        *(ptrC + 1) = colTransf[1];
        *(ptrC + 2) = colTransf[2];
        *(ptrC + 3) = colTransf[3];
        ptrC       += 4;
        *ptrC       = colf[0];
        *(ptrC + 1) = colf[1];
        *(ptrC + 2) = colf[2];
        *(ptrC + 3) = colf[3];
        ptrC       += 4;
    }

    for (uint i = 2; i < numCoords; ++i)
    {
        *ptrV       = coords[0];
        *(ptrV + 1) = coords[1];
        ptrV       += 2;
        *ptrV       = coords[(i - 1) * 2];
        *(ptrV + 1) = coords[(i - 1) * 2 + 1];
        ptrV       += 2;
        *ptrV       = coords[i * 2];
        *(ptrV + 1) = coords[i * 2 + 1];
        ptrV       += 2;

        *ptrC       = colf[0];
        *(ptrC + 1) = colf[1];
        *(ptrC + 2) = colf[2];
        *(ptrC + 3) = colf[3];
        ptrC       += 4;
        *ptrC       = colf[0];
        *(ptrC + 1) = colf[1];
        *(ptrC + 2) = colf[2];
        *(ptrC + 3) = colf[3];
        ptrC       += 4;
        *ptrC       = colf[0];
        *(ptrC + 1) = colf[1];
        *(ptrC + 2) = colf[2];
        *(ptrC + 3) = colf[3];
        ptrC       += 4;
    }

    glBindTexture(GL_TEXTURE_2D, g_whitetex);

    glBindVertexArray(g_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbos[0]);
    glBufferData(GL_ARRAY_BUFFER, vSize * float.sizeof, v, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbos[1]);
    glBufferData(GL_ARRAY_BUFFER, uvSize * float.sizeof, uv, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbos[2]);
    glBufferData(GL_ARRAY_BUFFER, cSize * float.sizeof, c, GL_STATIC_DRAW);
    glDrawArrays(GL_TRIANGLES, 0, (numCoords * 2 + numCoords - 2) * 3);
}

void drawRect(float x, float y, float w, float h, float fth, uint col)
{
    const float[4 * 2] verts =
    [
        x + 0.5f, y + 0.5f,
        x + w - 0.5f, y + 0.5f,
        x + w - 0.5f, y + h - 0.5f,
        x + 0.5f, y + h - 0.5f,
    ];
    drawPolygon(verts.ptr, 4, fth, col);
}

/*
   void drawEllipse(float x, float y, float w, float h, float fth, uint col)
   {
        float verts[CIRCLE_VERTS*2];
        const(float)* cverts = g_circleVerts;
        float* v = verts;

        for (int i = 0; i < CIRCLE_VERTS; ++i)
        {
 * v++ = x + cverts[i*2]*w;
 * v++ = y + cverts[i*2+1]*h;
        }

        drawPolygon(verts, CIRCLE_VERTS, fth, col);
   }
 */

void drawRoundedRect(float x, float y, float w, float h, float r, float fth, uint col)
{
    const uint n = CIRCLE_VERTS / 4;
    float[(n + 1) * 4 * 2] verts;
    const(float)* cverts = g_circleVerts.ptr;
    float* v = verts.ptr;

    for (uint i = 0; i <= n; ++i)
    {
        *v++ = x + w - r + cverts[i * 2] * r;
        *v++ = y + h - r + cverts[i * 2 + 1] * r;
    }

    for (uint i = n; i <= n * 2; ++i)
    {
        *v++ = x + r + cverts[i * 2] * r;
        *v++ = y + h - r + cverts[i * 2 + 1] * r;
    }

    for (uint i = n * 2; i <= n * 3; ++i)
    {
        *v++ = x + r + cverts[i * 2] * r;
        *v++ = y + r + cverts[i * 2 + 1] * r;
    }

    for (uint i = n * 3; i < n * 4; ++i)
    {
        *v++ = x + w - r + cverts[i * 2] * r;
        *v++ = y + r + cverts[i * 2 + 1] * r;
    }

    *v++ = x + w - r + cverts[0] * r;
    *v++ = y + r + cverts[1] * r;

    drawPolygon(verts.ptr, (n + 1) * 4, fth, col);
}

void drawLine(float x0, float y0, float x1, float y1, float r, float fth, uint col)
{
    float dx = x1 - x0;
    float dy = y1 - y0;
    float d  = sqrt(dx * dx + dy * dy);

    if (d > 0.0001f)
    {
        d   = 1.0f / d;
        dx *= d;
        dy *= d;
    }
    float nx = dy;
    float ny = -dx;
    float[4 * 2] verts;
    r -= fth;
    r *= 0.5f;

    if (r < 0.01f)
        r = 0.01f;
    dx *= r;
    dy *= r;
    nx *= r;
    ny *= r;

    verts[0] = x0 - dx - nx;
    verts[1] = y0 - dy - ny;

    verts[2] = x0 - dx + nx;
    verts[3] = y0 - dy + ny;

    verts[4] = x1 + dx + nx;
    verts[5] = y1 + dy + ny;

    verts[6] = x1 + dx - nx;
    verts[7] = y1 + dy - ny;

    drawPolygon(verts.ptr, 4, fth, col);
}

bool imguiRenderGLInit(const(char)[] fontpath, const uint fontTextureSize)
{
    for (int i = 0; i < CIRCLE_VERTS; ++i)
    {
        float a = cast(float)i / cast(float)CIRCLE_VERTS * PI * 2;
        g_circleVerts[i * 2 + 0] = cos(a);
        g_circleVerts[i * 2 + 1] = sin(a);
    }

    // Load font.
    auto file = File(cast(string)fontpath, "rb");
    g_font_texture_size = fontTextureSize;
    FILE* fp = file.getFP();

    if (!fp)
        return false;
    fseek(fp, 0, SEEK_END);
    size_t size = cast(size_t)ftell(fp);
    fseek(fp, 0, SEEK_SET);

    ubyte* ttfBuffer = cast(ubyte*)malloc(size);

    if (!ttfBuffer)
    {
        return false;
    }

    fread(ttfBuffer, 1, size, fp);
    // fclose(fp);
    fp = null;

    ubyte* bmap = cast(ubyte*)malloc(g_font_texture_size * g_font_texture_size);

    if (!bmap)
    {
        free(ttfBuffer);
        return false;
    }

    const result = stbtt_BakeFontBitmap(ttfBuffer, 0, 15.0f, bmap,
                                        g_font_texture_size, g_font_texture_size,
                                        FIRST_CHARACTER, g_max_character_count, g_cdata.ptr);
    // If result is negative, we baked less than max characters so update the max
    // character count.
    if(result < 0)
    {
        g_max_character_count = -result;
    }

    // can free ttf_buffer at this point
    glGenTextures(1, &g_ftex);
    glBindTexture(GL_TEXTURE_2D, g_ftex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED,
                 g_font_texture_size, g_font_texture_size,
                 0, GL_RED, GL_UNSIGNED_BYTE, bmap);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // can free ttf_buffer at this point
    ubyte white_alpha = 255;
    glGenTextures(1, &g_whitetex);
    glBindTexture(GL_TEXTURE_2D, g_whitetex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, 1, 1, 0, GL_RED, GL_UNSIGNED_BYTE, &white_alpha);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glGenVertexArrays(1, &g_vao);
    glGenBuffers(3, g_vbos.ptr);

    glBindVertexArray(g_vao);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);

    glBindBuffer(GL_ARRAY_BUFFER, g_vbos[0]);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, GL_FLOAT.sizeof * 2, null);
    glBufferData(GL_ARRAY_BUFFER, 0, null, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbos[1]);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, GL_FLOAT.sizeof * 2, null);
    glBufferData(GL_ARRAY_BUFFER, 0, null, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbos[2]);
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, GL_FLOAT.sizeof * 4, null);
    glBufferData(GL_ARRAY_BUFFER, 0, null, GL_STATIC_DRAW);
    g_program = glCreateProgram();

    string vs =
        "#version 150\n" ~
        "uniform vec2 Viewport;\n" ~
        "in vec2 VertexPosition;\n" ~
        "in vec2 VertexTexCoord;\n" ~
        "in vec4 VertexColor;\n" ~
        "out vec2 texCoord;\n" ~
        "out vec4 vertexColor;\n" ~
        "void main(void)\n" ~
        "{\n" ~
        "    vertexColor = VertexColor;\n" ~
        "    texCoord = VertexTexCoord;\n" ~
        "    gl_Position = vec4(VertexPosition * 2.0 / Viewport - 1.0, 0.f, 1.0);\n" ~
        "}\n";
    GLuint vso = glCreateShader(GL_VERTEX_SHADER);
    auto vsPtr = vs.ptr;
    glShaderSource(vso, 1, &vsPtr, null);
    glCompileShader(vso);
    glAttachShader(g_program, vso);

    string fs =
        "#version 150\n" ~
        "in vec2 texCoord;\n" ~
        "in vec4 vertexColor;\n" ~
        "uniform sampler2D Texture;\n" ~
        "out vec4  Color;\n" ~
        "void main(void)\n" ~
        "{\n" ~
        "    float alpha = texture(Texture, texCoord).r;\n" ~
        "    Color = vec4(vertexColor.rgb, vertexColor.a * alpha);\n" ~
        "}\n";
    GLuint fso = glCreateShader(GL_FRAGMENT_SHADER);

    auto fsPtr = fs.ptr;
    glShaderSource(fso, 1, &fsPtr, null);
    glCompileShader(fso);
    glAttachShader(g_program, fso);

    glBindAttribLocation(g_program, 0, "VertexPosition");
    glBindAttribLocation(g_program, 1, "VertexTexCoord");
    glBindAttribLocation(g_program, 2, "VertexColor");
    glBindFragDataLocation(g_program, 0, "Color");
    glLinkProgram(g_program);
    glDeleteShader(vso);
    glDeleteShader(fso);

    glUseProgram(g_program);
    g_programViewportLocation = glGetUniformLocation(g_program, "Viewport");
    g_programTextureLocation  = glGetUniformLocation(g_program, "Texture");

    glUseProgram(0);

    free(ttfBuffer);
    free(bmap);

    return true;
}

void imguiRenderGLDestroy()
{
    if (g_ftex)
    {
        glDeleteTextures(1, &g_ftex);
        g_ftex = 0;
    }

    if (g_vao)
    {
        glDeleteVertexArrays(1, &g_vao);
        glDeleteBuffers(3, g_vbos.ptr);
        g_vao = 0;
    }

    if (g_program)
    {
        glDeleteProgram(g_program);
        g_program = 0;
    }
}

void getBakedQuad(stbtt_bakedchar* chardata, int pw, int ph, int char_index,
                         float* xpos, float* ypos, stbtt_aligned_quad* q)
{
    stbtt_bakedchar* b = chardata + char_index;
    int round_x        = STBTT_ifloor(*xpos + b.xoff);
    int round_y        = STBTT_ifloor(*ypos - b.yoff);

    q.x0 = cast(float)round_x;
    q.y0 = cast(float)round_y;
    q.x1 = cast(float)round_x + b.x1 - b.x0;
    q.y1 = cast(float)round_y - b.y1 + b.y0;

    q.s0 = b.x0 / cast(float)pw;
    q.t0 = b.y0 / cast(float)pw;
    q.s1 = b.x1 / cast(float)ph;
    q.t1 = b.y1 / cast(float)ph;

    *xpos += b.xadvance;
}

float getTextLength(stbtt_bakedchar* chardata, const(char)[] text)
{
    float xpos = 0;
    float len  = 0;

    // The cast(string) is only there for UTF-8 decoding.
    foreach (dchar c; cast(string)text)
    {
        if (c == '\t')
        {
            for (int i = 0; i < 4; ++i)
            {
                if (xpos < g_tabStops[i])
                {
                    xpos = g_tabStops[i];
                    break;
                }
            }
        }
        else if (cast(int)c >= FIRST_CHARACTER && cast(int)c < FIRST_CHARACTER + g_max_character_count)
        {
            stbtt_bakedchar* b = chardata + c - FIRST_CHARACTER;
            int round_x        = STBTT_ifloor((xpos + b.xoff) + 0.5);
            len   = round_x + b.x1 - b.x0 + 0.5f;
            xpos += b.xadvance;
        }
    }

    return len;
}

float getTextLength(const(char)[] text)
{
    return getTextLength(g_cdata.ptr, text);
}

void drawText(float x, float y, const(char)[] text, int align_, uint col)
{
    if (!g_ftex)
        return;

    if (!text)
        return;

    if (align_ == TextAlign.center)
        x -= getTextLength(g_cdata.ptr, text) / 2;
    else if (align_ == TextAlign.right)
        x -= getTextLength(g_cdata.ptr, text);

    float r = cast(float)(col & 0xff) / 255.0;
    float g = cast(float)((col >> 8) & 0xff) / 255.0;
    float b = cast(float)((col >> 16) & 0xff) / 255.0;
    float a = cast(float)((col >> 24) & 0xff) / 255.0;

    // assume orthographic projection with units = screen pixels, origin at top left
    glBindTexture(GL_TEXTURE_2D, g_ftex);

    const float ox = x;

    // The cast(string) is only there for UTF-8 decoding.
    foreach (ubyte c; cast(ubyte[])text)
    {
        if (c == '\t')
        {
            for (int i = 0; i < 4; ++i)
            {
                if (x < g_tabStops[i] + ox)
                {
                    x = g_tabStops[i] + ox;
                    break;
                }
            }
        }
        else if (c >= FIRST_CHARACTER && c < FIRST_CHARACTER + g_max_character_count)
        {
            stbtt_aligned_quad q;
            getBakedQuad(g_cdata.ptr, g_font_texture_size, g_font_texture_size,
                         c - FIRST_CHARACTER, &x, &y, &q);

            float[12] v = [
                q.x0, q.y0,
                q.x1, q.y1,
                q.x1, q.y0,
                q.x0, q.y0,
                q.x0, q.y1,
                q.x1, q.y1,
            ];
            float[12] uv = [
                q.s0, q.t0,
                q.s1, q.t1,
                q.s1, q.t0,
                q.s0, q.t0,
                q.s0, q.t1,
                q.s1, q.t1,
            ];
            float[24] cArr = [
                r, g, b, a,
                r, g, b, a,
                r, g, b, a,
                r, g, b, a,
                r, g, b, a,
                r, g, b, a,
            ];
            glBindVertexArray(g_vao);
            glBindBuffer(GL_ARRAY_BUFFER, g_vbos[0]);
            glBufferData(GL_ARRAY_BUFFER, 12 * float.sizeof, v.ptr, GL_STATIC_DRAW);
            glBindBuffer(GL_ARRAY_BUFFER, g_vbos[1]);
            glBufferData(GL_ARRAY_BUFFER, 12 * float.sizeof, uv.ptr, GL_STATIC_DRAW);
            glBindBuffer(GL_ARRAY_BUFFER, g_vbos[2]);
            glBufferData(GL_ARRAY_BUFFER, 24 * float.sizeof, cArr.ptr, GL_STATIC_DRAW);
            glDrawArrays(GL_TRIANGLES, 0, 6);
        }
    }

    // glEnd();
    // glDisable(GL_TEXTURE_2D);
}

void imguiRenderGLDraw(int width, int height)
{
    const imguiGfxCmd* q = imguiGetRenderQueue();
    int nq = imguiGetRenderQueueSize();

    const float s = 1.0f / 8.0f;

    glViewport(0, 0, width, height);
    glUseProgram(g_program);
    glActiveTexture(GL_TEXTURE0);
    glUniform2f(g_programViewportLocation, cast(float)width, cast(float)height);
    glUniform1i(g_programTextureLocation, 0);

    glDisable(GL_SCISSOR_TEST);

    for (int i = 0; i < nq; ++i)
    {
        auto cmd = &q[i];

        if (cmd.type == IMGUI_GFXCMD_RECT)
        {
            if (cmd.rect.r == 0)
            {
                drawRect(cast(float)cmd.rect.x * s + 0.5f, cast(float)cmd.rect.y * s + 0.5f,
                         cast(float)cmd.rect.w * s - 1, cast(float)cmd.rect.h * s - 1,
                         1.0f, cmd.col);
            }
            else
            {
                drawRoundedRect(cast(float)cmd.rect.x * s + 0.5f, cast(float)cmd.rect.y * s + 0.5f,
                                cast(float)cmd.rect.w * s - 1, cast(float)cmd.rect.h * s - 1,
                                cast(float)cmd.rect.r * s, 1.0f, cmd.col);
            }
        }
        else if (cmd.type == IMGUI_GFXCMD_LINE)
        {
            drawLine(cmd.line.x0 * s, cmd.line.y0 * s, cmd.line.x1 * s, cmd.line.y1 * s, cmd.line.r * s, 1.0f, cmd.col);
        }
        else if (cmd.type == IMGUI_GFXCMD_TRIANGLE)
        {
            if (cmd.flags == 1)
            {
                const float[3 * 2] verts =
                [
                    cast(float)cmd.rect.x * s + 0.5f, cast(float)cmd.rect.y * s + 0.5f,
                    cast(float)cmd.rect.x * s + 0.5f + cast(float)cmd.rect.w * s - 1, cast(float)cmd.rect.y * s + 0.5f + cast(float)cmd.rect.h * s / 2 - 0.5f,
                    cast(float)cmd.rect.x * s + 0.5f, cast(float)cmd.rect.y * s + 0.5f + cast(float)cmd.rect.h * s - 1,
                ];
                drawPolygon(verts.ptr, 3, 1.0f, cmd.col);
            }

            if (cmd.flags == 2)
            {
                const float[3 * 2] verts =
                [
                    cast(float)cmd.rect.x * s + 0.5f, cast(float)cmd.rect.y * s + 0.5f + cast(float)cmd.rect.h * s - 1,
                    cast(float)cmd.rect.x * s + 0.5f + cast(float)cmd.rect.w * s / 2 - 0.5f, cast(float)cmd.rect.y * s + 0.5f,
                    cast(float)cmd.rect.x * s + 0.5f + cast(float)cmd.rect.w * s - 1, cast(float)cmd.rect.y * s + 0.5f + cast(float)cmd.rect.h * s - 1,
                ];
                drawPolygon(verts.ptr, 3, 1.0f, cmd.col);
            }
        }
        else if (cmd.type == IMGUI_GFXCMD_TEXT)
        {
            drawText(cmd.text.x, cmd.text.y, cmd.text.text, cmd.text.align_, cmd.col);
        }
        else if (cmd.type == IMGUI_GFXCMD_SCISSOR)
        {
            if (cmd.flags)
            {
                glEnable(GL_SCISSOR_TEST);
                glScissor(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h);
            }
            else
            {
                glDisable(GL_SCISSOR_TEST);
            }
        }
    }

    glDisable(GL_SCISSOR_TEST);
}
