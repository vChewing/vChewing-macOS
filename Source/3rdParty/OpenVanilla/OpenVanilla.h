/* 
 *  OpenVanilla.h
 *  
 *  Copyright 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef OpenVanilla_h
#define OpenVanilla_h

#if defined(__APPLE__)
    #include <OpenVanilla/OVAroundFilter.h>
    #include <OpenVanilla/OVBase.h>
    #include <OpenVanilla/OVBenchmark.h>
    #include <OpenVanilla/OVCandidateService.h>
    #include <OpenVanilla/OVCINDataTable.h>
    #include <OpenVanilla/OVCINDatabaseService.h>
    #include <OpenVanilla/OVDatabaseService.h>
    #include <OpenVanilla/OVDateTimeHelper.h>
    #include <OpenVanilla/OVEventHandlingContext.h>
    #include <OpenVanilla/OVFileHelper.h>
    #include <OpenVanilla/OVFrameworkInfo.h>
    #include <OpenVanilla/OVInputMethod.h>
    #include <OpenVanilla/OVLocalization.h>    
    #include <OpenVanilla/OVKey.h>
    #include <OpenVanilla/OVKeyValueMap.h>
    #include <OpenVanilla/OVLoaderService.h>
    #include <OpenVanilla/OVModule.h>
    #include <OpenVanilla/OVModulePackage.h>
    #include <OpenVanilla/OVOutputFilter.h>
    #include <OpenVanilla/OVPathInfo.h>
    #include <OpenVanilla/OVStringHelper.h>    
    #include <OpenVanilla/OVTextBuffer.h>
    #include <OpenVanilla/OVUTF8Helper.h>
    #include <OpenVanilla/OVWildcard.h>
    
    #ifdef OV_USE_SQLITE
        #include <OpenVanilla/OVSQLiteDatabaseService.h>
        #include <OpenVanilla/OVSQLiteWrapper.h>
    #endif
#else
    #ifdef WIN32
        #include <windows.h>
    #endif
    
    #include "OVAroundFilter.h"
    #include "OVBase.h"
    #include "OVBenchmark.h"
    #include "OVCandidateService.h"
    #include "OVCINDataTable.h"
    #include "OVCINDatabaseService.h"
    #include "OVDatabaseService.h"
    #include "OVDateTimeHelper.h"
    #include "OVEventHandlingContext.h"
    #include "OVFileHelper.h"
    #include "OVFrameworkInfo.h"
    #include "OVInputMethod.h"
    #include "OVLocalization.h"
    #include "OVKey.h"
    #include "OVKeyValueMap.h"
    #include "OVLoaderService.h"
    #include "OVModule.h"
    #include "OVModulePackage.h"
    #include "OVOutputFilter.h"
    #include "OVPathInfo.h"
    #include "OVStringHelper.h"
    #include "OVTextBuffer.h"    
    #include "OVUTF8Helper.h"
    #include "OVWildcard.h"
    
    #ifdef OV_USE_SQLITE
        #include "OVSQLiteDatabaseService.h"
        #include "OVSQLiteWrapper.h"
    #endif
#endif

#endif
