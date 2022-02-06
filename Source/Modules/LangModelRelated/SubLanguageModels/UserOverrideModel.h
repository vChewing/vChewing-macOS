
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

