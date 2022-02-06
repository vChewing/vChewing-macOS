//
// LanguageModel.h
//
// Copyright (c) 2007-2010 Lukhnos D. Liu (http://lukhnos.org)
//
//

#ifndef LanguageModel_h
#define LanguageModel_h

#include <vector>
#include "Bigram.h"
#include "Unigram.h"

namespace Taiyan {
    namespace Gramambular {
        
        using namespace std;
        
        class LanguageModel {
        public:
            virtual ~LanguageModel() {}

            virtual const vector<Bigram> bigramsForKeys(const string &preceedingKey, const string& key) = 0;
            virtual const vector<Unigram> unigramsForKey(const string &key) = 0;
            virtual bool hasUnigramsForKey(const string& key) = 0;
        };
    }
}


#endif
