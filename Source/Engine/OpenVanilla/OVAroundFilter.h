/* 
 *  OVAroundFilter.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVAroundFilter_h
#define OVAroundFilter_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVModule.h>
#else
    #include "OVModule.h"
#endif

namespace OpenVanilla {
    using namespace std;
    
    class OVAroundFilter : public OVModule {
    public:
        virtual bool isAroundFilter() const
        {
            return true;
        }                
    };
};

#endif
