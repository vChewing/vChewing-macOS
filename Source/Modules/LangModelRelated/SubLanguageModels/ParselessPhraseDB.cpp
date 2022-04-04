// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "ParselessPhraseDB.h"

#include <cassert>
#include <cstring>

namespace vChewing
{

ParselessPhraseDB::ParselessPhraseDB(const char *buf, size_t length) : begin_(buf), end_(buf + length)
{
}

std::vector<std::string_view> ParselessPhraseDB::findRows(const std::string_view &key)
{
    std::vector<std::string_view> rows;

    const char *ptr = findFirstMatchingLine(key);
    if (ptr == nullptr)
    {
        return rows;
    }

    while (ptr + key.length() <= end_ && memcmp(ptr, key.data(), key.length()) == 0)
    {
        const char *eol = ptr;

        while (eol != end_ && *eol != '\n')
        {
            ++eol;
        }

        rows.emplace_back(ptr, eol - ptr);
        if (eol == end_)
        {
            break;
        }

        ptr = ++eol;
    }

    return rows;
}

// Implements a binary search that returns the pointer to the first matching
// row. In its core it's just a standard binary search, but we use backtracking
// to locate the line start. We also check the previous line to see if the
// current line is actually the first matching line: if the previous line is
// less to the key and the current line starts exactly with the key, then
// the current line is the first matching line.
const char *ParselessPhraseDB::findFirstMatchingLine(const std::string_view &key)
{
    if (key.empty())
    {
        return begin_;
    }

    const char *top = begin_;
    const char *bottom = end_;

    while (top < bottom)
    {
        const char *mid = top + (bottom - top) / 2;
        const char *ptr = mid;

        if (ptr != begin_)
        {
            --ptr;
        }

        while (ptr != begin_ && *ptr != '\n')
        {
            --ptr;
        }

        const char *prev = nullptr;
        if (*ptr == '\n')
        {
            prev = ptr;
            ++ptr;
        }

        // ptr is now in the "current" line we're interested in.
        if (ptr + key.length() > end_)
        {
            // not enough data to compare at this point, bail.
            break;
        }

        int current_cmp = memcmp(ptr, key.data(), key.length());

        if (current_cmp > 0)
        {
            bottom = mid - 1;
            continue;
        }

        if (current_cmp < 0)
        {
            top = mid + 1;
            continue;
        }

        if (!prev)
        {
            return ptr;
        }

        // Move the prev so that it reaches the previous line.
        if (prev != begin_)
        {
            --prev;
        }
        while (prev != begin_ && *prev != '\n')
        {
            --prev;
        }
        if (*prev == '\n')
        {
            ++prev;
        }

        int prev_cmp = memcmp(prev, key.data(), key.length());

        // This is the first occurrence.
        if (prev_cmp < 0 && current_cmp == 0)
        {
            return ptr;
        }

        // This is not, which means ptr is "larger" than the keyData.
        bottom = mid - 1;
    }

    return nullptr;
}

}; // namespace vChewing
