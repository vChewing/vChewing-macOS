
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
    m_associatedPhrases.close();
}

void vChewingLM::loadLanguageModel(const char* languageModelDataPath)
{
    if (languageModelDataPath) {
        m_languageModel.close();
        m_languageModel.open(languageModelDataPath);
    }
}

bool vChewingLM::isDataModelLoaded()
{
    return m_languageModel.isLoaded();
}

void vChewingLM::loadAssociatedPhrases(const char* associatedPhrasesPath)
{
    if (associatedPhrasesPath) {
        m_associatedPhrases.close();
        m_associatedPhrases.open(associatedPhrasesPath);
    }
}

bool vChewingLM::isAssociatedPhrasesLoaded()
{
    return m_associatedPhrases.isLoaded();
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
    if (key == " ") {
        vector<Unigram> spaceUnigrams;
        Unigram g;
        g.keyValue.key = " ";
        g.keyValue.value= " ";
        g.score = 0;
        spaceUnigrams.push_back(g);
        return spaceUnigrams;
    }

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
    if (key == " ") {
        return true;
    }

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

void vChewingLM::setExternalConverterEnabled(bool enabled)
{
    m_externalConverterEnabled = enabled;
}

bool vChewingLM::externalConverterEnabled()
{
    return m_externalConverterEnabled;
}

void vChewingLM::setExternalConverter(std::function<string(string)> externalConverter)
{
    m_externalConverter = externalConverter;
}

const vector<Unigram> vChewingLM::filterAndTransformUnigrams(const vector<Unigram> unigrams, const unordered_set<string>& excludedValues, unordered_set<string>& insertedValues)
{
    vector<Unigram> results;

    for (auto&& unigram : unigrams) {
        // excludedValues filters out the unigrams with the original value.
        // insertedValues filters out the ones with the converted value
        string originalValue = unigram.keyValue.value;
        if (excludedValues.find(originalValue) != excludedValues.end()) {
            continue;
        }

        string value = originalValue;
        if (m_phraseReplacementEnabled) {
            string replacement = m_phraseReplacement.valueForKey(value);
            if (replacement != "") {
                value = replacement;
            }
        }
        if (m_externalConverterEnabled && m_externalConverter) {
            string replacement = m_externalConverter(value);
            value = replacement;
        }
        if (insertedValues.find(value) == insertedValues.end()) {
            Unigram g;
            g.keyValue.value = value;
            g.keyValue.key = unigram.keyValue.key;
            g.score = unigram.score;
            results.push_back(g);
            insertedValues.insert(value);
        }
    }
    return results;
}

const vector<std::string> vChewingLM::associatedPhrasesForKey(const string& key)
{
    return m_associatedPhrases.valuesForKey(key);
}

bool vChewingLM::hasAssociatedPhrasesForKey(const string& key)
{
    return m_associatedPhrases.hasValuesForKey(key);
}
