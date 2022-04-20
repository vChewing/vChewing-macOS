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

#ifndef GRID_H_
#define GRID_H_

#include <map>
#include <string>
#include <vector>

#include "NodeAnchor.h"
#include "Span.h"

namespace Gramambular
{

class Grid
{
  public:
    void clear();
    void insertNode(const Node &node, size_t location, size_t spanningLength);
    bool hasNodeAtLocationSpanningLengthMatchingKey(size_t location, size_t spanningLength, const std::string &key);

    void setHaninInputEnabled(bool enabled);
    bool HaninInputEnabled();

    void expandGridByOneAtLocation(size_t location);
    void shrinkGridByOneAtLocation(size_t location);

    size_t width() const;
    std::vector<NodeAnchor> nodesEndingAt(size_t location);
    std::vector<NodeAnchor> nodesCrossingOrEndingAt(size_t location);

    // "Freeze" the node with the unigram that represents the selected candidate
    // value. After this, the node that contains the unigram will always be
    // evaluated to that unigram, while all other overlapping nodes will be reset
    // to their initial state (that is, if any of those nodes were "frozen" or
    // fixed, they will be unfrozen.)
    NodeAnchor fixNodeSelectedCandidate(size_t location, const std::string &value);

    // Similar to fixNodeSelectedCandidate, but instead of "freezing" the node,
    // only boost the unigram that represents the value with an overriding score.
    // This has the same side effect as fixNodeSelectedCandidate, which is that
    // all other overlapping nodes will be reset to their initial state.
    void overrideNodeScoreForSelectedCandidate(size_t location, const std::string &value, float overridingScore);

    std::string dumpDOT()
    {
        std::stringstream sst;
        sst << "digraph {" << std::endl;
        sst << "graph [ rankdir=LR ];" << std::endl;
        sst << "BOS;" << std::endl;

        for (size_t p = 0; p < m_spans.size(); p++)
        {
            Span &span = m_spans[p];
            for (size_t ni = 0; ni <= span.maximumLength(); ni++)
            {
                Node *np = span.nodeOfLength(ni);
                if (np)
                {
                    if (!p)
                    {
                        sst << "BOS -> " << np->currentKeyValue().value << ";" << std::endl;
                    }

                    sst << np->currentKeyValue().value << ";" << std::endl;

                    if (p + ni < m_spans.size())
                    {
                        Span &dstSpan = m_spans[p + ni];
                        for (size_t q = 0; q <= dstSpan.maximumLength(); q++)
                        {
                            Node *dn = dstSpan.nodeOfLength(q);
                            if (dn)
                            {
                                sst << np->currentKeyValue().value << " -> " << dn->currentKeyValue().value << ";"
                                    << std::endl;
                            }
                        }
                    }

                    if (p + ni == m_spans.size())
                    {
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

  protected:
    std::vector<Span> m_spans;
    bool m_bolHaninEnabled;
};

inline void Grid::setHaninInputEnabled(bool enabled)
{
    m_bolHaninEnabled = enabled;
}

inline bool Grid::HaninInputEnabled()
{
    return m_bolHaninEnabled;
}

inline void Grid::clear()
{
    m_spans.clear();
}

inline void Grid::insertNode(const Node &node, size_t location, size_t spanningLength)
{
    if (location >= m_spans.size())
    {
        size_t diff = location - m_spans.size() + 1;

        for (size_t i = 0; i < diff; i++)
        {
            m_spans.push_back(Span());
        }
    }

    m_spans[location].insertNodeOfLength(node, spanningLength);
}

inline bool Grid::hasNodeAtLocationSpanningLengthMatchingKey(size_t location, size_t spanningLength,
                                                             const std::string &key)
{
    if (location > m_spans.size())
    {
        return false;
    }

    const Node *n = m_spans[location].nodeOfLength(spanningLength);
    if (!n)
    {
        return false;
    }

    return key == n->key();
}

inline void Grid::expandGridByOneAtLocation(size_t location)
{
    if (!location || location == m_spans.size())
    {
        m_spans.insert(m_spans.begin() + location, Span());
    }
    else
    {
        m_spans.insert(m_spans.begin() + location, Span());
        for (size_t i = 0; i < location; i++)
        {
            // zaps overlapping spans
            m_spans[i].removeNodeOfLengthGreaterThan(location - i);
        }
    }
}

inline void Grid::shrinkGridByOneAtLocation(size_t location)
{
    if (location >= m_spans.size())
    {
        return;
    }

    m_spans.erase(m_spans.begin() + location);
    for (size_t i = 0; i < location; i++)
    {
        // zaps overlapping spans
        m_spans[i].removeNodeOfLengthGreaterThan(location - i);
    }
}

inline size_t Grid::width() const
{
    return m_spans.size();
}

inline std::vector<NodeAnchor> Grid::nodesEndingAt(size_t location)
{
    std::vector<NodeAnchor> result;

    if (m_spans.size() && location <= m_spans.size())
    {
        for (size_t i = 0; i < location; i++)
        {
            Span &span = m_spans[i];
            if (i + span.maximumLength() >= location)
            {
                Node *np = span.nodeOfLength(location - i);
                if (np)
                {
                    NodeAnchor na;
                    na.node = np;
                    na.location = i;
                    na.spanningLength = location - i;

                    result.push_back(na);
                }
            }
        }
    }

    return result;
}

inline std::vector<NodeAnchor> Grid::nodesCrossingOrEndingAt(size_t location)
{
    std::vector<NodeAnchor> result;

    if (m_spans.size() && location <= m_spans.size())
    {
        for (size_t i = 0; i < location; i++)
        {
            Span &span = m_spans[i];

            if (i + span.maximumLength() >= location)
            {
                for (size_t j = 1, m = span.maximumLength(); j <= m; j++)
                {
                    // 左半是漢音模式，已經自威注音 1.5.2 版開始解決了可以在詞中間叫出候選字的問題。
                    // TODO: 右半是微軟新注音模式，仍有可以在詞中間叫出候選字的問題。
                    if (((i + j != location) && m_bolHaninEnabled) || ((i + j < location) && !m_bolHaninEnabled))
                    {
                        continue;
                    }

                    Node *np = span.nodeOfLength(j);
                    if (np)
                    {
                        NodeAnchor na;
                        na.node = np;
                        na.location = i;
                        na.spanningLength = location - i;

                        result.push_back(na);
                    }
                }
            }
        }
    }

    return result;
}

// For nodes found at the location, fix their currently-selected candidate using
// the supplied string value.
inline NodeAnchor Grid::fixNodeSelectedCandidate(size_t location, const std::string &value)
{
    std::vector<NodeAnchor> nodes = nodesCrossingOrEndingAt(location);
    NodeAnchor node;
    for (auto nodeAnchor : nodes)
    {
        auto candidates = nodeAnchor.node->candidates();

        // Reset the candidate-fixed state of every node at the location.
        const_cast<Node *>(nodeAnchor.node)->resetCandidate();

        for (size_t i = 0, c = candidates.size(); i < c; ++i)
        {
            if (candidates[i].value == value)
            {
                const_cast<Node *>(nodeAnchor.node)->selectCandidateAtIndex(i);
                node = nodeAnchor;
                break;
            }
        }
    }
    return node;
}

inline void Grid::overrideNodeScoreForSelectedCandidate(size_t location, const std::string &value,
                                                        float overridingScore)
{
    std::vector<NodeAnchor> nodes = nodesCrossingOrEndingAt(location);
    for (auto nodeAnchor : nodes)
    {
        auto candidates = nodeAnchor.node->candidates();

        // Reset the candidate-fixed state of every node at the location.
        const_cast<Node *>(nodeAnchor.node)->resetCandidate();

        for (size_t i = 0, c = candidates.size(); i < c; ++i)
        {
            if (candidates[i].value == value)
            {
                const_cast<Node *>(nodeAnchor.node)->selectFloatingCandidateAtIndex(i, overridingScore);
                break;
            }
        }
    }
}

} // namespace Gramambular

#endif
