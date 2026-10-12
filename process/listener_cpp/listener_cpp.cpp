#include <iostream>
#include "juiz/juiz.h"

// 受け取った文字列を表示する Process
auto manifest() {
    return ProcessManifest{"listener_cpp"}
        .description("Prints the received message.")
        .add_string_arg("arg1", "message to be printed", "Hello, Juiz!");
}

std::optional<std::string> listener_cpp(const std::string& arg1) {
    std::cout << "listener_cpp: " << arg1 << std::endl;
    return arg1;
}

PROCESS_FACTORY(manifest, listener_cpp);
