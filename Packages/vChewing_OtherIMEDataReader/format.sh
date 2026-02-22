find . -regex '.*\.\(hh\)' -exec clang-format -style=file -i {} \;
find . -regex '.*\.\(cc\)' -exec clang-format -style=file -i {} \;
find . -regex '.*\.\(mm\)' -exec clang-format -style=file -i {} \;
find . -regex '.*\.\(h\)' -exec clang-format -style=file -i {} \;
find . -regex '.*\.\(c\)' -exec clang-format -style=file -i {} \;
find . -regex '.*\.\(m\)' -exec clang-format -style=file -i {} \;
