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

#include "Grid.h"

#include <iostream>
#include <string>

namespace Taiyan {
namespace Gramambular {

std::string Grid::dumpDOT() {
    std::stringstream sst;
    sst << "digraph {" << std::endl;
    sst << "graph [ rankdir=LR ];" << std::endl;
    sst << "BOS;" << std::endl;
    
    for (size_t p = 0; p < m_spans.size(); p++) {
        Span& span = m_spans[p];
        for (size_t ni = 0; ni <= span.maximumLength(); ni++) {
            Node* np = span.nodeOfLength(ni);
            if (np) {
                if (!p) {
                    sst << "BOS -> " << np->currentKeyValue().value << ";" << std::endl;
                }
                
                sst << np->currentKeyValue().value << ";" << std::endl;
                
                if (p + ni < m_spans.size()) {
                    Span& dstSpan = m_spans[p + ni];
                    for (size_t q = 0; q <= dstSpan.maximumLength(); q++) {
                        Node* dn = dstSpan.nodeOfLength(q);
                        if (dn) {
                            sst << np->currentKeyValue().value << " -> "
                            << dn->currentKeyValue().value << ";" << std::endl;
                        }
                    }
                }
                
                if (p + ni == m_spans.size()) {
                    sst << np->currentKeyValue().value << " -> "
                    << "EOS;" << std::endl;
                }
            }
        }
    }
    
    sst << "EOS;" << std::endl;
    sst << "}";
    return sst.str();
}

}  // namespace Gramambular
}  // namespace Taiyan
