
#ifndef SOURCE_ENGINE_PARSELESSPHRASEDB_H_
#define SOURCE_ENGINE_PARSELESSPHRASEDB_H_

#include <cstddef>
#include <string>
#include <vector>

namespace vChewing {

// Defines phrase database that consists of (key, value, score) rows that are
// pre-sorted by the byte value of the keys. It is way faster than FastLM
// because it does not need to parse anything. Instead, it relies on the fact
// that the database is already sorted, and binary search is used to find the
// rows.
class ParselessPhraseDB {
public:
    ParselessPhraseDB(
        const char* buf, size_t length);

    // Find the rows that match the key. Note that prefix match is used. If you
    // need exact match, the key will need to have a delimiter (usually a space)
    // at the end.
    std::vector<std::string_view> findRows(const std::string_view& key);

    const char* findFirstMatchingLine(const std::string_view& key);

private:
    const char* begin_;
    const char* end_;
};

}; // namespace vChewing

#endif // SOURCE_ENGINE_PARSELESSPHRASEDB_H_
