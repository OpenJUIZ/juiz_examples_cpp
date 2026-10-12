#include "juiz/juiz.h"
#include "example_container_cpp.h"

// 整数値を 1 つ保持する Container
auto manifest() {
    return ContainerManifest("example_container_cpp")
        .description("Holds an integer value.");
}

// 設定ファイルの containers に書いた項目 (value など) を受け取って Container を作る
ExampleContainer* create_container(juiz::CapsuleMap args) {
    int64_t initial_value = 0;
    if (args.has("value")) {
        initial_value = args.get_int("value");
    }
    return new ExampleContainer(initial_value);
}

CONTAINER_FACTORY(manifest, create_container);
