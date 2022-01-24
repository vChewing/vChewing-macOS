/* 
 *  OVLocalization.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVLocalization_h
#define OVLocalization_h

#include <string>
#include <map>
#include "OVStringHelper.h"
#include "OVWildcard.h"

namespace OpenVanilla {
    using namespace std;
    
    class OVLocale {
    public:
        static const string POSIXLocaleID(const string& locale)
        {
            string n = OVStringHelper::StringByReplacingOccurrencesOfStringWithString(locale, "-", "_");
            
            if (OVWildcard::Match(n, "zh_Hant")) {
                return "zh_TW";
            }
            
            if (OVWildcard::Match(n, "zh_Hans")) {
                return "zh_CN";
            }
            
            if (OVWildcard::Match(n, "zh_HK")) {
                return "zh_TW";
            }

            if (OVWildcard::Match(n, "zh_SG")) {
                return "zh_CN";
            }

            if (OVWildcard::Match(n, "en_*")) {
                return "en";
            }
            
            return locale;
        }
    };


    template<class T> class OVLocalization {
    public:
        static const void SetDefaultLocale(const string& locale)
        {
            SharedInstance()->m_defaultLocale = locale.length() ? OVLocale::POSIXLocaleID(locale) : string("en");
        }
        
        static const string S(const string& locale, const string& text)
        {
            return SharedInstance()->m_table(locale, text);
        }

        static const string S(const string& text)
        {
            return SharedInstance()->m_table(SharedInstance()->m_defaultLocale, text);
        }
        
    protected:
        static OVLocalization<T>* SharedInstance()
        {
            static OVLocalization<T>* instance = 0;
            if (!instance) {
                instance = new OVLocalization<T>;
            }
            
            return instance;
        }
        
        OVLocalization<T>()
            : m_defaultLocale("en")
        {        
        }        
        
        T m_table;
        string m_defaultLocale;
    };

    class OVLocalizationStringTable {
    public:
        const string operator()(const string& locale, const string& text) const
        {
            // maybe we'll have fallback logic later here
            map<string, map<string, string> >::const_iterator i = m_table.find(locale);
            if (i == m_table.end()) {
                return text;
            }
            
            map<string, string>::const_iterator j = (*i).second.find(text);
            if (j == (*i).second.end()) {
                return text;
            }
            
            return (*j).second;
        }
        
        
    protected:
        void add(const string& locale, const string& original, const string& localized)
        {
            m_table[locale][original] = localized;
        }
        
        map<string, map<string, string> > m_table;
    };
};

#endif