//
// UserPhraseLM.h
//
// Copyright (c) 2011-2022 The OpenVanilla Project.
//
// Contributors:
//     Weizhong Yang (@zonble) @ OpenVanilla
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

#ifndef USERPHRASESLM_H
#define USERPHRASESLM_H

#include <stdio.h>

#include <string>
#include <map>
#include <iostream>
#include "LanguageModel.h"

namespace vChewing {

using namespace Formosa::Gramambular;

class UserPhrasesLM : public LanguageModel
{
public:
    UserPhrasesLM();
    ~UserPhrasesLM();

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
    };

    map<const char *, vector<Row>, CStringCmp> keyRowMap;
    int fd;
    void *data;
    size_t length;
};

}

#endif
