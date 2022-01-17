/* 
 *  OVKeyValueMap.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVKeyValueMap_h
#define OVKeyValueMap_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVBase.h>
#else
    #include "OVBase.h"
#endif

#include <sstream>

namespace OpenVanilla {
    using namespace std;
    
    class OVKeyValueMapInterface : public OVBase {
    public:
        virtual bool isReadOnly() = 0;
        virtual bool setKeyStringValue(const string& key, const string& value) = 0;
        virtual bool hasKey(const string& key) = 0;
        virtual const string stringValueForKey(const string& key) = 0;
        
        virtual bool setKeyIntValue(const string& key, int value)
        {
            stringstream sstr;
            sstr << value;
            return setKeyStringValue(key, sstr.str());
        }
        
        virtual bool setKeyBoolValue(const string& key, bool value)
        {
            if (value)
                return setKeyStringValue(key, "true");
            
            return setKeyStringValue(key, "false");
        }
        
        virtual int intValueForKey(const string& key)
        {
            string value = stringValueForKey(key);
            return atoi(value.c_str());
        }
        
        virtual const string stringValueForKeyWithDefault(const string& key, const string& defaultValue = "", bool setIfNotFound = true)
        {
            if (hasKey(key))
                return stringValueForKey(key);
            
            if (setIfNotFound)
                setKeyStringValue(key, defaultValue);
            
            return defaultValue;
        }
        
        virtual const string operator[](const string& key)
        {
            return stringValueForKey(key);
        }
        
        virtual bool isKeyTrue(const string& key)
        {
            if (!hasKey(key))
                return false;
              
            string value = stringValueForKey(key);
            
            if (atoi(value.c_str()) > 0)
                return true;
                
            if (value == "true")
                return true;
            
            return false;
        }
    };
    
    class OVKeyValueMapImpl : public OVKeyValueMapInterface {
    public:
        virtual bool shouldDelete() = 0;
        virtual OVKeyValueMapImpl* copy() = 0;
    };
        
    class OVKeyValueMap : public OVKeyValueMapInterface {
    public:
        OVKeyValueMap(OVKeyValueMapImpl* keyValueMapImpl = 0)
            : m_keyValueMapImpl(keyValueMapImpl)
        {
        }
        
        OVKeyValueMap(const OVKeyValueMap& aKeyValueMap)
        {
            m_keyValueMapImpl = aKeyValueMap.m_keyValueMapImpl ? aKeyValueMap.m_keyValueMapImpl->copy() : 0;
        }
        
        ~OVKeyValueMap()
        {
            if (m_keyValueMapImpl) {
                if (m_keyValueMapImpl->shouldDelete()) {
                    delete m_keyValueMapImpl;
                }                
            }
        }
        
        OVKeyValueMap& operator=(const OVKeyValueMap& aKeyValueMap)
        {
            if (m_keyValueMapImpl) {
                if (m_keyValueMapImpl->shouldDelete()) {
                    delete m_keyValueMapImpl;
                }             
				
				m_keyValueMapImpl = 0;
            }

            m_keyValueMapImpl = aKeyValueMap.m_keyValueMapImpl ? aKeyValueMap.m_keyValueMapImpl->copy() : 0;
            return *this;
        }

    public:
        virtual bool isReadOnly()
        {
            return m_keyValueMapImpl ? m_keyValueMapImpl->isReadOnly() : true;
        }
        
        virtual bool setKeyStringValue(const string& key, const string& value)
        {
            return m_keyValueMapImpl ? m_keyValueMapImpl->setKeyStringValue(key, value) : false;
        }
        
        virtual bool hasKey(const string& key)
        {
            return m_keyValueMapImpl ? m_keyValueMapImpl->hasKey(key) : false;
        }
        
        virtual const string stringValueForKey(const string& key)
        {
            return m_keyValueMapImpl ? m_keyValueMapImpl->stringValueForKey(key) : string();
        }
        
        virtual const string stringValueForKeyWithDefault(const string& key, const string& defaultValue = "", bool setIfNotFound = true)
        {
            return m_keyValueMapImpl ? m_keyValueMapImpl->stringValueForKeyWithDefault(key, defaultValue, setIfNotFound) : string();
        }
        
    protected:
        OVKeyValueMapImpl* m_keyValueMapImpl;
    };
};

#endif
