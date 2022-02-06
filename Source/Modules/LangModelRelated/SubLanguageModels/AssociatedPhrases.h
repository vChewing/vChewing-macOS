
#ifndef ASSOCIATEDPHRASES_H
#define ASSOCIATEDPHRASES_H

#include <string>
#include <map>
#include <iostream>
#include <vector>

namespace vChewing {

class AssociatedPhrases
{
public:
    AssociatedPhrases();
    ~AssociatedPhrases();

    const bool isLoaded();
    bool open(const char *path);
    void close();
    const std::vector<std::string> valuesForKey(const std::string& key);
    const bool hasValuesForKey(const std::string& key);

protected:
    struct Row {
        Row(std::string_view& k, std::string_view& v) : key(k), value(v) {}
        std::string_view key;
        std::string_view value;
    };

    std::map<std::string_view, std::vector<Row>> keyRowMap;

    int fd;
    void *data;
    size_t length;
};

}

#endif /* AssociatedPhrases_hpp */
