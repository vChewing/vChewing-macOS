/*
 *  ParselessLM.h
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef SOURCE_ENGINE_PARSELESSLM_H_
#define SOURCE_ENGINE_PARSELESSLM_H_

#include <memory>
#include <string>
#include <vector>

#include "LanguageModel.h"
#include "ParselessPhraseDB.h"

namespace vChewing {

class ParselessLM : public Taiyan::Gramambular::LanguageModel {
public:
    ~ParselessLM() override;

    bool isLoaded();
    bool open(const std::string_view& path);
    void close();

    const std::vector<Taiyan::Gramambular::Bigram> bigramsForKeys(
        const std::string& preceedingKey, const std::string& key) override;
    const std::vector<Taiyan::Gramambular::Unigram> unigramsForKey(
        const std::string& key) override;
    bool hasUnigramsForKey(const std::string& key) override;

private:
    int fd_ = -1;
    void* data_ = nullptr;
    size_t length_ = 0;
    std::unique_ptr<ParselessPhraseDB> db_;
};

}; // namespace vChewing

#endif // SOURCE_ENGINE_PARSELESSLM_H_
