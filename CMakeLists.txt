cmake_minimum_required(VERSION 3.16)

project(juiz_examples_cpp CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release)
endif()

# juiz の C++ ヘッダ (cppjuiz) と libjuiz_sdk を用意し、add_juiz_process() などの関数を定義する。
include(cmake/Juiz.cmake)

add_subdirectory(process)
add_subdirectory(container)
add_subdirectory(component)
