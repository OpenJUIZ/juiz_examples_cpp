#include <iostream>
#include "juiz/juiz.h"

// 文字列を出力する Process (引数なし)
auto manifest() {
    return ProcessManifest{"talker_cpp"}
        .description("Outputs a message.");
}

std::optional<std::string> talker_cpp() {
    std::cout << "talker_cpp: Hello, Juiz!" << std::endl;
    return "Hello, Juiz!";
}

PROCESS_FACTORY(manifest, talker_cpp);
