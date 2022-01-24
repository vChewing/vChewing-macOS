/* 
 *  OVDateTimeHelper.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OVDateTimeHelper_h
#define OVDateTimeHelper_h

#include <ctime>
#include <sstream>
#include <string>

namespace OpenVanilla {
    using namespace std;
    
    class OVDateTimeHelper
    {
    public:
        static time_t GetTimeIntervalSince1970()
        {
            return time(NULL);                        
        }
        
        static time_t GetTimeIntervalSince1970FromString(const string& s)
        {
            stringstream sst;
            sst << s;
            time_t t;
            sst >> t;
            return t;
        }
        
        static const string GetTimeIntervalSince1970AsString()
        {
            stringstream sst;
            sst << time(NULL);
            return sst.str();
        }
        
        static time_t GetTimeIntervalSince1970AtBeginningOfTodayLocalTime()
        {
            time_t t = time(NULL);

			#ifdef WIN32
			struct tm tdata;
			struct tm* td = &tdata;
            if (localtime_s(td, &t))
				return 0;
			#else
            struct tm* td;
			td = localtime(&t);
			#endif

            td->tm_hour = 0;
            td->tm_min = 0;
            td->tm_sec = 0;
            
            return mktime(td);
        }
        
        static const string LocalTimeString()
        {
            time_t t = time(NULL);

			#ifdef WIN32
			struct tm tdata;
			struct tm* td = &tdata;
            if (localtime_s(td, &t))
				return string();
			#else
            struct tm* td;
			td = localtime(&t);
			#endif

            ostringstream sstr;
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_hour << ":";
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_min << ":";
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_sec;
            return sstr.str();
        }
        
        static const string LocalDateTimeString()
        {
            time_t t = time(NULL);

			#ifdef WIN32
			struct tm tdata;
			struct tm* td = &tdata;
            if (localtime_s(td, &t))
				return string();
			#else
            struct tm* td;
			td = localtime(&t);
			#endif
            
            ostringstream sstr;
            sstr.width(4);
            sstr << td->tm_year + 1900 << "-";
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_mon + 1 << "-";
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_mday << " ";
            
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_hour << ":";
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_min << ":";
            sstr.width(2);
            sstr.fill('0');
            sstr << td->tm_sec;
            return sstr.str();
        }
    };
    
};

#endif
