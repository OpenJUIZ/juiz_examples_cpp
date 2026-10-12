#pragma once

#include <cstdint>

// Container が保持する状態
// Container と、それを操作する ContainerProcess で共有する。
class ExampleContainer {
public:
    int64_t value;
    ExampleContainer(int64_t v) : value(v) {}
};
