#include "juiz/juiz.h"

// 1 つのライブラリに Process・Container・ContainerProcess をまとめた Component
//
// Component では各要素を COMPONENT_*_FACTORY で公開し、
// 最後に component_manifest() でまとめて宣言する。

// Process: arg1 に 1 を足して返す
static auto example_component_cpp_increment_manif =
    ProcessManifest("example_component_cpp_increment")
        .add_int_arg("arg1", "value to be incremented", 1);
std::optional<int64_t> example_component_cpp_increment(int64_t arg1) {
    return arg1 + 1;
}
COMPONENT_PROCESS_FACTORY(example_component_cpp_increment_manif, example_component_cpp_increment);

// Container: 整数値を 1 つ保持する
class ComponentContainer {
public:
    int64_t value;
    ComponentContainer(int64_t v) : value(v) {}
};

static auto example_component_cpp_container_manif =
    ContainerManifest("example_component_cpp_container");
ComponentContainer* example_component_cpp_container(juiz::CapsuleMap args) {
    int64_t initial_value = 0;
    if (args.has("value")) {
        initial_value = args.get_int("value");
    }
    return new ComponentContainer(initial_value);
}
COMPONENT_CONTAINER_FACTORY(example_component_cpp_container_manif, example_component_cpp_container);

// ContainerProcess: Container の値を返す
static auto example_component_cpp_container_get_manif =
    ProcessManifest("example_component_cpp_container_get");
std::optional<int64_t> example_component_cpp_container_get(ComponentContainer* container) {
    return container->value;
}
COMPONENT_CONTAINER_PROCESS_FACTORY(ComponentContainer, example_component_cpp_container_get_manif, example_component_cpp_container_get);

// ContainerProcess: Container の値に arg1 を足す
static auto example_component_cpp_container_increment_manif =
    ProcessManifest("example_component_cpp_container_increment")
        .add_int_arg("arg1", "value to be added", 1);
std::optional<int64_t> example_component_cpp_container_increment(ComponentContainer* container, int64_t arg1) {
    container->value += arg1;
    return container->value;
}
COMPONENT_CONTAINER_PROCESS_FACTORY(ComponentContainer, example_component_cpp_container_increment_manif, example_component_cpp_container_increment);

// Component 全体のマニフェスト
auto component_manifest() {
    return ComponentManifest("example_component_cpp")
        .add_process(example_component_cpp_increment_manifest())
        .add_container(example_component_cpp_container_manifest()
            .add_process(example_component_cpp_container_get_manifest())
            .add_process(example_component_cpp_container_increment_manifest()));
}
DEFINE_COMPONENT_MANIFEST_ENTRY_POINT(component_manifest)
