/* 
 *  UserPhrasesLM.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef USERPHRASESLM_H
#define USERPHRASESLM_H

#include <string>
#include <map>
#include <iostream>
#include "LanguageModel.h"

namespace vChewing {

class UserPhrasesLM : public Taiyan::Gramambular::LanguageModel
{
public:
    UserPhrasesLM();
    ~UserPhrasesLM();
    
    bool open(const char *path);
    void close();
    void dump();
    
    virtual const std::vector<Taiyan::Gramambular::Bigram> bigramsForKeys(const std::string& preceedingKey, const std::string& key);
    virtual const std::vector<Taiyan::Gramambular::Unigram> unigramsForKey(const std::string& key);
    virtual bool hasUnigramsForKey(const std::string& key);
    
protected:
    struct Row {
        Row(std::string_view& k, std::string_view& v) : key(k), value(v) {}
        std::string_view key;
        std::string_view value;
    };
    
    std::map<std::string_view, std::vector<Row>> keyRowMap;
    int fd;
    void *data;
    size_t length;
};

}

#endif
