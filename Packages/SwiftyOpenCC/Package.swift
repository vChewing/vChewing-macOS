// swift-tools-version:5.3

import PackageDescription

let package = Package(
	name: "SwiftyOpenCC",
	products: [
		.library(
			name: "OpenCC",
			targets: ["OpenCC"])
	],
	targets: [
		.target(
			name: "OpenCC",
			dependencies: ["copencc"],
			resources: [
				.copy("Dictionary")
			]),
		.testTarget(
			name: "OpenCCTests",
			dependencies: ["OpenCC"],
			resources: [
				.copy("benchmark"),
				.copy("testcases"),
			]),
		.target(
			name: "copencc",
			exclude: [
				"src/benchmark",
				"src/tools",
				"src/BinaryDictTest.cpp",
				"src/Config.cpp",
				"src/ConfigTest.cpp",
				"src/ConversionChainTest.cpp",
				"src/ConversionTest.cpp",
				"src/DartsDictTest.cpp",
				"src/DictGroupTest.cpp",
				"src/MarisaDictTest.cpp",
				"src/MaxMatchSegmentationTest.cpp",
				"src/PhraseExtractTest.cpp",
				"src/SerializedValuesTest.cpp",
				"src/SimpleConverter.cpp",
				"src/SimpleConverterTest.cpp",
				"src/TextDictTest.cpp",
				"src/UTF8StringSliceTest.cpp",
				"src/UTF8UtilTest.cpp",
				"deps/google-benchmark",
				"deps/gtest-1.11.0",
				"deps/pybind11-2.5.0",
				"deps/rapidjson-1.1.0",
				"deps/tclap-1.2.2",

				"src/CmdLineOutput.hpp",
				"src/Config.hpp",
				"src/ConfigTestBase.hpp",
				"src/DictGroupTestBase.hpp",
				"src/SimpleConverter.hpp",
				"src/TestUtils.hpp",
				"src/TestUtilsUTF8.hpp",
				"src/TextDictTestBase.hpp",
				"src/py_opencc.cpp",

				// ???
				"src/README.md",
				"src/CMakeLists.txt",
				"deps/marisa-0.2.6/AUTHORS",
				"deps/marisa-0.2.6/CMakeLists.txt",
				"deps/marisa-0.2.6/COPYING.md",
				"deps/marisa-0.2.6/README.md",
			],
			sources: [
				"source.cpp",
				"src",
				"deps/marisa-0.2.6",
			],
			cxxSettings: [
				.headerSearchPath("src"),
				.headerSearchPath("deps/darts-clone"),
				.headerSearchPath("deps/marisa-0.2.6/include"),
				.headerSearchPath("deps/marisa-0.2.6/lib"),
				.define("ENABLE_DARTS"),
			]),
	],
	cxxLanguageStandard: .cxx14
)
