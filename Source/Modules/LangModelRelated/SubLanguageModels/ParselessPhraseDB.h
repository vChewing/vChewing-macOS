// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#ifndef SOURCE_ENGINE_PARSELESSPHRASEDB_H_
#define SOURCE_ENGINE_PARSELESSPHRASEDB_H_

#include <cstddef>
#include <string>
#include <vector>

namespace vChewing {

// Defines phrase database that consists of (key, value, score) rows that are
// pre-sorted by the byte value of the keys. It is way faster than FastLM
// because it does not need to parse anything. Instead, it relies on the fact
// that the database is already sorted, and binary search is used to find the
// rows.
class ParselessPhraseDB {
public:
    ParselessPhraseDB(
        const char* buf, size_t length);

    // Find the rows that match the key. Note that prefix match is used. If you
    // need exact match, the key will need to have a delimiter (usually a space)
    // at the end.
    std::vector<std::string_view> findRows(const std::string_view& key);

    const char* findFirstMatchingLine(const std::string_view& key);

private:
    const char* begin_;
    const char* end_;
};

}; // namespace vChewing

#endif // SOURCE_ENGINE_PARSELESSPHRASEDB_H_
