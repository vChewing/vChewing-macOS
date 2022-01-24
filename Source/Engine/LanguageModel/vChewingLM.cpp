/* 
 *  vChewingLM.cpp
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#include "vChewingLM.h"
#include <algorithm>
#include <iterator>
#include <unordered_set>

using namespace vChewing;

vChewingLM::vChewingLM()
{
}

vChewingLM::~vChewingLM()
{
    m_languageModel.close();
    m_userPhrases.close();
    m_excludedPhrases.close();
    m_phraseReplacement.close();
}

void vChewingLM::loadLanguageModel(const char* languageModelDataPath)
{
    if (languageModelDataPath) {
        m_languageModel.close();
        m_languageModel.open(languageModelDataPath);
    }
}

void vChewingLM::loadUserPhrases(const char* userPhrasesDataPath,
                                 const char* excludedPhrasesDataPath)
{
    if (userPhrasesDataPath) {
        m_userPhrases.close();
        m_userPhrases.open(userPhrasesDataPath);
    }
    if (excludedPhrasesDataPath) {
        m_excludedPhrases.close();
        m_excludedPhrases.open(excludedPhrasesDataPath);
    }
}

void vChewingLM::loadPhraseReplacementMap(const char* phraseReplacementPath) {
    if (phraseReplacementPath) {
        m_phraseReplacement.close();
        m_phraseReplacement.open(phraseReplacementPath);
    }
}

const vector<Bigram> vChewingLM::bigramsForKeys(const string& preceedingKey, const string& key)
{
    return vector<Bigram>();
}

const vector<Unigram> vChewingLM::unigramsForKey(const string& key)
{
    vector<Unigram> unigrams;
    vector<Unigram> userUnigrams;
    
    // Use unordered_set so that you don't have to do O(n*m)
    unordered_set<string> excludedValues;
    unordered_set<string> userValues;
    
    if (m_excludedPhrases.hasUnigramsForKey(key)) {
        vector<Unigram> excludedUnigrams = m_excludedPhrases.unigramsForKey(key);
        transform(excludedUnigrams.begin(), excludedUnigrams.end(),
                  inserter(excludedValues, excludedValues.end()),
                  [](const Unigram &u) { return u.keyValue.value; });
    }
    
    if (m_userPhrases.hasUnigramsForKey(key)) {
        vector<Unigram> rawUserUnigrams = m_userPhrases.unigramsForKey(key);
        vector<Unigram> filterredUserUnigrams;

        for (auto&& unigram : rawUserUnigrams) {
            if (excludedValues.find(unigram.keyValue.value) == excludedValues.end()) {
                filterredUserUnigrams.push_back(unigram);
            }
        }

        transform(filterredUserUnigrams.begin(), filterredUserUnigrams.end(),
                  inserter(userValues, userValues.end()),
                  [](const Unigram &u) { return u.keyValue.value; });

        if (m_phraseReplacementEnabled) {
            for (auto&& unigram : filterredUserUnigrams) {
                string value = unigram.keyValue.value;
                string replacement = m_phraseReplacement.valueForKey(value);
                if (replacement != "") {
                    unigram.keyValue.value = replacement;
                }
                unigrams.push_back(unigram);
            }
        } else {
            unigrams = filterredUserUnigrams;
        }
    }

    if (m_languageModel.hasUnigramsForKey(key)) {
        vector<Unigram> globalUnigrams = m_languageModel.unigramsForKey(key);

        for (auto&& unigram : globalUnigrams) {
            string value = unigram.keyValue.value;
            if (excludedValues.find(value) == excludedValues.end() &&
                userValues.find(value) == userValues.end()) {
                if (m_phraseReplacementEnabled) {
                    string replacement = m_phraseReplacement.valueForKey(value);
                    if (replacement != "") {
                        unigram.keyValue.value = replacement;
                    }
                }
                unigrams.push_back(unigram);
            }
        }
    }
    
    unigrams.insert(unigrams.begin(), userUnigrams.begin(), userUnigrams.end());
    return unigrams;
}

bool vChewingLM::hasUnigramsForKey(const string& key)
{
    if (key == " ") {
        return true;
    }

    if (!m_excludedPhrases.hasUnigramsForKey(key)) {
        return m_userPhrases.hasUnigramsForKey(key) ||
        m_languageModel.hasUnigramsForKey(key);
    }
    
    return unigramsForKey(key).size() > 0;
}
    
void vChewingLM::setPhraseReplacementEnabled(bool enabled)
{
        m_phraseReplacementEnabled = enabled;
}
    
bool vChewingLM::phraseReplacementEnabled()
{
    return m_phraseReplacementEnabled;
}
