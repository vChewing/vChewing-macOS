.PHONY: format

format:
	swiftformat ./ --swiftversion 5.5
	@git ls-files --exclude-standard | grep -E '\.swift$$' | xargs swift-format format --in-place --configuration ./.clang-format-swift.json --parallel
	@git ls-files --exclude-standard | grep -E '\.swift$$' | xargs swift-format lint --configuration ./.clang-format-swift.json --parallel
