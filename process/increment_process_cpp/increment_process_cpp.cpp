#include "juiz/juiz.h"

// 引数 arg1 に 1 を足して返す Process
//
// manifest() で Process の名前と引数 (名前・説明・既定値) を宣言し、
// PROCESS_FACTORY で juiz から呼び出せる関数として公開する。
auto manifest() {
    return ProcessManifest{"increment_process_cpp"}
        .description("Adds 1 to arg1.")
        .add_int_arg("arg1", "value to be incremented", 1);
}

std::optional<int64_t> increment_process_cpp(int64_t arg1) {
    return arg1 + 1;
}

PROCESS_FACTORY(manifest, increment_process_cpp);
