/* 
 *  UserPhrasesLM.mm
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#include "UserPhrasesLM.h"
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <fstream>
#include <unistd.h>
#include <syslog.h>
#include "LMConsolidator.h"
#include "KeyValueBlobReader.h"

namespace vChewing {

UserPhrasesLM::UserPhrasesLM()
    : fd(-1)
    , data(0)
    , length(0)
{
}

UserPhrasesLM::~UserPhrasesLM()
{
    if (data) {
        close();
    }
}

bool UserPhrasesLM::open(const char *path)
{
    if (data) {
        return false;
    }

    LMConsolidator::FixEOF(path);
    LMConsolidator::ConsolidateContent(path, false);

    fd = ::open(path, O_RDONLY);
    if (fd == -1) {
        printf("open:: file not exist");
        return false;
    }

    struct stat sb;
    if (fstat(fd, &sb) == -1) {
        printf("open:: cannot open file");
        return false;
    }

    length = (size_t)sb.st_size;

    data = mmap(NULL, length, PROT_READ, MAP_SHARED, fd, 0);
    if (!data) {
        ::close(fd);
        return false;
    }

    KeyValueBlobReader reader(static_cast<char*>(data), length);
    KeyValueBlobReader::KeyValue keyValue;
    KeyValueBlobReader::State state;
    while ((state = reader.Next(&keyValue)) == KeyValueBlobReader::State::HAS_PAIR) {
        // We invert the key and value, since in user phrases, "key" is the phrase value, and "value" is the BPMF reading.
        keyRowMap[keyValue.value].emplace_back(keyValue.value, keyValue.key);
    }
	// 下面這一段或許可以做成開關、來詢問是否對使用者語彙採取寬鬆策略（哪怕有行內容寫錯也會放行）
    if (state == KeyValueBlobReader::State::ERROR) {
        close();
        return false;
    }
    return true;
}

void UserPhrasesLM::close()
{
    if (data) {
        munmap(data, length);
        ::close(fd);
        data = 0;
    }

    keyRowMap.clear();
}

void UserPhrasesLM::dump()
{
    for (const auto& entry : keyRowMap) {
        const std::vector<Row>& rows = entry.second;
        for (const auto& row : rows) {
            std::cerr << row.key << " " << row.value << "\n";
        }
    }
}

const std::vector<Taiyan::Gramambular::Bigram> UserPhrasesLM::bigramsForKeys(const std::string& preceedingKey, const std::string& key)
{
    return std::vector<Taiyan::Gramambular::Bigram>();
}

const std::vector<Taiyan::Gramambular::Unigram> UserPhrasesLM::unigramsForKey(const std::string& key)
{
    std::vector<Taiyan::Gramambular::Unigram> v;
    auto iter = keyRowMap.find(key);
    if (iter != keyRowMap.end()) {
        const std::vector<Row>& rows = iter->second;
        for (const auto& row : rows) {
            Taiyan::Gramambular::Unigram g;
            g.keyValue.key = row.key;
            g.keyValue.value = row.value;
            g.score = 0.0;
            v.push_back(g);
        }
    }

    return v;
}

bool UserPhrasesLM::hasUnigramsForKey(const std::string& key)
{
    return keyRowMap.find(key) != keyRowMap.end();
}

};  // namespace vChewing
