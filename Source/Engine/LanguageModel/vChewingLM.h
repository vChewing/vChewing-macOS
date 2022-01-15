//
// vChewingLM.h
//
// Copyright (c) 2021-2022 The vChewing Project.
// Copyright (c) 2011-2022 The OpenVanilla Project.
//
// Contributors:
//     Weizhong Yang (@zonble) @ OpenVanilla
//     Hiraku Wang (@hirakujira) @ vChewing
//     Shiki Suen (@ShikiSuen) @ vChewing
//
// Based on the Syrup Project and the Formosana Library
// by Lukhnos Liu (@lukhnos).
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#ifndef VCHEWINGLM_H
#define VCHEWINGLM_H

#include <stdio.h>
#include "FastLM.h"

namespace vChewing {

using namespace Formosa::Gramambular;

class vChewingLM : public LanguageModel {
public:
    vChewingLM();
    ~vChewingLM();
    
    void loadLanguageModel(const char* languageModelDataPath);
    void loadUserPhrases(const char* m_userPhrasesDataPath,
                         const char* m_excludedPhrasesDataPath);
    
    const vector<Bigram> bigramsForKeys(const string& preceedingKey, const string& key);
    const vector<Unigram> unigramsForKey(const string& key);
    bool hasUnigramsForKey(const string& key);
    
protected:
    FastLM m_languageModel;
    FastLM m_userPhrases;
    FastLM m_excludedPhrases;
};
};

#endif
