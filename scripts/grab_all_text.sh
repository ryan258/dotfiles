#!/bin/bash
find . \( -path ./.git -o -path ./zsh/.zsh_sessions -o -path ./all_text_contents.txt \) -prune -o -type f -exec sh -c 'grep -Iq . "$1" && cat "$1"' _ {} \; > all_text_contents.txt