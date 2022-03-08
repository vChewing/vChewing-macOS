// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "CoreLM.h"
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <fstream>
#include <unistd.h>
#include <syslog.h>

using namespace Gramambular;

vChewing::CoreLM::CoreLM()
    : fd(-1)
    , data(0)
    , length(0)
{
}

vChewing::CoreLM::~CoreLM()
{
    if (data) {
        close();
    }
}

bool vChewing::CoreLM::isLoaded()
{
    if (data) {
        return true;
    }
    return false;
}

bool vChewing::CoreLM::open(const char *path)
{
    if (data) {
        return false;
    }
    
    fd = ::open(path, O_RDONLY);
    if (fd == -1) {
        return false;
    }

    struct stat sb;
    if (fstat(fd, &sb) == -1) {
        return false;
    }

    length = (size_t)sb.st_size;

    data = mmap(NULL, length, PROT_WRITE, MAP_PRIVATE, fd, 0);
    if (!data) {
        ::close(fd);
        return false;
    }

    // Regular expression for parsing:
    //   (\n*\w\w*\s\w\w*\s\w\w*)*$
    //
    // Expanded as DFA (in Graphviz):
    //
    // digraph finite_state_machine {
    //  rankdir = LR;
    //  size = "10";
    //
    //  node [shape = doublecircle]; End;
    //  node [shape = circle];
    //
    //  Start -> End    [ label = "EOF"];
    //  Start -> Error  [ label = "\\s" ];
    //  Start -> Start  [ label = "\\n" ];
    //  Start -> 1      [ label = "\\w" ];
    //
    //  1 -> Error      [ label = "\\n, EOF" ];
    //  1 -> 2          [ label = "\\s" ];
    //  1 -> 1          [ label = "\\w" ];
    //
    //  2 -> Error      [ label = "\\n, \\s, EOF" ];
    //  2 -> 3          [ label = "\\w" ];
    //
    //  3 -> Error      [ label = "\\n, EOF "];
    //  3 -> 4          [ label = "\\s" ];
    //  3 -> 3          [ label = "\\w" ];
    //
    //  4 -> Error      [ label = "\\n, \\s, EOF" ];
    //  4 -> 5          [ label = "\\w" ];
    //
    //  5 -> Error      [ label = "\\s, EOF" ];
    //  5 -> Start      [ label = "\\n" ];
    //  5 -> 5          [ label = "\\w" ];
    // }

    char *head = (char *)data;
    char *end = (char *)data + length;
    char c;
    Row row;

start:
    // EOF -> end
    if (head == end) {
        goto end;
    }

    c = *head;
    // \s -> error
    if (c == ' ') {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // Start: \\s -> error");
        goto error;
    }
    // \n -> start
    else if (c == '\n') {
        head++;
        goto start;
    }

    // \w -> record column star, state1
    row.value = head;
    head++;
    // fall through to state 1

state1:
    // EOF -> error
    if (head == end) {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 1: EOF -> error");
        goto error;
    }

    c = *head;
    // \n -> error
    if (c == '\n') {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 1: \\n -> error");
        goto error;
    }
    // \s -> state2 + zero out ending + record column start
    else if (c == ' ') {
        *head = 0;
        head++;
        row.key = head;
        goto state2;
    }

    // \w -> state1
    head++;
    goto state1;

state2:
    // eof -> error
    if (head == end) {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 2: EOF -> error");
        goto error;
    }

    c = *head;
    // \n, \s -> error
    if (c == '\n' || c == ' ') {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 2: \\n \\s -> error");
        goto error;
    }

    // \w -> state3
    head++;

    // fall through to state 3

state3:
    // eof -> error
    if (head == end) {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 3: EOF -> error");
        goto error;
    }

    c = *head;

    // \n -> error
    if (c == '\n') {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 3: \\n -> error");
        goto error;
    }
    // \s -> state4 + zero out ending + record column start
    else if (c == ' ') {
        *head = 0;
        head++;
        row.logProbability = head;
        goto state4;
    }

    // \w -> state3
    head++;
    goto state3;

state4:
    // eof -> error
    if (head == end) {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 4: EOF -> error");
        goto error;
    }

    c = *head;
    // \n, \s -> error
    if (c == '\n' || c == ' ') {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 4: \\n \\s -> error");
        goto error;
    }

    // \w -> state5
    head++;

    // fall through to state 5


state5:
    // eof -> error
    if (head == end) {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 5: EOF -> error");
        goto error;
    }

    c = *head;
    // \s -> error
    if (c == ' ') {
        syslog(LOG_CONS, "vChewingDebug: CoreLM // state 5: \\s -> error");
        goto error;
    }
    // \n -> start
    else if (c == '\n') {
        *head = 0;
        head++;
        keyRowMap[row.key].push_back(row);
        goto start;
    }

    // \w -> state 5
    head++;
    goto state5;

error:
    close();
    return false;

end:
    static const char *space = " ";
    static const char *zero = "0.0";
    Row emptyRow;
    emptyRow.key = space;
    emptyRow.value = space;
    emptyRow.logProbability = zero;
    keyRowMap[space].push_back(emptyRow);
    syslog(LOG_CONS, "vChewingDebug: CoreLM // File Load Complete.");
    return true;
}

void vChewing::CoreLM::close()
{
    if (data) {
        munmap(data, length);
        ::close(fd);
        data = 0;
    }

    keyRowMap.clear();
}

void vChewing::CoreLM::dump()
{
    size_t rows = 0;
    for (map<const char *, vector<Row> >::const_iterator i = keyRowMap.begin(), e = keyRowMap.end(); i != e; ++i) {
        const vector<Row>& r = (*i).second;
        for (vector<Row>::const_iterator ri = r.begin(), re = r.end(); ri != re; ++ri) {
            const Row& row = *ri;
            cerr << row.key << " " << row.value << " " << row.logProbability << "\n";
            rows++;
        }
    }
}

const std::vector<Gramambular::Bigram> vChewing::CoreLM::bigramsForKeys(const string& preceedingKey, const string& key)
{
    return std::vector<Gramambular::Bigram>();
}

const std::vector<Gramambular::Unigram> vChewing::CoreLM::unigramsForKey(const string& key)
{
    std::vector<Gramambular::Unigram> v;
    map<const char *, vector<Row> >::const_iterator i = keyRowMap.find(key.c_str());

    if (i != keyRowMap.end()) {
        for (vector<Row>::const_iterator ri = (*i).second.begin(), re = (*i).second.end(); ri != re; ++ri) {
            Unigram g;
            const Row& r = *ri;
            g.keyValue.key = r.key;
            g.keyValue.value = r.value;
            g.score = atof(r.logProbability);
            v.push_back(g);
        }
    }

    return v;
}

bool vChewing::CoreLM::hasUnigramsForKey(const string& key)
{
    return keyRowMap.find(key.c_str()) != keyRowMap.end();
}
