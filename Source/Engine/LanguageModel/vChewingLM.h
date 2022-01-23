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
#include "CNSLM.h"
#include "UserPhrasesLM.h"
#include "PhraseReplacementMap.h"
#include <unordered_set>

namespace vChewing {

using namespace Taiyan::Gramambular;

class vChewingLM : public LanguageModel {
public:
    vChewingLM();
    ~vChewingLM();
    
    void loadLanguageModel(const char* languageModelPath);
    void loadCNSData(const char* cnsDataPath);
    void loadUserPhrases(const char* userPhrasesPath, const char* excludedPhrasesPath);
    void loadPhraseReplacementMap(const char* phraseReplacementPath);
    
    const vector<Bigram> bigramsForKeys(const string& preceedingKey, const string& key);
    const vector<Unigram> unigramsForKey(const string& key);
    bool hasUnigramsForKey(const string& key);
    
    void setPhraseReplacementEnabled(bool enabled);
    bool phraseReplacementEnabled();
    
    void setCNSEnabled(bool enabled);
    bool CNSEnabled();
    
protected:
    const vector<Unigram> filterAndTransformUnigrams(vector<Unigram> unigrams,
                                                     const std::unordered_set<string>& excludedValues,
                                                     std::unordered_set<string>& insertedValues);
    
    FastLM m_languageModel;
    CNSLM m_cnsModel;
    UserPhrasesLM m_userPhrases;
    UserPhrasesLM m_excludedPhrases;
    PhraseReplacementMap m_phraseReplacement;
    bool m_phraseReplacementEnabled;
    bool m_CNSEnabled;
};
};

#endif
