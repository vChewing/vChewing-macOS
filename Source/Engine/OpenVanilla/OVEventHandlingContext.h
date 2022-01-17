/* 
 *  OVEventHandlingContext.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVEventHandlingContext_h
#define OVEventHandlingContext_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVBase.h>
    #include <OpenVanilla/OVCandidateService.h>
    #include <OpenVanilla/OVStringHelper.h>
    #include <OpenVanilla/OVTextBuffer.h>
    #include <OpenVanilla/OVKey.h>
    #include <OpenVanilla/OVLoaderService.h>
#else
    #include "OVBase.h"
    #include "OVCandidateService.h"
    #include "OVStringHelper.h"
    #include "OVTextBuffer.h"
    #include "OVKey.h"
    #include "OVLoaderService.h"
#endif

namespace OpenVanilla {
    using namespace std;
    
    class OVEventHandlingContext : public OVBase {
    public:
        virtual void startSession(OVLoaderService* loaderService)
        {
        }
        
        virtual void stopSession(OVLoaderService* loaderService)
        {
        }
        
        virtual void clear(OVLoaderService* loaderService)
        {
            stopSession(loaderService);
            startSession(loaderService);
        }
        
        virtual bool handleKey(OVKey* key, OVTextBuffer* readingText, OVTextBuffer* composingText, OVCandidateService* candidateService, OVLoaderService* loaderService)
        {
            return false;
        }
        
        virtual bool handleDirectText(const vector<string>& segments, OVTextBuffer* readingText, OVTextBuffer* composingText, OVCandidateService* candidateService, OVLoaderService* loaderService)
        {
            return handleDirectText(OVStringHelper::Join(segments), readingText, composingText, candidateService, loaderService);
        }
        
        virtual bool handleDirectText(const string&, OVTextBuffer* readingText, OVTextBuffer* composingText, OVCandidateService* candidateService, OVLoaderService* loaderService)
        {
            return false;
        }
        
        virtual void candidateCanceled(OVCandidateService* candidateService, OVTextBuffer* readingText, OVTextBuffer* composingText, OVLoaderService* loaderService)
        {
        }
        
        virtual bool candidateSelected(OVCandidateService* candidateService, const string& text, size_t index, OVTextBuffer* readingText, OVTextBuffer* composingText, OVLoaderService* loaderService)
        {
            return true;
        }
        
        virtual bool candidateNonPanelKeyReceived(OVCandidateService* candidateService, const OVKey* key, OVTextBuffer* readingText, OVTextBuffer* composingText, OVLoaderService* loaderService)
        {
            return false;
        }
        
        virtual const string filterText(const string& inputText, OVLoaderService* loaderService)
        {
            return inputText;
        }
    };
};

#endif
