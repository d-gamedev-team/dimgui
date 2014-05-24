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

/**
    imgui is an immediate mode GUI. See also:
    http://sol.gfxile.net/imgui/

    This module contains the API of the library.
*/

import std.math;
import std.stdio;
import std.string;

import imgui.engine;
import imgui.gl3_renderer;

// todo: opApply to allow changing brightness on all colors.
// todo: check CairoD samples for brightness settingsroutines.

/** A color scheme contains all the configurable GUI element colors. */
struct ColorScheme
{
    static struct Generic
    {
        RGBA text;       /// Used by imguiDrawText.
        RGBA line;       /// Used by imguiDrawLine.
        RGBA rect;       /// Used by imguiDrawRect.
        RGBA roundRect;  /// Used by imguiDrawRoundedRect.
    }

    static struct Button
    {
        RGBA text         = RGBA(255, 255, 255, 200);
        RGBA textHover    = RGBA(255, 196,   0, 255);
        RGBA textDisabled = RGBA(128, 128, 128, 200);
        RGBA back         = RGBA(128, 128, 128,  96);
        RGBA backPress    = RGBA(128, 128, 128, 196);
    }

    static struct Scroll
    {
        static struct Area
        {
            RGBA back = RGBA(0, 0, 0, 192);
            RGBA text = RGBA(255, 255, 255, 128);
        }

        static struct Bar
        {
            RGBA back = RGBA(0, 0, 0, 196);
            RGBA thumb = RGBA(255, 255, 255, 64);
            RGBA thumbHover = RGBA(255, 196, 0, 96);
            RGBA thumbPress = RGBA(255, 196, 0, 196);
        }

        Area area;
        Bar bar;
    }

    static struct Checkbox
    {
        //~ RGBA text         = RGBA(255, 255, 255, 200);
        //~ RGBA textHover    = RGBA(255, 196,   0, 255);
        //~ RGBA textDisabled = RGBA(128, 128, 128, 200);
        //~ RGBA back         = RGBA(128, 128, 128, 96);
        //~ RGBA backPress    = RGBA(128, 128, 128, 196);
    }

    /// Colors for the generic imguiDraw* functions.
    Generic generic;

    /// Colors for the scrollable area.
    Scroll scroll;

    /// Colors for button elements.
    Button button;

    /// Colors for checkbox elements.
    Checkbox checkbox;
}

/**
    The current default color scheme.

    You can configure this scheme to your own liking,
    which will be used by GUI element creation functions,
    unless you explicitly pass a color scheme of your own.
*/
__gshared ColorScheme defaultColorScheme;

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

/** The possible mouse buttons. These can be used as bitflags. */
enum MouseButton : ubyte
{
    left  = 0x01,
    right = 0x02,
}

///
enum Enabled : bool
{
    no,
    yes,
}

/** Initialize the imgui library. */
bool imguiInit(const(char)[] fontPath)
{
    return imguiRenderGLInit(fontPath);
}

/** Destroy the imgui library. */
void imguiDestroy()
{
    imguiRenderGLDestroy();
}

/**
    Begin a new frame. All batched commands after the call to
    $(D imguiBeginFrame) will be rendered as a single frame once
    $(D imguiRender) is called.

    Note: You should call $(D imguiEndFrame) after batching all
    commands to reset the input handling for the next frame.

    Example:
    -----
    int cursorX, cursorY;
    ubyte mouseButtons;
    int mouseScroll;

    /// start a new batch of commands for this frame (the batched commands)
    imguiBeginFrame(cursorX, cursorY, mouseButtons, mouseScroll);

    /// define your UI elements here
    imguiLabel("some text here");

    /// end the frame (this just resets the input control state, e.g. mouse button states)
    imguiEndFrame();

    /// now render the batched commands
    imguiRender();
    -----

    Params:

    cursorX = The cursor's last X position.
    cursorY = The cursor's last Y position.
    mouseButtons = The last mouse buttons pressed (a value or a combination of values of a $(D MouseButton)).
    mouseScroll = The last scroll value emitted by the mouse.
*/
void imguiBeginFrame(int cursorX, int cursorY, ubyte mouseButtons, int mouseScroll)
{
    updateInput(cursorX, cursorY, mouseButtons, mouseScroll);

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

/** End the list of batched commands for the current frame. */
void imguiEndFrame()
{
    clearInput();
}

/** Render all of the batched commands for the current frame. */
void imguiRender(int width, int height)
{
    imguiRenderGLDraw(width, height);
}

/**
    Begin the definition of a new scrollable area.

    Once elements within the scrollable area are defined
    you must call $(D imguiEndScrollArea) to end the definition.

    Params:

    title = The title that will be displayed for this scroll area.
    xPos = The X position of the scroll area.
    yPos = The Y position of the scroll area.
    width = The width of the scroll area.
    height = The height of the scroll area.
    scroll = A pointer to a variable which will hold the current scroll value of the widget.

    Returns:

    $(D true) if the mouse was located inside the scrollable area.
*/
bool imguiBeginScrollArea(const(char)[] title, int xPos, int yPos, int width, int height, int* scroll, const ref ColorScheme colorScheme = defaultColorScheme)
{
    g_state.areaId++;
    g_state.widgetId = 0;
    g_scrollId       = (g_state.areaId << 16) | g_state.widgetId;

    g_state.widgetX = xPos + SCROLL_AREA_PADDING;
    g_state.widgetY = yPos + height - AREA_HEADER + (*scroll);
    g_state.widgetW = width - SCROLL_AREA_PADDING * 4;
    g_scrollTop     = yPos - AREA_HEADER + height;
    g_scrollBottom  = yPos + SCROLL_AREA_PADDING;
    g_scrollRight   = xPos + width - SCROLL_AREA_PADDING * 3;
    g_scrollVal     = scroll;

    g_scrollAreaTop = g_state.widgetY;

    g_focusTop    = yPos - AREA_HEADER;
    g_focusBottom = yPos - AREA_HEADER + height;

    g_insideScrollArea = inRect(xPos, yPos, width, height, false);
    g_state.insideCurrentScroll = g_insideScrollArea;

    addGfxCmdRoundedRect(cast(float)xPos, cast(float)yPos, cast(float)width, cast(float)height, 6, colorScheme.scroll.area.back);

    addGfxCmdText(xPos + AREA_HEADER / 2, yPos + height - AREA_HEADER / 2 - TEXT_HEIGHT / 2, TextAlign.left, title, colorScheme.scroll.area.text);

    addGfxCmdScissor(xPos + SCROLL_AREA_PADDING, yPos + SCROLL_AREA_PADDING, width - SCROLL_AREA_PADDING * 4, height - AREA_HEADER - SCROLL_AREA_PADDING);

    return g_insideScrollArea;
}

/** End the definition of the last scrollable element. */
void imguiEndScrollArea(const ref ColorScheme colorScheme = defaultColorScheme)
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
        addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, cast(float)w / 2 - 1, colorScheme.scroll.bar.back);

        // Bar
        if (isActive(hid))
            addGfxCmdRoundedRect(cast(float)hx, cast(float)hy, cast(float)hw, cast(float)hh, cast(float)w / 2 - 1, colorScheme.scroll.bar.thumbPress);
        else
            addGfxCmdRoundedRect(cast(float)hx, cast(float)hy, cast(float)hw, cast(float)hh, cast(float)w / 2 - 1, isHot(hid) ? colorScheme.scroll.bar.thumbHover : colorScheme.scroll.bar.thumb);

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

/**
    Define a new button.

    Params:

    label = The text that will be displayed on the button.
    enabled = Set whether the button can be pressed.
    colorScheme = The color scheme to use for drawing the button elements.

    Returns:

    $(D true) if the button is enabled and was pressed.
    Note that pressing a button implies pressing and releasing the
    left mouse button while over the gui button.

    Example:
    -----
    void onPress() { }
    if (imguiButton("Push me"))  // button was pushed
        onPress();
    -----
*/
bool imguiButton(const(char)[] label, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
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

    addGfxCmdRoundedRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, cast(float)BUTTON_HEIGHT / 2 - 1,
                         isActive(id) ? colorScheme.button.backPress : colorScheme.button.back);

    if (enabled)
    {
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label,
                      isHot(id) ? colorScheme.button.textHover : colorScheme.button.text);
    }
    else
    {
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label,
                      colorScheme.button.textDisabled);
    }

    return res;
}

/**
    Define a new checkbox.

    Params:

    label = The text that will be displayed on the button.
    checkState = A pointer to a variable which holds the current state of the checkbox.
    enabled = Set whether the checkbox can be pressed.

    Returns:

    $(D true) if the checkbox was toggled on or off.
    Note that toggling implies pressing and releasing the
    left mouse button while over the checkbox.

    Example:
    -----
    bool checkState = false;  // initially un-checked
    if (imguiCheck("checkbox", &checkState))  // checkbox was toggled
        writeln(checkState);  // check the current state
    -----
*/
bool imguiCheck(const(char)[] label, bool* checkState, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
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

    if (res)  // toggle the state
        *checkState ^= 1;

    const int cx = x + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;
    const int cy = y + BUTTON_HEIGHT / 2 - CHECK_SIZE / 2;
    addGfxCmdRoundedRect(cast(float)cx - 3, cast(float)cy - 3, cast(float)CHECK_SIZE + 6, cast(float)CHECK_SIZE + 6, 4, RGBA(128, 128, 128, isActive(id) ? 196 : 96));

    if (*checkState)
    {
        if (enabled)
            addGfxCmdRoundedRect(cast(float)cx, cast(float)cy, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE / 2 - 1, RGBA(255, 255, 255, isActive(id) ? 255 : 200));
        else
            addGfxCmdRoundedRect(cast(float)cx, cast(float)cy, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE, cast(float)CHECK_SIZE / 2 - 1, RGBA(128, 128, 128, 200));
    }

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
    else
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, RGBA(128, 128, 128, 200));

    return res;
}

/**
    Define a new item.

    Params:

    label = The text that will be displayed as the item.
    enabled = Set whether the item can be pressed.

    Returns:

    $(D true) if the item is enabled and was pressed.
    Note that pressing an item implies pressing and releasing the
    left mouse button while over the item.
*/
bool imguiItem(const(char)[] label, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
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
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, RGBA(255, 255, 255, 200));
    else
        addGfxCmdText(x + BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, RGBA(128, 128, 128, 200));

    return res;
}

/**
    Define a new collapsable element.

    Params:

    label = The text that will be displayed as the item.
    subtext = Additional text displayed on the right of the label.
    checkState = A pointer to a variable which holds the current state of the collapsable element.
    enabled = Set whether the element can be pressed.

    Returns:

    $(D true) if the collapsable element is enabled and was pressed.
    Note that pressing a collapsable element implies pressing and releasing the
    left mouse button while over the collapsable element.
*/
bool imguiCollapse(const(char)[] label, const(char)[] subtext, bool* checkState, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
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

    if (res)  // toggle the state
        *checkState ^= 1;

    if (*checkState)
        addGfxCmdTriangle(cx, cy, CHECK_SIZE, CHECK_SIZE, 2, RGBA(255, 255, 255, isActive(id) ? 255 : 200));
    else
        addGfxCmdTriangle(cx, cy, CHECK_SIZE, CHECK_SIZE, 1, RGBA(255, 255, 255, isActive(id) ? 255 : 200));

    if (enabled)
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
    else
        addGfxCmdText(x + BUTTON_HEIGHT, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, RGBA(128, 128, 128, 200));

    if (subtext)
        addGfxCmdText(x + w - BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, subtext, RGBA(255, 255, 255, 128));

    return res;
}

/**
    Define a new label.

    Params:

    label = The text that will be displayed as the label.
*/
void imguiLabel(const(char)[] label, const ref ColorScheme colorScheme = defaultColorScheme)
{
    int x = g_state.widgetX;
    int y = g_state.widgetY - BUTTON_HEIGHT;
    g_state.widgetY -= BUTTON_HEIGHT;
    addGfxCmdText(x, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, RGBA(255, 255, 255, 255));
}


/**
    Define a new value.

    Params:

    label = The text that will be displayed as the value.
*/
void imguiValue(const(char)[] label, const ref ColorScheme colorScheme = defaultColorScheme)
{
    const int x = g_state.widgetX;
    const int y = g_state.widgetY - BUTTON_HEIGHT;
    const int w = g_state.widgetW;
    g_state.widgetY -= BUTTON_HEIGHT;

    addGfxCmdText(x + w - BUTTON_HEIGHT / 2, y + BUTTON_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, label, RGBA(255, 255, 255, 200));
}

/**
    Define a new slider.

    Params:

    label = The text that will be displayed above the slider.
    sliderState = A pointer to a variable which holds the current slider value.
    minValue = The minimum value that the slider can hold.
    maxValue = The maximum value that the slider can hold.
    stepValue = The step at which the value of the slider will increase or decrease.
    enabled = Set whether the slider's value can can be changed with the mouse.

    Returns:

    $(D true) if the slider is enabled and was pressed.
    Note that pressing a slider implies pressing and releasing the
    left mouse button while over the slider.
*/
bool imguiSlider(const(char)[] label, float* sliderState, float minValue, float maxValue, float stepValue, Enabled enabled = Enabled.yes, const ref ColorScheme colorScheme = defaultColorScheme)
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

    float u = (*sliderState - minValue) / (maxValue - minValue);

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
            *sliderState = minValue + u * (maxValue - minValue);
            *sliderState = floor(*sliderState / stepValue + 0.5f) * stepValue; // Snap to stepValue
            m          = cast(int)(u * range);
            valChanged = true;
        }
    }

    if (isActive(id))
        addGfxCmdRoundedRect(cast(float)(x + m), cast(float)y, cast(float)SLIDER_MARKER_WIDTH, cast(float)SLIDER_HEIGHT, 4.0f, RGBA(255, 255, 255, 255));
    else
        addGfxCmdRoundedRect(cast(float)(x + m), cast(float)y, cast(float)SLIDER_MARKER_WIDTH, cast(float)SLIDER_HEIGHT, 4.0f, isHot(id) ? RGBA(255, 196, 0, 128) : RGBA(255, 255, 255, 64));

    // TODO: fix this, take a look at 'nicenum'.
    int digits = cast(int)(ceil(log10(stepValue)));
    char[16] fmt;
    sformat(fmt, "%%.%df", digits >= 0 ? 0 : -digits);
    char[32] msgBuf;
    string msg = sformat(msgBuf, fmt, *sliderState).idup;

    if (enabled)
    {
        addGfxCmdText(x + SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
        addGfxCmdText(x + w - SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, msg, isHot(id) ? RGBA(255, 196, 0, 255) : RGBA(255, 255, 255, 200));
    }
    else
    {
        addGfxCmdText(x + SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.left, label, RGBA(128, 128, 128, 200));
        addGfxCmdText(x + w - SLIDER_HEIGHT / 2, y + SLIDER_HEIGHT / 2 - TEXT_HEIGHT / 2, TextAlign.right, msg, RGBA(128, 128, 128, 200));
    }

    return res || valChanged;
}

/** Add horizontal indentation for elements to be added. */
void imguiIndent()
{
    g_state.widgetX += INDENT_SIZE;
    g_state.widgetW -= INDENT_SIZE;
}

/** Remove horizontal indentation for elements to be added. */
void imguiUnindent()
{
    g_state.widgetX -= INDENT_SIZE;
    g_state.widgetW += INDENT_SIZE;
}

/** Add vertical space as a separator below the last element. */
void imguiSeparator()
{
    g_state.widgetY -= DEFAULT_SPACING * 3;
}

/** Add a horizontal line as a separator below the last element. */
void imguiSeparatorLine(const ref ColorScheme colorScheme = defaultColorScheme)
{
    int x = g_state.widgetX;
    int y = g_state.widgetY - DEFAULT_SPACING * 2;
    int w = g_state.widgetW;
    int h = 1;
    g_state.widgetY -= DEFAULT_SPACING * 4;

    addGfxCmdRect(cast(float)x, cast(float)y, cast(float)w, cast(float)h, RGBA(255, 255, 255, 32));
}

/** Draw text. */
void imguiDrawText(int xPos, int yPos, TextAlign textAlign, const(char)[] text, RGBA color = defaultColorScheme.generic.text)
{
    addGfxCmdText(xPos, yPos, textAlign, text, color);
}

/** Draw a line. */
void imguiDrawLine(float x0, float y0, float x1, float y1, float r, RGBA color = defaultColorScheme.generic.line)
{
    addGfxCmdLine(x0, y0, x1, y1, r, color);
}

/** Draw a rectangle. */
void imguiDrawRect(float xPos, float yPos, float width, float height, RGBA color = defaultColorScheme.generic.rect)
{
    addGfxCmdRect(xPos, yPos, width, height, color);
}

/** Draw a rounded rectangle. */
void imguiDrawRoundedRect(float xPos, float yPos, float width, float height, float r, RGBA color = defaultColorScheme.generic.roundRect)
{
    addGfxCmdRoundedRect(xPos, yPos, width, height, r, color);
}
