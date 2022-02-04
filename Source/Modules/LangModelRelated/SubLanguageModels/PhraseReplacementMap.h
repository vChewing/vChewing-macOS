/* 
 *  PhraseReplacementMap.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef PHRASEREPLACEMENTMAP_H
#define PHRASEREPLACEMENTMAP_H

#include <string>
#include <map>
#include <iostream>

namespace vChewing {

class PhraseReplacementMap
{
public:
    PhraseReplacementMap();
    ~PhraseReplacementMap();

    bool open(const char *path);
    void close();
    const std::string valueForKey(const std::string& key);

protected:
    std::map<std::string_view, std::string_view> keyValueMap;
    int fd;
    void *data;
    size_t length;
};

}

#endif
