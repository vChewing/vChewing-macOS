/* 
 *  OVFrameworkInfo.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVFrameworkVersion_h
#define OVFrameworkVersion_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVBase.h>
#else
    #include "OVBase.h"
#endif

#include <sstream>

namespace OpenVanilla {
    using namespace std;
    
	class OVFrameworkInfo {
    public:
        static unsigned int MajorVersion()
        {
            return c_MajorVersion;
        }
        
        static unsigned int MinorVersion()
        {
            return c_MinorVersion;
        }
        
        static unsigned int TinyVersion()
        {
            return c_TinyVersion;
        }
        
        static unsigned int Version()
        {
            return ((c_MajorVersion & 0xff) << 24) | ((c_MinorVersion & 0xff)<< 16) | (c_TinyVersion & 0xffff);
        }
        
        static unsigned int BuildNumber()
        {
            return c_FrameworkBuildNumber;
        }
        
        static const string VersionString(bool withBuildNumber = false)
        {
            stringstream s;
            s << c_MajorVersion << "." << c_MinorVersion << "." << c_TinyVersion;
            if (withBuildNumber)
                s << "." << c_FrameworkBuildNumber;
                
            return s.str();
        }
        
        static const string VersionStringWithBuildNumber()
        {
            return VersionString(true);
        }
        
    protected:
        static const unsigned int c_MajorVersion;
        static const unsigned int c_MinorVersion;
        static const unsigned int c_TinyVersion;
        static const unsigned int c_FrameworkBuildNumber;        
    };
};

#endif
