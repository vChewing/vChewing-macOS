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

#ifndef USEROVERRIDEMODEL_H
#define USEROVERRIDEMODEL_H

#include <list>
#include <map>
#include <string>

#include "Gramambular.h"

namespace vChewing {

using namespace Taiyan::Gramambular;

class UserOverrideModel {
public:
    UserOverrideModel(size_t capacity, double decayConstant);

    void observe(const std::vector<NodeAnchor>& walkedNodes,
                 size_t cursorIndex,
                 const string& candidate,
                 double timestamp);

    string suggest(const std::vector<NodeAnchor>& walkedNodes,
                   size_t cursorIndex,
                   double timestamp);

private:
    struct Override {
        size_t count;
        double timestamp;

        Override() : count(0), timestamp(0.0) {}
    };

    struct Observation {
        size_t count;
        std::map<std::string, Override> overrides;

        Observation() : count(0) {}
        void update(const string& candidate, double timestamp);
    };

    typedef std::pair<std::string, Observation> KeyObservationPair;

    size_t m_capacity;
    double m_decayExponent;
    std::list<KeyObservationPair> m_lruList;
    std::map<std::string, std::list<KeyObservationPair>::iterator> m_lruMap;
};

};   // namespace vChewing

#endif

