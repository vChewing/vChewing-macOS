import XCTest

@testable import OpenCC

let testCases: [(String, ChineseConverter.Options)] = [
	("s2t", [.traditionalize]),
	("t2s", [.simplify]),
	("s2hk", [.traditionalize, .hkStandard]),
	("hk2s", [.simplify, .hkStandard]),
	("s2tw", [.traditionalize, .twStandard]),
	("tw2s", [.simplify, .twStandard]),
	("s2twp", [.traditionalize, .twStandard, .twIdiom]),
	("tw2sp", [.simplify, .twStandard, .twIdiom])
]

class OpenCCTests: XCTestCase {

	func converter(option: ChineseConverter.Options) throws -> ChineseConverter {
		try ChineseConverter(options: option)
	}

	func testConversion() throws {
		func testCase(name: String, ext: String) -> String {
			let url = Bundle.module.url(
				forResource: name, withExtension: ext, subdirectory: "testcases")!
			return try! String(contentsOf: url)
		}
		for (name, opt) in testCases {
			let coverter = try ChineseConverter(options: opt)
			let input = testCase(name: name, ext: "in")
			let converted = coverter.convert(input)
			let output = testCase(name: name, ext: "ans")
			XCTAssertEqual(converted, output, "Conversion \(name) fails")
		}
	}

	func testConverterCreationPerformance() {
		let options: ChineseConverter.Options = [.traditionalize, .twStandard, .twIdiom]
		measure {
			for _ in 0..<10 {
				_ = try! ChineseConverter(options: options)
			}
		}
	}

	func testDictionaryCache() {
		let options: ChineseConverter.Options = [.traditionalize, .twStandard, .twIdiom]
		let holder = try! ChineseConverter(options: options)
		measure {
			for _ in 0..<1_000 {
				_ = try! ChineseConverter(options: options)
			}
		}
		_ = holder.convert("foo")
	}

	func testConversionPerformance() throws {
		let cov = try converter(option: [.traditionalize, .twStandard, .twIdiom])
		let url = Bundle.module.url(
			forResource: "zuozhuan", withExtension: "txt", subdirectory: "benchmark")!
		// 1.9 MB, 624k word
		let str = try String(contentsOf: url)
		measure {
			_ = cov.convert(str)
		}
	}
}
