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

#ifndef BIGRAM_H_
#define BIGRAM_H_

#include <vector>

#include "KeyValuePair.h"

namespace Gramambular {
class Bigram {
public:
    Bigram();
    
    KeyValuePair preceedingKeyValue;
    KeyValuePair keyValue;
    double score;
    
    bool operator==(const Bigram& another) const;
    bool operator<(const Bigram& another) const;
};

inline std::ostream& operator<<(std::ostream& stream, const Bigram& gram) {
    std::streamsize p = stream.precision();
    stream.precision(6);
    stream << "(" << gram.keyValue << "|" << gram.preceedingKeyValue << ","
    << gram.score << ")";
    stream.precision(p);
    return stream;
}

inline std::ostream& operator<<(std::ostream& stream,
                                const std::vector<Bigram>& grams) {
    stream << "[" << grams.size() << "]=>{";
    
    size_t index = 0;
    
    for (std::vector<Bigram>::const_iterator gi = grams.begin();
         gi != grams.end(); ++gi, ++index) {
        stream << index << "=>";
        stream << *gi;
        if (gi + 1 != grams.end()) {
            stream << ",";
        }
    }
    
    stream << "}";
    return stream;
}

inline Bigram::Bigram() : score(0.0) {}

inline bool Bigram::operator==(const Bigram& another) const {
    return preceedingKeyValue == another.preceedingKeyValue &&
    keyValue == another.keyValue && score == another.score;
}

inline bool Bigram::operator<(const Bigram& another) const {
    if (preceedingKeyValue < another.preceedingKeyValue) {
        return true;
    } else if (preceedingKeyValue == another.preceedingKeyValue) {
        if (keyValue < another.keyValue) {
            return true;
        } else if (keyValue == another.keyValue) {
            return score < another.score;
        }
        return false;
    }
    
    return false;
}
}  // namespace Gramambular


#endif
