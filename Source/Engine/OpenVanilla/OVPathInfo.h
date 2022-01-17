/* 
 *  OVPathInfo.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVPathInfo_h
#define OVPathInfo_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVFileHelper.h>
#else
    #include "OVFileHelper.h"
#endif

namespace OpenVanilla {
    using namespace std;

    struct OVPathInfo {
        string loadedPath;
        string resourcePath;
        string writablePath;
        
        static const OVPathInfo DefaultPathInfo() {
            string tmpdir = OVDirectoryHelper::TempDirectory();
            OVPathInfo pathInfo;
            
            pathInfo.loadedPath = tmpdir;
            pathInfo.resourcePath = tmpdir;
            pathInfo.writablePath = tmpdir;
            return pathInfo;
        }
    };
    
    inline ostream& operator<<(ostream& stream, const OVPathInfo& info)
    {
        stream << "OVPathInfo = (loaded path = " << info.loadedPath << ", resource path = " << info.resourcePath << ", writable path = " << info.writablePath << ")";
        return stream;
    }
};

#endif
