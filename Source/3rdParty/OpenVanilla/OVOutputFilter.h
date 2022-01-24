/* 
 *  OVOutputFilter.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVOutputFilter_h
#define OVOutputFilter_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVModule.h>
#else
    #include "OVModule.h"
#endif

namespace OpenVanilla {
    using namespace std;
    
    class OVOutputFilter : public OVModule {
    public:
        virtual bool isOutputFilter() const
        {
            return true;
        }
    };
};

#endif
