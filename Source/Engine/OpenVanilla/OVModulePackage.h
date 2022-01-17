/* 
 *  OVModulePackage.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVModulePackage_h
#define OVModulePackage_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVFrameworkInfo.h>
    #include <OpenVanilla/OVModule.h>
#else
    #include "OVFrameworkInfo.h"
    #include "OVModule.h"
#endif

#ifdef WIN32
	#define OVEXPORT __declspec(dllexport)
#else
	#define OVEXPORT
#endif

namespace OpenVanilla {
    using namespace std;
    
    class OVModuleClassWrapperBase : public OVBase {
    public:
        virtual OVModule* newModule()
		{
			// this member function can't be abstract, or vector<OVModuleClassWrapperBase> wouldn't instantiate under VC++ 2005
			return 0;
		}
    };
    
    template<class T> class OVModuleClassWrapper : public OVModuleClassWrapperBase {
    public:
        virtual OVModule* newModule()
        {
            return new T;
        }        
    };
    
    // we encourage people to do the real initialization in initialize
    class OVModulePackage : OVBase {
    public:
        ~OVModulePackage()
        {
            vector<OVModuleClassWrapperBase*>::iterator iter = m_moduleVector.begin();
            for ( ; iter != m_moduleVector.end(); ++iter)
                delete *iter;
        }
        virtual bool initialize(OVPathInfo* , OVLoaderService* loaderService)
        {
            // in your derived class, add class wrappers to m_moduleVector
            return true;
        }
        
        virtual void finalize()
        {
        }
        
        virtual size_t numberOfModules(OVLoaderService*)
        {
            return m_moduleVector.size();
        }
        
        virtual OVModule* moduleAtIndex(size_t index, OVLoaderService*)
        {
            if (index > m_moduleVector.size()) return 0;
            return m_moduleVector[index]->newModule();
        }
    
    protected:
        vector<OVModuleClassWrapperBase*> m_moduleVector;
    };
};

#endif
