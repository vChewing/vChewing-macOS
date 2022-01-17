/* 
 *  OVLoaderBase.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVLoaderBase_h
#define OVLoaderBase_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVModule.h>
#else
    #include "OVModule.h"
#endif

namespace OpenVanilla {
    using namespace std;

    class OVLoader : public OVBase {
    public:
        virtual OVLoaderService* loaderService() = 0;
        virtual OVModule* moduleForIdentifier(const string& identifier) = 0;
        virtual vector<string> moduleIdentifiers() = 0;
        virtual vector<string> moduleIdentifiersForConditions(bool preprocessor, bool inputMethod, bool outputFilter) = 0;
    };

};

#endif
