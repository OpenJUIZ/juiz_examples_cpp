#include "juiz/juiz.h"

// 引数 arg1 から 1 を引いて返す Process
auto manifest() {
    return ProcessManifest{"decrement_process_cpp"}
        .description("Subtracts 1 from arg1.")
        .add_int_arg("arg1", "value to be decremented", 1);
}

std::optional<int64_t> decrement_process_cpp(int64_t arg1) {
    return arg1 - 1;
}

PROCESS_FACTORY(manifest, decrement_process_cpp);
