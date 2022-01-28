/* 
 *  LMConsolidator.h
 *  vChewing-Specific module for Consolidating Language Model Data files.
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef LMConsolidator_hpp
#define LMConsolidator_hpp

#include <syslog.h>
#include <stdio.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <string>
#include <map>
#include <set>
#include <regex>

using namespace std;
namespace vChewing {

class LMConsolidator
{
public:
    static bool FixEOF(const char *path);
    static bool ConsolidateContent(const char *path, bool shouldsort);
};

} // namespace vChewing
#endif /* LMConsolidator_hpp */
