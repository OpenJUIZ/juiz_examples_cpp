#include "juiz/juiz.h"
#include "example_container_cpp.h"

// Container の値を返す ContainerProcess
auto manifest() {
    return ProcessManifest("example_container_cpp_get")
        .description("Returns the value of the container.")
        .container_type("example_container_cpp");
}

std::optional<int64_t> example_container_cpp_get(ExampleContainer* container) {
    return container->value;
}

CONTAINER_PROCESS_FACTORY(ExampleContainer, manifest, example_container_cpp_get);
