// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "LMInstantiator.h"
#include <algorithm>
#include <iterator>

namespace vChewing {

LMInstantiator::LMInstantiator()
{
}

LMInstantiator::~LMInstantiator()
{
    m_languageModel.close();
    m_miscModel.close();
    m_userPhrases.close();
    m_cnsModel.close();
    m_excludedPhrases.close();
    m_phraseReplacement.close();
    m_associatedPhrases.close();
}

void LMInstantiator::loadLanguageModel(const char* languageModelDataPath)
{
    if (languageModelDataPath) {
        m_languageModel.close();
        m_languageModel.open(languageModelDataPath);
    }
}

bool LMInstantiator::isDataModelLoaded()
{
    return m_languageModel.isLoaded();
}

void LMInstantiator::loadCNSData(const char* cnsDataPath)
{
    if (cnsDataPath) {
        m_cnsModel.close();
        m_cnsModel.open(cnsDataPath);
    }
}

bool LMInstantiator::isCNSDataLoaded()
{
    return m_cnsModel.isLoaded();
}

void LMInstantiator::loadMiscData(const char* miscDataPath)
{
    if (miscDataPath) {
        m_miscModel.close();
        m_miscModel.open(miscDataPath);
    }
}

bool LMInstantiator::isMiscDataLoaded()
{
    return m_miscModel.isLoaded();
}

void LMInstantiator::loadSymbolData(const char* symbolDataPath)
{
    if (symbolDataPath) {
        m_symbolModel.close();
        m_symbolModel.open(symbolDataPath);
    }
}

bool LMInstantiator::isSymbolDataLoaded()
{
    return m_symbolModel.isLoaded();
}

void LMInstantiator::loadUserPhrases(const char* userPhrasesDataPath,
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

void LMInstantiator::loadUserAssociatedPhrases(const char *userAssociatedPhrasesPath)
{
    if (userAssociatedPhrasesPath) {
        m_associatedPhrases.close();
        m_associatedPhrases.open(userAssociatedPhrasesPath);
    }
}

void LMInstantiator::loadPhraseReplacementMap(const char* phraseReplacementPath)
{
    if (phraseReplacementPath) {
        m_phraseReplacement.close();
        m_phraseReplacement.open(phraseReplacementPath);
    }
}

const std::vector<Gramambular::Bigram> LMInstantiator::bigramsForKeys(const std::string& preceedingKey, const std::string& key)
{
    return std::vector<Gramambular::Bigram>();
}

const std::vector<Gramambular::Unigram> LMInstantiator::unigramsForKey(const std::string& key)
{
    if (key == " ") {
        std::vector<Gramambular::Unigram> spaceUnigrams;
        Gramambular::Unigram g;
        g.keyValue.key = " ";
        g.keyValue.value = " ";
        g.score = 0;
        spaceUnigrams.push_back(g);
        return spaceUnigrams;
    }

    std::vector<Gramambular::Unigram> allUnigrams;
    std::vector<Gramambular::Unigram> miscUnigrams;
    std::vector<Gramambular::Unigram> symbolUnigrams;
    std::vector<Gramambular::Unigram> userUnigrams;
    std::vector<Gramambular::Unigram> cnsUnigrams;

     std::unordered_set<std::string> excludedValues;
     std::unordered_set<std::string> insertedValues;

    if (m_excludedPhrases.hasUnigramsForKey(key)) {
        std::vector<Gramambular::Unigram> excludedUnigrams = m_excludedPhrases.unigramsForKey(key);
        transform(excludedUnigrams.begin(), excludedUnigrams.end(),
            inserter(excludedValues, excludedValues.end()),
            [](const Gramambular::Unigram& u) { return u.keyValue.value; });
    }

    if (m_userPhrases.hasUnigramsForKey(key)) {
        std::vector<Gramambular::Unigram> rawUserUnigrams = m_userPhrases.unigramsForKey(key);
        // 用這句指令讓使用者語彙檔案內的詞條優先順序隨著行數增加而逐漸增高。
        // 這樣一來就可以在就地新增語彙時徹底複寫優先權。
        std::reverse(rawUserUnigrams.begin(), rawUserUnigrams.end());
        userUnigrams = filterAndTransformUnigrams(rawUserUnigrams, excludedValues, insertedValues);
    }

    if (m_languageModel.hasUnigramsForKey(key)) {
        std::vector<Gramambular::Unigram> rawGlobalUnigrams = m_languageModel.unigramsForKey(key);
        allUnigrams = filterAndTransformUnigrams(rawGlobalUnigrams, excludedValues, insertedValues);
    }

    if (m_miscModel.hasUnigramsForKey(key)) {
        std::vector<Gramambular::Unigram> rawMiscUnigrams = m_miscModel.unigramsForKey(key);
        miscUnigrams = filterAndTransformUnigrams(rawMiscUnigrams, excludedValues, insertedValues);
    }

    if (m_symbolModel.hasUnigramsForKey(key)) {
        std::vector<Gramambular::Unigram> rawSymbolUnigrams = m_symbolModel.unigramsForKey(key);
        symbolUnigrams = filterAndTransformUnigrams(rawSymbolUnigrams, excludedValues, insertedValues);
    }

    if (m_cnsModel.hasUnigramsForKey(key) && m_cnsEnabled) {
        std::vector<Gramambular::Unigram> rawCNSUnigrams = m_cnsModel.unigramsForKey(key);
        cnsUnigrams = filterAndTransformUnigrams(rawCNSUnigrams, excludedValues, insertedValues);
    }

    allUnigrams.insert(allUnigrams.begin(), userUnigrams.begin(), userUnigrams.end());
    allUnigrams.insert(allUnigrams.end(), cnsUnigrams.begin(), cnsUnigrams.end());
    allUnigrams.insert(allUnigrams.begin(), miscUnigrams.begin(), miscUnigrams.end());
    allUnigrams.insert(allUnigrams.end(), symbolUnigrams.begin(), symbolUnigrams.end());
    return allUnigrams;
}

bool LMInstantiator::hasUnigramsForKey(const std::string& key)
{
    if (key == " ") {
        return true;
    }

    if (!m_excludedPhrases.hasUnigramsForKey(key)) {
        return m_userPhrases.hasUnigramsForKey(key) || m_languageModel.hasUnigramsForKey(key);
    }

    return unigramsForKey(key).size() > 0;
}

void LMInstantiator::setPhraseReplacementEnabled(bool enabled)
{
    m_phraseReplacementEnabled = enabled;
}

bool LMInstantiator::phraseReplacementEnabled()
{
    return m_phraseReplacementEnabled;
}

void LMInstantiator::setCNSEnabled(bool enabled)
{
    m_cnsEnabled = enabled;
}
bool LMInstantiator::cnsEnabled()
{
    return m_cnsEnabled;
}

void LMInstantiator::setExternalConverterEnabled(bool enabled)
{
    m_externalConverterEnabled = enabled;
}

bool LMInstantiator::externalConverterEnabled()
{
    return m_externalConverterEnabled;
}

void LMInstantiator::setExternalConverter(std::function<std::string(std::string)> externalConverter)
{
    m_externalConverter = externalConverter;
}

const std::vector<Gramambular::Unigram> LMInstantiator::filterAndTransformUnigrams(const std::vector<Gramambular::Unigram> unigrams, const  std::unordered_set<std::string>& excludedValues,  std::unordered_set<std::string>& insertedValues)
{
    std::vector<Gramambular::Unigram> results;

    for (auto&& unigram : unigrams) {
        // excludedValues filters out the unigrams with the original value.
        // insertedValues filters out the ones with the converted value
        std::string originalValue = unigram.keyValue.value;
        if (excludedValues.find(originalValue) != excludedValues.end()) {
            continue;
        }

        std::string value = originalValue;
        if (m_phraseReplacementEnabled) {
            std::string replacement = m_phraseReplacement.valueForKey(value);
            if (replacement != "") {
                value = replacement;
            }
        }
        if (m_externalConverterEnabled && m_externalConverter) {
            std::string replacement = m_externalConverter(value);
            value = replacement;
        }
        if (insertedValues.find(value) == insertedValues.end()) {
            Gramambular::Unigram g;
            g.keyValue.value = value;
            g.keyValue.key = unigram.keyValue.key;
            g.score = unigram.score;
            results.push_back(g);
            insertedValues.insert(value);
        }
    }
    return results;
}

const std::vector<std::string> LMInstantiator::associatedPhrasesForKey(const std::string& key)
{
    return m_associatedPhrases.valuesForKey(key);
}

bool LMInstantiator::hasAssociatedPhrasesForKey(const std::string& key)
{
    return m_associatedPhrases.hasValuesForKey(key);
}

} // namespace vChewing
