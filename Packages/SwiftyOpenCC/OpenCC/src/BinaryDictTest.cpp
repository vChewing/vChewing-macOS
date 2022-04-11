/*
 * Open Chinese Convert
 *
 * Copyright 2015-2020 Carbo Kuo <byvoid@byvoid.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "BinaryDict.hpp"
#include "TextDictTestBase.hpp"

namespace opencc
{

class BinaryDictTest : public TextDictTestBase
{
  protected:
    BinaryDictTest() : binDict(new BinaryDict(textDict->GetLexicon())), fileName("dict.bin"){};

    const BinaryDictPtr binDict;
    const std::string fileName;
};

TEST_F(BinaryDictTest, Serialization)
{
    binDict->opencc::SerializableDict::SerializeToFile(fileName);
}

TEST_F(BinaryDictTest, Deserialization)
{
    const BinaryDictPtr &deserialized = SerializableDict::NewFromFile<BinaryDict>(fileName);
    const LexiconPtr &lex1 = binDict->GetLexicon();
    const LexiconPtr &lex2 = deserialized->GetLexicon();

    // Compare every entry
    EXPECT_EQ(lex1->Length(), lex2->Length());
    for (size_t i = 0; i < lex1->Length(); i++)
    {
        EXPECT_EQ(lex1->At(i)->Key(), lex2->At(i)->Key());
        EXPECT_EQ(lex1->At(i)->NumValues(), lex2->At(i)->NumValues());
    }

    const TextDictPtr deserializedTextDict(new TextDict(lex2));
    TestDict(deserializedTextDict);
}

} // namespace opencc
