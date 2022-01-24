/* 
 *  OVEncodingService.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVEncodingService_h
#define OVEncodingService_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVUTF8Helper.h>
#else
    #include "OVUTF8Helper.h"
#endif

namespace OpenVanilla {
    using namespace std;

    class OVEncodingService : public OVBase {
    public:
        virtual bool stringSupportedByEncoding(const string& text, const string& encoding)
        {
            vector<string> svec = OVUTF8Helper::SplitStringByCodePoint(text);
            for (vector<string>::iterator iter = svec.begin() ; iter != svec.end() ; ++iter)
                if (!codepointSupportedByEncoding(*iter, encoding))
                    return false;
                    
            return true;
        }

        virtual bool stringSupportedBySystem(const string& text)
        {
            vector<string> svec = OVUTF8Helper::SplitStringByCodePoint(text);
            for (vector<string>::iterator iter = svec.begin() ; iter != svec.end() ; ++iter)
                if (!codepointSupportedBySystem(*iter))
                    return false;
                    
            return true;
        }        
        
        virtual bool codepointSupportedByEncoding(const string& codepoint, const string& encoding) = 0;
        virtual bool codepointSupportedBySystem(const string& codepoint) = 0;        
        virtual const vector<string> supportedEncodings() = 0;
        virtual bool isEncodingSupported(const string& encoding) = 0;

        virtual bool isEncodingConversionSupported(const string& fromEncoding, const string& toEncoding) = 0;
        virtual const pair<bool, string> convertEncoding(const string& fromEncoding, const string& toEncoding, const string& text) = 0;
    };
};

#endif