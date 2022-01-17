/* 
 *  OVException.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVException_h
#define OVException_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVBase.h>
#else
    #include "OVBase.h"
#endif

namespace OpenVanilla {
    using namespace std;

    class OVException {
    public:
        class OverflowException {};
    };
};

#endif
