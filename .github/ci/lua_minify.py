"""Conservative Lua 5.1 minification: remove comments and collapse whitespace only."""
import re

LONG = re.compile(r"\[(=*)\[")


def minify(source):
    output, index, gap = [], 0, False
    while index < len(source):
        if source[index].isspace():
            gap = True
            index += 1
            continue
        start = index
        comment = source.startswith("--", index)
        if comment:
            index += 2
        long = LONG.match(source, index)
        if long:
            closing = "]" + long[1] + "]"
            end = source.find(closing, long.end())
            if end < 0:
                raise ValueError("Unterminated Lua long string/comment")
            index = end + len(closing)
        elif comment:
            end = re.search(r"[\r\n]", source[index:])
            index = index + end.end() if end else len(source)
        elif source[index] in "\"'":
            quote = source[index]
            index += 1
            while index < len(source) and source[index] != quote:
                index += 2 if source[index] == "\\" else 1
            if index >= len(source):
                raise ValueError("Unterminated Lua string")
            index += 1
        else:
            index += 1
        if comment:
            gap = True
            continue
        if gap and output:
            output.append(" ")
        output.append(source[start:index])
        gap = False
    return "".join(output) + "\n"
