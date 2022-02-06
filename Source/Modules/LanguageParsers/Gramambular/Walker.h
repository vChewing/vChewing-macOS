/* 
 *  Walker.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
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
