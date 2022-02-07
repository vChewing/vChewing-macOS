// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// See LICENSE.TXT for details.

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
