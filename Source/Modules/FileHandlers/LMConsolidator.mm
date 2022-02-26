// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

#include "LMConsolidator.h"

namespace vChewing {

constexpr std::string_view FORMATTED_PRAGMA_HEADER
    = "# 𝙵𝙾𝚁𝙼𝙰𝚃 𝚘𝚛𝚐.𝚊𝚝𝚎𝚕𝚒𝚎𝚛𝙸𝚗𝚖𝚞.𝚟𝚌𝚑𝚎𝚠𝚒𝚗𝚐.𝚞𝚜𝚎𝚛𝙻𝚊𝚗𝚐𝚞𝚊𝚐𝚎𝙼𝚘𝚍𝚎𝚕𝙳𝚊𝚝𝚊.𝚏𝚘𝚛𝚖𝚊𝚝𝚝𝚎𝚍";

// HEADER VERIFIER. CREDIT: Shiki Suen
bool LMConsolidator::CheckPragma(const char *path)
{
    ifstream zfdCheckPragma(path);
    if (zfdCheckPragma.good())
    {
        string firstLine;
        getline(zfdCheckPragma, firstLine);
        syslog(LOG_CONS, "HEADER SEEN ||%s", firstLine.c_str());
        if (firstLine != FORMATTED_PRAGMA_HEADER) {
            syslog(LOG_CONS, "HEADER VERIFICATION FAILED. START IN-PLACE CONSOLIDATING PROCESS.");
            return false;
        }
    }
    syslog(LOG_CONS, "HEADER VERIFICATION SUCCESSFUL.");
    return true;
}

// EOF FIXER. CREDIT: Shiki Suen.
bool LMConsolidator::FixEOF(const char *path)
{
    std::fstream zfdEOFFixerIncomingStream(path);
    zfdEOFFixerIncomingStream.seekg(-1,std::ios_base::end);
    char z;
    zfdEOFFixerIncomingStream.get(z);
    if(z!='\n'){
        syslog(LOG_CONS, "// REPORT: Data File not ended with a new line.\n");
        syslog(LOG_CONS, "// DATA FILE: %s", path);
        syslog(LOG_CONS, "// PROCEDURE: Trying to insert a new line as EOF before per-line check process.\n");
        std::ofstream zfdEOFFixerOutput(path, std::ios_base::app);
        zfdEOFFixerOutput << std::endl;
        zfdEOFFixerOutput.close();
        if (zfdEOFFixerOutput.fail()) {
            syslog(LOG_CONS, "// REPORT: Failed to append a newline to the data file. Insufficient Privileges?\n");
            syslog(LOG_CONS, "// DATA FILE: %s", path);
            return false;
        }
    }
    zfdEOFFixerIncomingStream.close();
    if (zfdEOFFixerIncomingStream.fail()) {
        syslog(LOG_CONS, "// REPORT: Failed to read lines through the data file for EOF check. Insufficient Privileges?\n");
        syslog(LOG_CONS, "// DATA FILE: %s", path);
        return false;
    }
    return true;
} // END: EOF FIXER.

// CONTENT CONSOLIDATOR. CREDIT: Shiki Suen.
bool LMConsolidator::ConsolidateContent(const char *path, bool shouldCheckPragma) {
    if (LMConsolidator::CheckPragma(path) && shouldCheckPragma){
        return true;
    }

    ifstream zfdContentConsolidatorIncomingStream(path);
    vector<string>vecEntry;
    while(!zfdContentConsolidatorIncomingStream.eof())
    { // Xcode 13 能用的 ObjCpp 與 Cpp 並無原生支援「\h」這個 Regex 參數的能力，只能逐行處理。
        string zfdBuffer;
        getline(zfdContentConsolidatorIncomingStream,zfdBuffer);
        vecEntry.push_back(zfdBuffer);
    }
    // 第一遍 for 用來統整每行內的內容。
    // regex sedCJKWhiteSpace("\\x{3000}"), sedNonBreakWhiteSpace("\\x{A0}"), sedWhiteSpace("\\s+"), sedLeadingSpace("^\\s"), sedTrailingSpace("\\s$"); // 這樣寫會導致輸入法敲不了任何字，推測 Xcode 13 支援的 cpp / objCpp 可能對某些 Regex 寫法有相容性問題。
    regex sedCJKWhiteSpace("　"), sedNonBreakWhiteSpace(" "), sedWhiteSpace("\\s+"), sedLeadingSpace("^\\s"), sedTrailingSpace("\\s$"); // RegEx 先定義好。
    for(int i=0;i<vecEntry.size();i++) { // 第一遍 for 用來統整每行內的內容。
        if (vecEntry[i].size() != 0) { // 不要理會空行，否則給空行加上 endl 等於再加空行。
            // RegEx 處理順序：先將全形空格換成西文空格，然後合併任何意義上的連續空格（包括 tab 等），最後去除每行首尾空格。
            vecEntry[i] = regex_replace(vecEntry[i], sedCJKWhiteSpace, " ").c_str(); // 中日韓全形空格轉為 ASCII 空格。
            vecEntry[i] = regex_replace(vecEntry[i], sedNonBreakWhiteSpace, " ").c_str(); // Non-Break 型空格轉為 ASCII 空格。
            vecEntry[i] = regex_replace(vecEntry[i], sedWhiteSpace, " ").c_str(); // 所有意義上的連續的 \s 型空格都轉為單個 ASCII 空格。
            vecEntry[i] = regex_replace(vecEntry[i], sedLeadingSpace, "").c_str(); // 去掉行首空格。
            vecEntry[i] = regex_replace(vecEntry[i], sedTrailingSpace, "").c_str(); // 去掉行尾空格。
        }
    }
    // 在第二遍 for 運算之前，針對 vecEntry 去除重複條目。
    std::reverse(vecEntry.begin(), vecEntry.end()); // 先首尾顛倒，免得破壞最新的 override 資訊。
    vecEntry.erase(unique(vecEntry.begin(), vecEntry.end()), vecEntry.end()); // 去重複。
    std::reverse(vecEntry.begin(), vecEntry.end()); // 再顛倒回來。
    // 統整完畢。開始將統整過的內容寫入檔案。
    ofstream zfdContentConsolidatorOutput(path); // 這裡是要從頭開始重寫檔案內容，所以不需要「 ios_base::app 」。
    if (!LMConsolidator::CheckPragma(path)){
        zfdContentConsolidatorOutput<<FORMATTED_PRAGMA_HEADER<<endl; // 寫入經過整理處理的 HEADER。
    }
    for(int i=0;i<vecEntry.size();i++) { // 第二遍 for 用來寫入統整過的內容。
        if (vecEntry[i].size() != 0) { // 這句很重要，不然還是會把經過 RegEx 處理後出現的空行搞到檔案裡。
            zfdContentConsolidatorOutput<<vecEntry[i]<<endl; // 這裡是必須得加上 endl 的，不然所有行都變成一個整合行。
        }
    }
    zfdContentConsolidatorOutput.close();
    if (zfdContentConsolidatorOutput.fail()) {
        syslog(LOG_CONS, "// REPORT: Failed to write content-consolidated data to the file. Insufficient Privileges?\n");
        syslog(LOG_CONS, "// DATA FILE: %s", path);
        return false;
    }
    zfdContentConsolidatorIncomingStream.close();
    if (zfdContentConsolidatorIncomingStream.fail()) {
        syslog(LOG_CONS, "// REPORT: Failed to read lines through the data file for content-consolidation. Insufficient Privileges?\n");
        syslog(LOG_CONS, "// DATA FILE: %s", path);
        return false;
    }
    return true;
} // END: CONTENT CONSOLIDATOR.

} // namespace vChewing
