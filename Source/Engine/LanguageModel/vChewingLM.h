/* 
 *  vChewingLM.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef VCHEWINGLM_H
#define VCHEWINGLM_H

#include <stdio.h>
#include "FastLM.h"
#include "UserPhrasesLM.h"
#include "PhraseReplacementMap.h"

namespace vChewing {

using namespace Taiyan::Gramambular;

class vChewingLM : public LanguageModel {
public:
    vChewingLM();
    ~vChewingLM();
    
    void loadLanguageModel(const char* languageModelDataPath);
    void loadUserPhrases(const char* userPhrasesDataPath,
                         const char* excludedPhrasesDataPath);
    void loadPhraseReplacementMap(const char* phraseReplacementPath);
    
    const vector<Bigram> bigramsForKeys(const string& preceedingKey, const string& key);
    const vector<Unigram> unigramsForKey(const string& key);
    bool hasUnigramsForKey(const string& key);
    
    void setPhraseReplacementEnabled(bool enabled);
    bool phraseReplacementEnabled();
    
protected:
    FastLM m_languageModel;
    UserPhrasesLM m_userPhrases;
    UserPhrasesLM m_excludedPhrases;
    PhraseReplacementMap m_phraseReplacement;
    bool m_phraseReplacementEnabled;
};
};

#endif
