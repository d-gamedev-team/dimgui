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
module imgui.api;

import std.math;
import std.stdio;
import std.string;

import imgui.engine;
import imgui.gl3_renderer;

///
struct RGBA
{
    ubyte r;
    ubyte g;
    ubyte b;
    ubyte a = 255;
}

///
enum TextAlign
{
    left,
    center,
    right,
}

///
enum MouseButton
{
    left  = 0x01,
    right = 0x02,
}

/** Initialize the imgui library. */
bool imguiInit(string fontPath)
{
    return imguiRenderGLInit(fontPath);
}

/** Destroy the imgui library. */
void imguiDestroy()
{
    imguiRenderGLDestroy();
}

/** Render the batched commands. */
void imguiRender(int width, int height)
{
    imguiRenderGLDraw(width, height);
}

///
void imguiBeginFrame(int mx, int my, ubyte mbut, int scroll)
{
    updateInput(mx, my, mbut, scroll);

    g_state.hot     = g_state.hotToBe;
    g_state.hotToBe = 0;

    g_state.wentActive = false;
    g_state.isActive   = false;
    g_state.isHot      = false;

    g_state.widgetX = 0;
    g_state.widgetY = 0;
    g_state.widgetW = 0;

    g_state.areaId   = 1;
    g_state.widgetId = 1;

    resetGfxCmdQueue();
}

///
void imguiEndFrame()
{
    clearInput();
}

///
bool imguiBeginScrollArea(string name, int x, int y, int w, int h, int* scroll)
{
    g_state.areaId++;
    g_state.widgetId = 0;
    g_scrollId       = (g_state.areaId << 16) | g_state.widgetId;

    g_state.widgetX = x + SCROLL_AREA_PADDING;
    g_state.widgetY = y + h - AREA_HEADER + (*scroll);
    g_state.widgetW = w - SCROLL_AREA_PADDING * 4;
    g_scrollTop     = y - AREA_HEADER + h;
    g_scrollBottom  = y + SCROLL_AREA_PADDING;
    g_scrollRight   = x + w - SCROLL_AREA_PADDING * 3;
    g_scrollVal     = scroll;

    g_scrollAreaTop = g_state.widgetY;

    g_focusTop    = y - AREA_HEADER;
    g_focusBottom = y - AREA_HEADER + h;

    g_insideScrollArea = inRect(x, y, w, h, false);
    g_state.insideCurrentScroll = g_insideScrollArea;

    addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 6, RGBA(0, 0, 0, 192));

    addGfxCmdText(x + AREA_HEADER / 2, y + h - AREA_HEADER / 2 - TEXT_HEIGHT / 2, TextAlign.left, name, RGBA(255, 255, 255, 128));

    addGfxCmdScissor(x + SCROLL_AREA_PADDING, y + SCROLL_AREA_PADDING, w - SCROLL_AREA_PADDING * 4, h - AREA_HEADER - SCROLL_AREA_PADDING);

    return g_insideScrollArea;
}

///
void imguiEndScrollArea()
{
    // Disable scissoring.
    addGfxCmdScissor(-1, -1, -1, -1);

    // Draw scroll bar
    int x = g_scrollRight + SCROLL_AREA_PADDING / 2;
    int y = g_scrollBottom;
    int w = SCROLL_AREA_PADDING * 2;
    int h = g_scrollTop - g_scrollBottom;

    int stop = g_scrollAreaTop;
    int sbot = g_state.widgetY;
    int sh   = stop - sbot;   // The scrollable area height.

    float barHeight = cast(float)h / cast(float)sh;

    if (barHeight < 1)
    {
        float barY = cast(float)(y - sbot) / cast(float)sh;

        if (barY < 0)
            barY = 0;

        if (barY > 1)
            barY = 1;

        // Handle scroll bar logic.
        uint hid = g_scrollId;
        int hx = x;
        int hy = y + cast(int)(barY * h);
        int hw = w;
        int hh = cast(int)(barHeight * h);

        const int range = h - (hh - 1);
        bool over       = inRect(hx, hy, hw, hh);
        buttonLogic(hid, over);

        if (isActive(hid))
        {
            float u = cast(float)(hy - y) / cast(float)range;

            if (g_state.wentActive)
            {
                g_state.dragY    = g_state.my;
                g_state.dragOrig = u;
            }

            if (g_state.dragY != g_state.my)
            {
                u = g_state.dragOrig + (g_state.my - g_state.dragY) / cast(float)range;

                if (u < 0)
                    u = 0;

                if (u > 1)
                    u = 1;
                *g_scrollVal = cast(int)((1 - u) * (sh - h));
            }
        }

        // BG
        addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, cast(float)w / 2 - 1, RGBA(0, 0, 0, 196));

        // Bar
        if (isActive(hid))
            addGfxCmdRoundedRect(cast(float)hx, cast(float)hy, cast(float)hw, cast(float)hh, cast(float)w / 2 - 1, RGBA(255, 196, 0, 196));
        else
            addGfxCmdRoundedRect(cast(float)hx, cast(float)hy, cast(float)hw, cast(float)hh, cast(float)w / 2 - 1, isHot(hid) ? RGBA(255, 196, 0, 96) : RGBA(255, 255, 255, 64));

        // Handle mouse scrolling.
        if (g_insideScrollArea)         // && !anyActive())
        {
            if (g_state.scroll)
            {
                *g_scrollVal += 20 * g_state.scroll;

                if (*g_scrollVal < 0)
                    *g_scrollVal = 0;

                if (*g_scrollVal > (sh - h))
                    *g_scrollVal = (sh - h);
            }
        }
    }
    g_state.insideCurrentScroll = false;
}

///
bool imguiButton(string text, bool enabled = true)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, cast(float)BUTTON_HEIGHT / 2 - 1, RGBA(128, 128, 128, isActive(id) ? 196 : 96));

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
    else
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, RGBA(128, 128, 128, 200));

    return res;
}

///
bool imguiItem(string text, bool enabled = true)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    if (isHot(id))
        addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 2.0f, RGBA(255, 196, 0, isActive(id) ? 196 : 96));

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, RGBA(255, 255, 255, 200));
    else
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, RGBA(128, 128, 128, 200));

    return res;
}

///
bool imguiCheck(string text, bool checked, bool enabled = true)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT + DEFAULT_SPACING;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    const int cx = x + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;
    const int cy = y + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;
    addGfxCmdRoundedRect(cast(float)cx - 3, cast(float)cy - 3, cast(float)CHECK_SIZE + 6, cast(float)CHECK_SIZE + 6, 4, RGBA(128, 128, 128, isActive(id) ? 196 : 96));

    if (checked)
    {
        if (enabled)
            addGfxCmdRoundedRect(cast(float)cx, cast(float)cy, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE / 2 - 1, RGBA(255, 255, 255, isActive(id) ? 255 : 200));
        else
            addGfxCmdRoundedRect(cast(float)cx, cast(float)cy, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE / 2 - 1, RGBA(128, 128, 128, 200));
    }

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
    else
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, RGBA(128, 128, 128, 200));

    return res;
}

///
bool imguiCollapse(string text, string subtext, bool checked, bool enabled = true)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT;     // + DEFAULT_SPACING;

    const int cx = x + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;
    const int cy = y + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;

    bool over = enabled && inRect(x, y, w, h);
    bool res  = buttonLogic(id, over);

    if (checked)
        addGfxCmdTriangle(cx, cy, CHECK_SIZE, CHECK_SIZE, 2, RGBA(255, 255, 255, isActive(id) ? 255 : 200));
    else
        addGfxCmdTriangle(cx, cy, CHECK_SIZE, CHECK_SIZE, 1, RGBA(255, 255, 255, isActive(id) ? 255 : 200));

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
    else
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, RGBA(128, 128, 128, 200));

    if (subtext)
        addGfxCmdText(x + w - BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, subtext, RGBA(255, 255, 255, 128));

    return res;
}

///
void imguiLabel(string text)
{
    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT;
    addGfxCmdText(x, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, RGBA(255, 255, 255, 255));
}

///
void imguiValue(string text)
{
    const int x = g_state.widgetX;
    const int y = g_state.widgetY - BUTTON_HEIGHT;
    const int w = g_state.widgetW;
    g_state.widgetY -= BUTTON_HEIGHT;

    addGfxCmdText(x + w - BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, text, RGBA(255, 255, 255, 200));
}

///
bool imguiSlider(string text, float* val, float vmin, float vmax, float vinc, bool enabled = true)
{
    g_state.widgetId++;
    uint id = (g_state.areaId << 16) | g_state.widgetId;

    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    int w = g_state.widgetW;
    int h = SLIDER_HEIGHT;
    g_state.widgetY -= SLIDER_HEIGHT + DEFAULT_SPACING;

    addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, 4.0f, RGBA(0, 0, 0, 128));

    const int range = w - SLIDER_MARKER_WIDTH;

    float u = (*val - vmin) / (vmax - vmin);

    if (u < 0)
        u = 0;

    if (u > 1)
        u = 1;
    int m = cast(int)(u * range);

    bool over       = enabled && inRect(x + m, y, SLIDER_MARKER_WIDTH, SLIDER_HEIGHT);
    bool res        = buttonLogic(id, over);
    bool valChanged = false;

    if (isActive(id))
    {
        if (g_state.wentActive)
        {
            g_state.dragX    = g_state.mx;
            g_state.dragOrig = u;
        }

        if (g_state.dragX != g_state.mx)
        {
            u = g_state.dragOrig + cast(float)(g_state.mx - g_state.dragX) / cast(float)range;

            if (u < 0)
                u = 0;

            if (u > 1)
                u = 1;
            *val       = vmin + u * (vmax - vmin);
            *val       = floor(*val / vinc + 0.5f) * vinc; // Snap to vinc
            m          = cast(int)(u * range);
            valChanged = true;
        }
    }

    if (isActive(id))
        addGfxCmdRoundedRect(cast(float)(x + m), cast(float)y, cast(float)SLIDER_MARKER_WIDTH, cast(float)SLIDER_HEIGHT, 4.0f, RGBA(255, 255, 255, 255));
    else
        addGfxCmdRoundedRect(cast(float)(x + m), cast(float)y, cast(float)SLIDER_MARKER_WIDTH, cast(float)SLIDER_HEIGHT, 4.0f, isHot(id) ? RGBA(255, 196, 0, 128) : RGBA(255, 255, 255, 64));

    // TODO: fix this, take a look at 'nicenum'.
    int digits = cast(int)(ceil(log10(vinc)));
    char[16] fmt;
    sformat(fmt, "%%.%df", digits >= 0 ? 0 : -digits);
    char[128] msgBuf;
    sformat(msgBuf, fmt, *val);

    string msg = msgBuf.idup;

    if (enabled)
    {
        addGfxCmdText(x + SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
        addGfxCmdText(x + w - SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, msg, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
    }
    else
    {
        addGfxCmdText(x + SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, text, RGBA(128, 128, 128, 200));
        addGfxCmdText(x + w - SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, msg, RGBA(128, 128, 128, 200));
    }

    return res || valChanged;
}

///
void imguiIndent()
{
    g_state.widgetX += INDENT_SIZE;
    g_state.widgetW -= INDENT_SIZE;
}

///
void imguiUnindent()
{
    g_state.widgetX -= INDENT_SIZE;
    g_state.widgetW += INDENT_SIZE;
}

///
void imguiSeparator()
{
    g_state.widgetY -= DEFAULT_SPACING * 3;
}

///
void imguiSeparatorLine()
{
    int x = g_state.widgetX;
    int y = g_state.widgetY - DEFAULT_SPACING * 2;
    int w = g_state.widgetW;
    int h = 1;
    g_state.widgetY -= DEFAULT_SPACING * 4;

    addGfxCmdRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, RGBA(255, 255, 255, 32));
}

///
void imguiDrawText(int x, int y, int align_, string text, RGBA color)
{
    addGfxCmdText(x, y, align_, text, color);
}

///
void imguiDrawLine(float x0, float y0, float x1, float y1, float r, RGBA color)
{
    addGfxCmdLine(x0, y0, x1, y1, r, color);
}

///
void imguiDrawRect(float x, float y, float w, float h, RGBA color)
{
    addGfxCmdRect(x, y, w, h, color);
}

///
void imguiDrawRoundedRect(float x, float y, float w, float h, float r, RGBA color)
{
    addGfxCmdRoundedRect(x, y, w, h, r, color);
}
