
#include "AssociatedPhrases.h"

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <fstream>
#include <unistd.h>

#include "KeyValueBlobReader.h"

namespace vChewing {

AssociatedPhrases::AssociatedPhrases()
: fd(-1)
, data(0)
, length(0)
{
}

AssociatedPhrases::~AssociatedPhrases()
{
    if (data) {
        close();
    }
}

const bool AssociatedPhrases::isLoaded()
{
    if (data) {
        return true;
    }
    return false;
}

bool AssociatedPhrases::open(const char *path)
{
    if (data) {
        return false;
    }

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
        keyRowMap[keyValue.key].emplace_back(keyValue.key, keyValue.value);
    }
    return true;
}

void AssociatedPhrases::close()
{
    if (data) {
        munmap(data, length);
        ::close(fd);
        data = 0;
    }

    keyRowMap.clear();
}

const std::vector<std::string> AssociatedPhrases::valuesForKey(const std::string& key)
{
    std::vector<std::string> v;
    auto iter = keyRowMap.find(key);
    if (iter != keyRowMap.end()) {
        const std::vector<Row>& rows = iter->second;
        for (const auto& row : rows) {
            std::string_view value = row.value;
            v.push_back({value.data(), value.size()});
        }
    }
    return v;
}

const bool AssociatedPhrases::hasValuesForKey(const std::string& key)
{
    return keyRowMap.find(key) != keyRowMap.end();
}

};  // namespace vChewing
