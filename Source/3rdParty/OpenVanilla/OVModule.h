/* 
 *  OVModule.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVModule_h
#define OVModule_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVEventHandlingContext.h>
    #include <OpenVanilla/OVKeyValueMap.h>
    #include <OpenVanilla/OVPathInfo.h>
#else
    #include "OVEventHandlingContext.h"
    #include "OVKeyValueMap.h"
    #include "OVPathInfo.h"
#endif

namespace OpenVanilla {
    using namespace std;
    
    class OVModule : public OVBase {
    public:
        OVModule() 
            : m_initialized(false)
            , m_usable(false)
        {
        }
        
        virtual bool isInitialized() const
        {
            return m_initialized;
        }
        
        virtual bool isUsable() const
        {
            return m_usable;
        }
        
        virtual bool isPreprocessor() const
        {
            return false;
        }
        
        virtual bool isInputMethod() const
        {
            return false;
        }
        
        virtual bool isOutputFilter() const
        {
            return false;
        }
        
        virtual bool isAroundFilter() const
        {
            return false;
        }
        
        // the smaller it gets, the closer the the filter gets to the commit event
        virtual int suggestedOrder() const
        {
            return 0;
        }
        
        virtual OVEventHandlingContext* createContext()
        {
            return 0;
        }
        
        virtual const string identifier() const = 0;
        
        virtual const string localizedName(const string& locale)
        {
            return identifier();

        }

        virtual bool moduleInitialize(OVPathInfo* pathInfo, OVLoaderService* loaderService)
        {
            if (m_initialized)
                return false;

            m_usable = initialize(pathInfo, loaderService);
            m_initialized = true;
            return m_usable;
        }

        virtual bool initialize(OVPathInfo* pathInfo, OVLoaderService* loaderService)
        {
            return true;
        }
    
        virtual void finalize()
        {
        }
    
        virtual void loadConfig(OVKeyValueMap* moduleConfig, OVLoaderService* loaderService)
        {
        }
        
        virtual void saveConfig(OVKeyValueMap* moduleConfig, OVLoaderService* loaderService)
        {
        }
        
        enum AroundFilterDisplayOption {
            ShownAsPreprocessor,
            ShownAsOutputFilter,
            ShownAsBoth
        };
 
        // around filter modules need to tell loader how it wishes to be placed in the menu
        virtual AroundFilterDisplayOption aroundFilterPreferredDisplayOption()
        {
            return ShownAsBoth;
        }
                
    protected:                
        bool m_initialized;
        bool m_usable;
    };    
};

#endif
