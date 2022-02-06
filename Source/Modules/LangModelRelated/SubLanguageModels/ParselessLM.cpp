/*
 *  ParselessLM.cpp
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#include "ParselessLM.h"

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <memory>

vChewing::ParselessLM::~ParselessLM() { close(); }

bool vChewing::ParselessLM::isLoaded()
{
    if (data_) {
        return true;
    }
    return false;
}

bool vChewing::ParselessLM::open(const std::string_view& path)
{
    if (data_) {
        return false;
    }

    fd_ = ::open(path.data(), O_RDONLY);
    if (fd_ == -1) {
        return false;
    }

    struct stat sb;
    if (fstat(fd_, &sb) == -1) {
        ::close(fd_);
        fd_ = -1;
        return false;
    }

    length_ = static_cast<size_t>(sb.st_size);

    data_ = mmap(NULL, length_, PROT_READ, MAP_SHARED, fd_, 0);
    if (data_ == nullptr) {
        ::close(fd_);
        fd_ = -1;
        length_ = 0;
        return false;
    }

    db_ = std::unique_ptr<ParselessPhraseDB>(new ParselessPhraseDB(
        static_cast<char*>(data_), length_));
    return true;
}

void vChewing::ParselessLM::close()
{
    if (data_ != nullptr) {
        munmap(data_, length_);
        ::close(fd_);
        fd_ = -1;
        length_ = 0;
        data_ = nullptr;
    }
}

const std::vector<Taiyan::Gramambular::Bigram>
vChewing::ParselessLM::bigramsForKeys(
    const std::string& preceedingKey, const std::string& key)
{
    return std::vector<Taiyan::Gramambular::Bigram>();
}

const std::vector<Taiyan::Gramambular::Unigram>
vChewing::ParselessLM::unigramsForKey(const std::string& key)
{
    if (db_ == nullptr) {
        return std::vector<Taiyan::Gramambular::Unigram>();
    }

    std::vector<Taiyan::Gramambular::Unigram> results;
    for (const auto& row : db_->findRows(key + " ")) {
        Taiyan::Gramambular::Unigram unigram;

        // Move ahead until we encounter the first space. This is the key.
        auto it = row.begin();
        while (it != row.end() && *it != ' ') {
            ++it;
        }

        unigram.keyValue.key = std::string(row.begin(), it);

        // Read past the space.
        if (it != row.end()) {
            ++it;
        }

        if (it != row.end()) {
            // Now it is the start of the value portion.
            auto value_begin = it;

            // Move ahead until we encounter the second space. This is the
            // value.
            while (it != row.end() && *it != ' ') {
                ++it;
            }
            unigram.keyValue.value = std::string(value_begin, it);
        }

        // Read past the space. The remainder, if it exists, is the score.
        if (it != row.end()) {
            ++it;
        }

        if (it != row.end()) {
            unigram.score = std::stod(std::string(it, row.end()));
        }
        results.push_back(unigram);
    }
    return results;
}

bool vChewing::ParselessLM::hasUnigramsForKey(const std::string& key)
{
    if (db_ == nullptr) {
        return false;
    }

    return db_->findFirstMatchingLine(key + " ") != nullptr;
}
