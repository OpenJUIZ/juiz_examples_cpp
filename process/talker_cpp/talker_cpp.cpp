#include <iostream>
#include "juiz/juiz.h"

// 文字列 message (既定は "Hello, Juiz!") を出力する Process
auto manifest() {
    return ProcessManifest{"talker_cpp"}
        .description("Outputs a message.")
        .add_string_arg("message", "message to be output", "Hello, Juiz!");
}

std::optional<std::string> talker_cpp(const std::string& message) {
    std::cout << "talker_cpp: " << message << std::endl;
    return message;
}

PROCESS_FACTORY(manifest, talker_cpp);
