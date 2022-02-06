//
// NodeAnchor.h
//
// Copyright (c) 2007-2010 Lukhnos D. Liu (http://lukhnos.org)
//
//

#ifndef NodeAnchor_h
#define NodeAnchor_h

#include "Node.h"

namespace Taiyan {
    namespace Gramambular {
        class NodeAnchor {
        public:
            NodeAnchor();
            const Node *node;
            size_t location;
            size_t spanningLength;
            double accumulatedScore;
        };
        
        inline NodeAnchor::NodeAnchor()
            : node(0)
            , location(0)
            , spanningLength(0)
            , accumulatedScore(0.0)
        {
        }        

        inline ostream& operator<<(ostream& inStream, const NodeAnchor& inAnchor)
        {
            inStream << "{@(" << inAnchor.location << "," << inAnchor.spanningLength << "),";
            if (inAnchor.node) {
                inStream << *(inAnchor.node);
            }
            else {
                inStream << "null";
            }
            inStream << "}";
            return inStream;
        }
        
        inline ostream& operator<<(ostream& inStream, const vector<NodeAnchor>& inAnchor)
        {
            for (vector<NodeAnchor>::const_iterator i = inAnchor.begin() ; i != inAnchor.end() ; ++i) {
                inStream << *i;
                if (i + 1 != inAnchor.end()) {
                    inStream << "<-";
                }
            }
            
            return inStream;            
        }
    }
}

#endif
