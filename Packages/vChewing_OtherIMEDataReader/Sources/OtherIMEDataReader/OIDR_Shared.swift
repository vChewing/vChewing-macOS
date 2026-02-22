// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

public enum OIDRException: Error {
  case notFileURL(URL)
  case fileNotExist(URL)
  case fileNameInsane(URL)
  case wrongFileExtension(URL)
  case sqliteDatabaseReadingError(Error)
  case sqliteCERODDatabaseReadingError(Error)
  case manjusriTextReadingError(Error)

  // MARK: Public

  public var i18nKeyHeader: StaticString {
    switch self {
    case .notFileURL:
      "i18n:OtherIMEDataReader.OIDRException.notFileURL"
    case .fileNotExist:
      "i18n:OtherIMEDataReader.OIDRException.fileNotExist"
    case .fileNameInsane:
      "i18n:OtherIMEDataReader.OIDRException.fileNameInsane"
    case .wrongFileExtension:
      "i18n:OtherIMEDataReader.OIDRException.wrongFileExtension"
    case .sqliteDatabaseReadingError:
      "i18n:OtherIMEDataReader.OIDRException.sqliteDatabaseReadingError"
    case .sqliteCERODDatabaseReadingError:
      "i18n:OtherIMEDataReader.OIDRException.sqliteCERODDatabaseReadingError"
    case .manjusriTextReadingError:
      "i18n:OtherIMEDataReader.OIDRException.manjusriTextReadingError"
    }
  }
}
