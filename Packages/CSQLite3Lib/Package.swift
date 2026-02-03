// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CSQLite3Lib",
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "CSQLite3Lib",
      targets: ["CSQLite3Lib"]
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "CSQLite3Lib",
      cSettings: buildCSQLiteSettings()
    ),
  ]
)

func buildCSQLiteSettings() -> [CSetting] {
  var settings: [CSetting] = [
    .unsafeFlags(["-w"]),
    // Common performance optimizations
    .define("SQLITE_THREADSAFE", to: "2"), // Multi-thread safe
    .define("SQLITE_DEFAULT_CACHE_SIZE", to: "-64000"), // 64MB cache
    .define("SQLITE_DEFAULT_PAGE_SIZE", to: "4096"), // 4KB pages
    .define("SQLITE_DEFAULT_TEMP_CACHE_SIZE", to: "-32000"), // 32MB temp cache
    .define("SQLITE_OMIT_DEPRECATED"), // Remove deprecated APIs
    .define("SQLITE_OMIT_LOAD_EXTENSION"), // No dynamic loading
    .define("SQLITE_OMIT_SHARED_CACHE"), // No shared cache (read-only DB)
    .define("SQLITE_OMIT_UTF16"), // Only UTF-8 support
    .define("SQLITE_OMIT_PROGRESS_CALLBACK"), // No progress callbacks
    .define("SQLITE_MAX_EXPR_DEPTH", to: "0"), // No expression depth limit
    .define("SQLITE_USE_ALLOCA"), // Use alloca for small allocations
    .define("SQLITE_ENABLE_MEMORY_MANAGEMENT"), // Better memory management
    .define("SQLITE_ENABLE_FAST_SECURE_DELETE"), // Faster deletes
  ]

  #if os(Windows)
    // Windows-specific optimizations
    settings.append(.define("SQLITE_WIN32_MALLOC")) // Use Windows heap API
    settings.append(.define("SQLITE_WIN32_MALLOC_VALIDATE")) // Validate heap allocations
  #endif

  #if canImport(Darwin)
    // macOS/iOS-specific optimizations
    settings.append(.define("SQLITE_ENABLE_LOCKING_STYLE", to: "1")) // Better file locking
  #endif

  return settings
}
