/*
 *  CoreLM.hh
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef CoreLM_H
#define CoreLM_H

#include "LanguageModel.h"
#include <string>
#include <vector>
#include <map>
#include <iostream>

// this class relies on the fact that we have a space-separated data
// format, and we use mmap and zero-out the separators and line feeds
// to avoid creating new string objects; the parser is a simple DFA

using namespace std;
using namespace Taiyan::Gramambular;

namespace vChewing {

class CoreLM : public Taiyan::Gramambular::LanguageModel {
public:
    CoreLM();
    ~CoreLM();

    bool isLoaded();
    bool open(const char *path);
    void close();
    void dump();

    virtual const vector<Bigram> bigramsForKeys(const string& preceedingKey, const string& key);
    virtual const vector<Unigram> unigramsForKey(const string& key);
    virtual bool hasUnigramsForKey(const string& key);

protected:
    struct CStringCmp
    {
        bool operator()(const char* s1, const char* s2) const
        {
            return strcmp(s1, s2) < 0;
        }
    };

    struct Row {
        const char *key;
        const char *value;
        const char *logProbability;
    };

    map<const char *, vector<Row>, CStringCmp> keyRowMap;
    int fd;
    void *data;
    size_t length;
};

}; // namespace vChewing

#endif
