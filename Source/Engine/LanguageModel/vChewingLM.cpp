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

void vChewingLM::loadPhraseReplacementMap(const char* phraseReplacementPath)
{
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
    vector<Unigram> allUnigrams;
    vector<Unigram> userUnigrams;

    unordered_set<string> excludedValues;
    unordered_set<string> insertedValues;

    if (m_excludedPhrases.hasUnigramsForKey(key)) {
        vector<Unigram> excludedUnigrams = m_excludedPhrases.unigramsForKey(key);
        transform(excludedUnigrams.begin(), excludedUnigrams.end(),
                  inserter(excludedValues, excludedValues.end()),
                  [](const Unigram& u) { return u.keyValue.value; });
    }

    if (m_userPhrases.hasUnigramsForKey(key)) {
        vector<Unigram> rawUserUnigrams = m_userPhrases.unigramsForKey(key);
        userUnigrams = filterAndTransformUnigrams(rawUserUnigrams, excludedValues, insertedValues);
    }

    if (m_languageModel.hasUnigramsForKey(key)) {
        vector<Unigram> rawGlobalUnigrams = m_languageModel.unigramsForKey(key);
        allUnigrams = filterAndTransformUnigrams(rawGlobalUnigrams, excludedValues, insertedValues);
    }

    allUnigrams.insert(allUnigrams.begin(), userUnigrams.begin(), userUnigrams.end());
    return allUnigrams;
}

bool vChewingLM::hasUnigramsForKey(const string& key)
{
    if (!m_excludedPhrases.hasUnigramsForKey(key)) {
        return m_userPhrases.hasUnigramsForKey(key) || m_languageModel.hasUnigramsForKey(key);
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

const vector<Unigram> vChewingLM::filterAndTransformUnigrams(vector<Unigram> unigrams, const unordered_set<string>& excludedValues, unordered_set<string>& insertedValues)
{
    vector<Unigram> results;

    for (auto&& unigram : unigrams) {
        string value = unigram.keyValue.value;
        if (m_phraseReplacementEnabled) {
            string replacement = m_phraseReplacement.valueForKey(value);
            if (replacement != "") {
                value = replacement;
                unigram.keyValue.value = value;
            }
        }
        if (excludedValues.find(value) == excludedValues.end() && insertedValues.find(value) == insertedValues.end()) {
            results.push_back(unigram);
            insertedValues.insert(value);
        }
    }
    return results;
}
