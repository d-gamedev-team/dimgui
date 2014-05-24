/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module imgui.util;

/**
    Note: This unfortunately doesn't work with more complex structures
    due to a DMD bug with an infinite loop problem. This isn't reported yet.
*/

import std.range;
import std.stdio;

auto ref fieldRange(S, T)(auto ref T sym)
{
    static if (is(T == struct) && !is(T == S))
        return fieldRange!S(sym.tupleof);
    else
        return only(sym);
}

auto ref fieldRange(S, T...)(auto ref T syms) if (T.length > 1)
{
    return chain(fieldRange!S(syms[0]),
                 fieldRange!S(syms[1 .. $]));
}

auto addrFieldRange(S, T)(ref T sym)
{
    static if (is(T == struct) && !is(T == S))
        return addrFieldRange!S(sym.tupleof);
    else
        return only(&sym);
}

auto addrFieldRange(S, T...)(ref T syms) if (T.length > 1)
{
    return chain(addrFieldRange!S(syms[0]),
                 addrFieldRange!S(syms[1 .. $]));
}

auto refFieldRange(S, T)(ref T sym)
{
    alias Type = typeof(sym.fieldRange!S.front);

    static ref Type getRef(Type* elem) { return *elem; }

    return sym.addrFieldRange!S.map!getRef;
}
