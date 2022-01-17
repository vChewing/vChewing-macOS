/* 
 *  OVCINDatabaseService.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVCINDatabaseService_h
#define OVCINDatabaseService_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVCINDataTable.h>
    #include <OpenVanilla/OVDatabaseService.h>    
#else
    #include "OVCINDataTable.h"
    #include "OVDatabaseService.h"
#endif

namespace OpenVanilla {
    using namespace std;

    class OVCINDatabaseService;
    
    class OVCINKeyValueDataTable : public OVKeyValueDataTableInterface
    {
    public:
        ~OVCINKeyValueDataTable()
        {
            delete m_table;
        }
        
        virtual const vector<string> valuesForKey(const string& key)
        {
            return m_table->findChardef(key);
        }
        
        virtual const vector<pair<string, string> > valuesForKey(const OVWildcard& expression)
        {
            return m_table->findChardefWithWildcard(expression);
        }
        
        virtual const string valueForProperty(const string& property)
        {
            if (OVKeynamePropertyHelper::IsPropertyKeyname(property))
                return m_table->findKeyname(OVKeynamePropertyHelper::KeynameFromProperty(property));
            else
                return m_table->findProperty(property);
        }
                
    protected:
        OVCINDataTable* m_table;
        
        friend class OVCINDatabaseService;
        
        OVCINKeyValueDataTable(OVCINDataTable* table)
            : m_table(table)
        {
        }
    };
    

    class OVCINDatabaseService : public OVDatabaseService {
    public:
        OVCINDatabaseService()
        {
        }
        
        OVCINDatabaseService(const string& pathToScan, const string& includePattern = "*.cin", const string& excludePattern = "", size_t depth = 1)
        {
            addDirectory(pathToScan, includePattern, excludePattern, depth);
        }

        // note addDirectory overwrites the table data, so scan user directory after scan the systems if you want to give precedence to user' tables
        void addDirectory(const string& pathToScan, const string& includePattern = "*.cin", const string& excludePattern = "", size_t depth = 1)
        {
            string pathPrefix = OVPathHelper::NormalizeByExpandingTilde(pathToScan) + OVPathHelper::Separator();
            size_t prefixLength = pathPrefix.length();
            
            vector<string> tables = OVDirectoryHelper::Glob(pathPrefix, includePattern, excludePattern, depth);
            
            vector<string>::iterator iter = tables.begin();
            for ( ; iter != tables.end(); ++iter) {
                const string& path = *iter;
                string shortPath = *iter;                
                shortPath.erase(0, prefixLength);
                
                string tableName = OVCINDatabaseService::TableNameFromPath(shortPath);
                m_tables[tableName] = path;
            }
        }

        virtual const vector<string> tables(const OVWildcard& filter = string("*"))
        {
            vector<string> result;
            
            for (map<string, string>::iterator iter = m_tables.begin() ; iter != m_tables.end(); ++iter) {
                if (filter.match((*iter).first))
                    result.push_back((*iter).first);
            }
            
            return result;
        }
        
        virtual bool tableSupportsValueToKeyLookup(const string &tableName)
        {
            return false;
        }        
        
        virtual OVKeyValueDataTableInterface* createKeyValueDataTableInterface(const string& name, bool suggestedCaseSensitivity = false)
        {
            map<string, string>::iterator iter = m_tables.find(name);
            if (iter == m_tables.end())
                return 0;
            
            OVCINDataTableParser parser;
            OVCINDataTable* table = parser.CINDataTableFromFileName((*iter).second, suggestedCaseSensitivity);
            
            if (!table)
                return 0;

            return new OVCINKeyValueDataTable(table);
        }


        virtual const string valueForPropertyInTable(const string& property, const string& name)
        {
            map<string, string>::iterator iter;
            
            if (name != m_cachedTableName)
            {                
                iter = m_tables.find(name);
                if (iter == m_tables.end())
                    return string();
                    
                m_cachedProperties = OVCINDataTableParser::QuickParseProperty((*iter).second);
                m_cachedTableName = name;
            }
            
            iter = m_cachedProperties.find(property);
            if (iter != m_cachedProperties.end())
                return (*iter).second;
                
            return string();
        }
        
    protected:
        map<string, string> m_tables;
        map<string, string> m_cachedProperties;
        string m_cachedTableName;
                
    public:
        static const string TableNameFromPath(const string& path)
        {
            string result;
            char separator = OVPathHelper::Separator();
            
            string::const_iterator iter = path.begin();
            for ( ; iter != path.end(); ++iter)
                if (*iter == separator || *iter == '.')
                    result += '-';
                else
                    result += *iter;
                    
            return result;
        }
    };    
};

#endif