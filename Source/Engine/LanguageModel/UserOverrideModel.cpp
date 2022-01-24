/* 
 *  UserOverrideModel.cpp
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#include "UserOverrideModel.h"

#include <cassert>
#include <cmath>
#include <sstream>

using namespace vChewing;

// About 20 generations.
static const double DecayThreshould = 1.0 / 1048576.0;

static double Score(size_t eventCount,
                    size_t totalCount,
                    double eventTimestamp,
                    double timestamp,
                    double lambda);
static bool IsEndingPunctuation(const string& value);
static string WalkedNodesToKey(const std::vector<NodeAnchor>& walkedNodes,
                               size_t cursorIndex);

UserOverrideModel::UserOverrideModel(size_t capacity, double decayConstant)
    : m_capacity(capacity) {
    assert(m_capacity > 0);
    m_decayExponent = log(0.5) / decayConstant;
}

void UserOverrideModel::observe(const std::vector<NodeAnchor>& walkedNodes,
                                size_t cursorIndex,
                                const string& candidate,
                                double timestamp) {
    string key = WalkedNodesToKey(walkedNodes, cursorIndex);
    auto mapIter = m_lruMap.find(key);
    if (mapIter == m_lruMap.end()) {
        auto keyValuePair = KeyObservationPair(key, Observation());
        Observation& observation = keyValuePair.second;
        observation.update(candidate, timestamp);

        m_lruList.push_front(keyValuePair);
        auto listIter = m_lruList.begin();
        auto lruKeyValue = std::pair<std::string,
                std::list<KeyObservationPair>::iterator>(key, listIter);
        m_lruMap.insert(lruKeyValue);

        if (m_lruList.size() > m_capacity) {
            auto lastKeyValuePair = m_lruList.end();
            --lastKeyValuePair;
            m_lruMap.erase(lastKeyValuePair->first);
            m_lruList.pop_back();
        }
    } else {
        auto listIter = mapIter->second;
        m_lruList.splice(m_lruList.begin(), m_lruList, listIter);

        auto& keyValuePair = *listIter;
        Observation& observation = keyValuePair.second;
        observation.update(candidate, timestamp);
    }
}

string UserOverrideModel::suggest(const std::vector<NodeAnchor>& walkedNodes,
                                  size_t cursorIndex,
                                  double timestamp) {
    string key = WalkedNodesToKey(walkedNodes, cursorIndex);
    auto mapIter = m_lruMap.find(key);
    if (mapIter == m_lruMap.end()) {
        return string();
    }

    auto listIter = mapIter->second;
    auto& keyValuePair = *listIter;
    const Observation& observation = keyValuePair.second;

    string candidate;
    double score = 0.0;
    for (auto i = observation.overrides.begin();
         i != observation.overrides.end();
         ++i) {
        const Override& o = i->second;
        double overrideScore = Score(o.count,
                                     observation.count,
                                     o.timestamp,
                                     timestamp,
                                     m_decayExponent);
        if (overrideScore == 0.0) {
            continue;
        }

        if (overrideScore > score) {
            candidate = i->first;
            score = overrideScore;
        }
    }
    return candidate;
}

void UserOverrideModel::Observation::update(const string& candidate,
                                            double timestamp) {
    count++;
    auto& o = overrides[candidate];
    o.timestamp = timestamp;
    o.count++;
}

static double Score(size_t eventCount,
                    size_t totalCount,
                    double eventTimestamp,
                    double timestamp,
                    double lambda) {
    double decay = exp((timestamp - eventTimestamp) * lambda);
    if (decay < DecayThreshould) {
        return 0.0;
    }

    double prob = (double)eventCount / (double)totalCount;
    return prob * decay;
}

static bool IsEndingPunctuation(const string& value) {
    return value == "，" || value == "。" || value== "！" || value == "？" ||
        value == "」" || value == "』" || value== "”" || value == "’";
}
static string WalkedNodesToKey(const std::vector<NodeAnchor>& walkedNodes,
                               size_t cursorIndex) {
    std::stringstream s;
    std::vector<NodeAnchor> n;
    size_t ll = 0;
    for (std::vector<NodeAnchor>::const_iterator i = walkedNodes.begin();
         i != walkedNodes.end();
         ++i) {
        const auto& nn = *i;
        n.push_back(nn);
        ll += nn.spanningLength;
        if (ll >= cursorIndex) {
            break;
        }
    }

    std::vector<NodeAnchor>::const_reverse_iterator r = n.rbegin();

    if (r == n.rend()) {
        return "";
    }

    string current = (*r).node->currentKeyValue().key;
    ++r;

    s.clear();
    s.str(std::string());
    if (r != n.rend()) {
        string value = (*r).node->currentKeyValue().value;
        if (IsEndingPunctuation(value)) {
            s << "()";
            r = n.rend();
        } else {
            s << "("
                    << (*r).node->currentKeyValue().key
                    << ","
                    << value
                    << ")";
            ++r;
        }
    } else {
        s << "()";
    }
    string prev = s.str();

    s.clear();
    s.str(std::string());
    if (r != n.rend()) {
        string value = (*r).node->currentKeyValue().value;
        if (IsEndingPunctuation(value)) {
            s << "()";
            r = n.rend();
        } else {
            s << "("
            << (*r).node->currentKeyValue().key
            << ","
            << value
            << ")";
            ++r;
        }
    } else {
        s << "()";
    }
    string anterior = s.str();

    s.clear();
    s.str(std::string());
    s << "(" << anterior << "," << prev << "," << current << ")";

    return s.str();
}
