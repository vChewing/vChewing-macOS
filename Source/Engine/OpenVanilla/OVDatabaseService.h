/* 
 *  OVDatabaseService.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVDatabaseService_h
#define OVDatabaseService_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVBase.h>
    #include <OpenVanilla/OVCINDataTable.h>
    #include <OpenVanilla/OVFileHelper.h>
    #include <OpenVanilla/OVWildcard.h>
#else
    #include "OVBase.h"
    #include "OVCINDataTable.h"
    #include "OVFileHelper.h"
    #include "OVWildcard.h"
#endif

#include <map>

namespace OpenVanilla {
    using namespace std;

    // database-backed table uses this prefix to store properties ina key-value data table
    #define OVPropertyStringInternalPrefix "__property_"

    #define OVCINKeynameString "keyname-"
    #define OVCINKeynameStringLength 8

    // keyname is defined in the .cin format, not to be confused with the key in key-value pairs
    class OVKeynamePropertyHelper : public OVBase {
    public:
        static bool IsPropertyKeyname(const string& property)
        {
            return (property.substr(0, OVCINKeynameStringLength) == OVCINKeynameString);
        }
        
        // passes property and gets back the keyname
        static const string KeynameFromProperty(const string& property)
        {
            return IsPropertyKeyname(property) ? property.substr(OVCINKeynameStringLength, property.length() - OVCINKeynameStringLength) : string();
        }
        
        // passes keyname and gets the combined property
        static const string KeynameToProperty(const string& keyname)
        {
            return string(OVCINKeynameString) + keyname;
        }
    };

    class OVKeyValueDataTableInterface : public OVBase {
    public:
        virtual const vector<string> valuesForKey(const string& key) = 0;
        virtual const vector<pair<string, string> > valuesForKey(const OVWildcard& expression) = 0;
        virtual const string valueForProperty(const string& property) = 0;
        
        // only supported by database services that support value-to-key lookup, the default implementation is an empty vector<string>
        virtual const vector<string> keysForValue(const string& value)
        {
            return vector<string>();
        }
    };

    class OVDatabaseService : public OVBase {
    public:
        virtual const vector<string> tables(const OVWildcard& filter = string("*")) = 0;
        virtual bool tableSupportsValueToKeyLookup(const string &tableName) = 0;
        
        virtual OVKeyValueDataTableInterface* createKeyValueDataTableInterface(const string& name, bool suggestedCaseSensitivity = false) = 0;
        
        // this is needed so that modules like OVIMGeneric can know table localized names in advance, without really loading them
        virtual const string valueForPropertyInTable(const string& property, const string& name) = 0;
    };

};

#endif
