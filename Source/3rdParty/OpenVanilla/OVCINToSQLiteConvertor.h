/* 
 *  OVCINToSQLiteConvertor.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVCINToSQLiteConvertor_h
#define OVCINToSQLiteConvertor_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVCINDataTable.h>
    #include <OpenVanilla/OVSQLiteWrapper.h>
#else
    #include "OVCINDataTable.h"
    #include "OVSQLiteWrapper.h"
#endif

namespace OpenVanilla {
    using namespace std;

    class OVCINToSQLiteConvertor {
    protected:
        static bool InsertKeyValue(OVFastKeyValuePairMap* map, OVSQLiteStatement* statement, const char* prefix = 0)
        {
            string prefixString = prefix ? prefix : "";

            size_t size = map->size();
            
            for (size_t index = 0; index < size; index++) {
                pair<string, string> kvpair = map->keyValuePairAtIndex(index);
                
                const string& key = prefix ? prefixString + kvpair.first : kvpair.first;
                
                statement->bindTextToColumn(key, 1);
                statement->bindTextToColumn(kvpair.second, 2);
                
                if (statement->step() != SQLITE_DONE)
                    return false;
                
                statement->reset();
            }
            
            return true;
        }
        
    public:
        static bool Convert(OVCINDataTable* table, OVSQLiteConnection* connection, const string& tableName, bool overwriteTable = true)
        {
            const char* nameStr = tableName.c_str();
            // query if the table exists
            OVSQLiteStatement* statement;
            
            statement = connection->prepare("SELECT name FROM sqlite_master WHERE name = %Q", nameStr);
            
            if (!statement)
                return false;
                
            if (statement->step() == SQLITE_ROW && overwriteTable)
            {
                delete statement;
                
                if (connection->execute("DROP TABLE %Q", nameStr) != SQLITE_OK) {
                    delete statement;
                    return false;
                }
            }
            else            
                delete statement;
            
            if (connection->execute("CREATE TABLE %Q (key, value)", nameStr) != SQLITE_OK)
                return false;
            
            string indexName = tableName + "_index";
            if (connection->execute("CREATE INDEX %Q on %Q (key)", indexName.c_str(), nameStr) != SQLITE_OK)
                return false;
            
            statement = connection->prepare("INSERT INTO %Q VALUES (?, ?)", nameStr);
            if (!statement) {
                return false;
            }
                
            if (connection->execute("BEGIN") != SQLITE_OK) {
                return false;
            }
            
            string keynameProperty = string(OVPropertyStringInternalPrefix) + string(OVCINKeynameString);
            
            if (InsertKeyValue(table->propertyMap(), statement, OVPropertyStringInternalPrefix))
                if (InsertKeyValue(table->keynameMap(), statement, keynameProperty.c_str()))
                    InsertKeyValue(table->chardefMap(), statement);
                    
            delete statement;
            
            if (connection->execute("COMMIT") != SQLITE_OK) {
                return false;                                
            }
            
            return true;
        }
        
    };
};

#endif