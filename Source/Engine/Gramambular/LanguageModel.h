/* 
 *  LanguageModel.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

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
