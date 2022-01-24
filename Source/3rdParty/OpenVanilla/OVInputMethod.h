/* 
 *  OVInputMethod.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVInputMethod_h
#define OVInputMethod_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVModule.h>
#else
    #include "OVModule.h"
#endif

namespace OpenVanilla {
    using namespace std;
    
    class OVInputMethod : public OVModule {
    public:
        virtual bool isInputMethod() const
        {
            return true;
        }
    };
};

#endif
