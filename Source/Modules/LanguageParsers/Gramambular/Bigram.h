/* 
 *  Bigram.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef Bigram_h
#define Bigram_h

#include <vector>

#include "KeyValuePair.h"

namespace Taiyan {
    namespace Gramambular {
        class Bigram {
        public:
            Bigram();
            
            KeyValuePair preceedingKeyValue;
            KeyValuePair keyValue;
            double score;
            
            bool operator==(const Bigram& inAnother) const;
            bool operator<(const Bigram& inAnother) const;                        
        };

        inline ostream& operator<<(ostream& inStream, const Bigram& inGram)
        {
            streamsize p = inStream.precision();
            inStream.precision(6);
            inStream << "(" << inGram.keyValue << "|" <<inGram.preceedingKeyValue  << "," << inGram.score << ")";
            inStream.precision(p);
            return inStream;
        }

        inline ostream& operator<<(ostream& inStream, const vector<Bigram>& inGrams)
        {
            inStream << "[" << inGrams.size() << "]=>{";
            
            size_t index = 0;
            
            for (vector<Bigram>::const_iterator gi = inGrams.begin() ; gi != inGrams.end() ; ++gi, ++index) {
                inStream << index << "=>";
                inStream << *gi;
                if (gi + 1 != inGrams.end()) {
                    inStream << ",";
                }
            }
            
            inStream << "}";
            return inStream;
        }
        
        inline Bigram::Bigram()
            : score(0.0)
        {
        }
        
        inline bool Bigram::operator==(const Bigram& inAnother) const
        {
            return preceedingKeyValue == inAnother.preceedingKeyValue && keyValue == inAnother.keyValue && score == inAnother.score;
        }
        
        inline bool Bigram::operator<(const Bigram& inAnother) const
        {
            if (preceedingKeyValue < inAnother.preceedingKeyValue) {
                return true;
            }
            else if (preceedingKeyValue == inAnother.preceedingKeyValue) {            
                if (keyValue < inAnother.keyValue) {
                    return true;
                }
                else if (keyValue == inAnother.keyValue) {
                    return score < inAnother.score;
                }
                return false;
            }

            return false;
        }        
    }
}

#endif
