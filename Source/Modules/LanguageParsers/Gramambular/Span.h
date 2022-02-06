//
// Span.h
//
// Copyright (c) 2007-2010 Lukhnos D. Liu (http://lukhnos.org)
//
//

#ifndef Span_h
#define Span_h

#include <map>
#include <set>
#include <sstream>
#include "Node.h"

namespace Taiyan {
    namespace Gramambular {
        class Span {
        public:
            Span();

            void clear();
            void insertNodeOfLength(const Node& inNode, size_t inLength);
            void removeNodeOfLengthGreaterThan(size_t inLength);
            
            Node* nodeOfLength(size_t inLength);
            size_t maximumLength() const;

        protected:
            map<size_t, Node> m_lengthNodeMap;
            size_t m_maximumLength;
        };
        
        inline Span::Span()
            : m_maximumLength(0)
        {
        }
        
        inline void Span::clear()
        {
            m_lengthNodeMap.clear();
            m_maximumLength = 0;
        }
        
        inline void Span::insertNodeOfLength(const Node& inNode, size_t inLength)
        {
            m_lengthNodeMap[inLength] = inNode;
            if (inLength > m_maximumLength) {
                m_maximumLength = inLength;
            }
        }
        
        inline void Span::removeNodeOfLengthGreaterThan(size_t inLength)
        {
            if (inLength > m_maximumLength) {
                return;
            }
            
            size_t max = 0;
            set<size_t> removeSet;
            for (map<size_t, Node>::iterator i = m_lengthNodeMap.begin(), e = m_lengthNodeMap.end() ; i != e ; ++i) {
                if ((*i).first > inLength) {
                    removeSet.insert((*i).first);
                }
                else {
                    if ((*i).first > max) {
                        max = (*i).first;
                    }
                }
            }
            
            for (set<size_t>::iterator i = removeSet.begin(), e = removeSet.end(); i != e; ++i) {
                m_lengthNodeMap.erase(*i);
            }

            m_maximumLength = max;
        }
        
        inline Node* Span::nodeOfLength(size_t inLength)
        {
            map<size_t, Node>::iterator f = m_lengthNodeMap.find(inLength);
            return f == m_lengthNodeMap.end() ? 0 : &(*f).second;
        }
        
        inline size_t Span::maximumLength() const
        {
            return m_maximumLength;
        }
    }
}

#endif
