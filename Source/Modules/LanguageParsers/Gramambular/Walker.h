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

#ifndef Walker_h
#define Walker_h

#include <algorithm>
#include "Grid.h"

namespace Taiyan {
    namespace Gramambular {
        using namespace std;

        class Walker {
        public:
            Walker(Grid* inGrid);
            const vector<NodeAnchor> reverseWalk(size_t inLocation, double inAccumulatedScore = 0.0);            
            
        protected:
            Grid* m_grid;
        };
        
        inline Walker::Walker(Grid* inGrid)
            : m_grid(inGrid)
        {
        }
        
        inline const vector<NodeAnchor> Walker::reverseWalk(size_t inLocation, double inAccumulatedScore)
        {
            if (!inLocation || inLocation > m_grid->width()) {
                return vector<NodeAnchor>();
            }
            
            vector<vector<NodeAnchor> > paths;

            vector<NodeAnchor> nodes = m_grid->nodesEndingAt(inLocation);
            
            for (vector<NodeAnchor>::iterator ni = nodes.begin() ; ni != nodes.end() ; ++ni) {
                if (!(*ni).node) {
                    continue;
                }

                (*ni).accumulatedScore = inAccumulatedScore + (*ni).node->score();

                vector<NodeAnchor> path = reverseWalk(inLocation - (*ni).spanningLength, (*ni).accumulatedScore);
                path.insert(path.begin(), *ni);
                
                paths.push_back(path);
            }
            
            if (!paths.size()) {
                return vector<NodeAnchor>();
            }
            
            vector<NodeAnchor>* result = &*(paths.begin());
            for (vector<vector<NodeAnchor> >::iterator pi = paths.begin() ; pi != paths.end() ; ++pi) {                
                if ((*pi).back().accumulatedScore > result->back().accumulatedScore) {
                    result = &*pi;
                }
            }
            
            return *result;
        }
    }
}

#endif
