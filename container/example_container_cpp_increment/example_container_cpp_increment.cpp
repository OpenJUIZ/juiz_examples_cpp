#include "juiz/juiz.h"
#include "example_container_cpp.h"

// Container の値に arg1 を足して、足した後の値を返す ContainerProcess
auto manifest() {
    return ProcessManifest("example_container_cpp_increment")
        .description("Adds arg1 to the value of the container.")
        .container_type("example_container_cpp")
        .add_int_arg("arg1", "value to be added", 1);
}

std::optional<int64_t> example_container_cpp_increment(ExampleContainer* container, int64_t arg1) {
    container->value += arg1;
    return container->value;
}

CONTAINER_PROCESS_FACTORY(ExampleContainer, manifest, example_container_cpp_increment);
