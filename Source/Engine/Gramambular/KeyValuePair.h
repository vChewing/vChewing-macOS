/* 
 *  KeyValuePair.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef KeyValuePair_h
#define KeyValuePair_h

#include <ostream>
#include <string>

namespace Formosa {
  namespace Gramambular {
      using namespace std;
      
      class KeyValuePair {
      public:
          string key;
          string value;

          bool operator==(const KeyValuePair& inAnother) const;
          bool operator<(const KeyValuePair& inAnother) const;
      };

      inline ostream& operator<<(ostream& inStream, const KeyValuePair& inPair)
      {
          inStream << "(" << inPair.key << "," << inPair.value << ")";
          return inStream;
      }
      
      inline bool KeyValuePair::operator==(const KeyValuePair& inAnother) const
      {
          return key == inAnother.key && value == inAnother.value;
      }

      inline bool KeyValuePair::operator<(const KeyValuePair& inAnother) const
      {
          if (key < inAnother.key) {
              return true;
          }
          else if (key == inAnother.key) {
              return value < inAnother.value;
          }
          return false;
      }      
  }
}

#endif
