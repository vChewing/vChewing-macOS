/* 
 *  Unigram.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef Unigram_h
#define Unigram_h

#include <vector>
#include "KeyValuePair.h"

namespace Taiyan {
    namespace Gramambular {
        class Unigram {
        public:
            Unigram();

            KeyValuePair keyValue;
            double score;
            
            bool operator==(const Unigram& inAnother) const;
            bool operator<(const Unigram& inAnother) const;
            
            static bool ScoreCompare(const Unigram& a, const Unigram& b);
        };

        inline ostream& operator<<(ostream& inStream, const Unigram& inGram)
        {
            streamsize p = inStream.precision();
            inStream.precision(6);
            inStream << "(" << inGram.keyValue << "," << inGram.score << ")";
            inStream.precision(p);
            return inStream;
        }
        
        inline ostream& operator<<(ostream& inStream, const vector<Unigram>& inGrams)
        {
            inStream << "[" << inGrams.size() << "]=>{";
            
            size_t index = 0;
            
            for (vector<Unigram>::const_iterator gi = inGrams.begin() ; gi != inGrams.end() ; ++gi, ++index) {
                inStream << index << "=>";
                inStream << *gi;
                if (gi + 1 != inGrams.end()) {
                    inStream << ",";
                }
            }
            
            inStream << "}";
            return inStream;
        }
        
        inline Unigram::Unigram()
            : score(0.0)
        {
        }
        
        inline bool Unigram::operator==(const Unigram& inAnother) const
        {
            return keyValue == inAnother.keyValue && score == inAnother.score;
        }
        
        inline bool Unigram::operator<(const Unigram& inAnother) const
        {
            if (keyValue < inAnother.keyValue) {
                return true;
            }
            else if (keyValue == inAnother.keyValue) {
                return score < inAnother.score;
            }
            return false;
        }

        inline bool Unigram::ScoreCompare(const Unigram& a, const Unigram& b)
        {
            return a.score > b.score;
        }
    }
}

#endif
