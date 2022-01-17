/* 
 *  OVKeyPreprocessor.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVKeyPreprocessor_h
#define OVKeyPreprocessor_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVModule.h>
#else
    #include "OVModule.h"
#endif

namespace OpenVanilla {
    using namespace std;
    
    class OVKeyPreprocessor : public OVModule {
    public:
        virtual bool isPreprocessor() const
        {
            return true;
        }
    };
};

#endif
