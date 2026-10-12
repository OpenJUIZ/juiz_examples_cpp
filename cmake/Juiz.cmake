# juiz の C++ 機能要素をビルドするための設定
#
# C++ の機能要素は、juiz の C++ ヘッダ (bindings/cppjuiz/include) を使って書き、
# juiz_sdk の共有ライブラリ (libjuiz_sdk.so / libjuiz_sdk.dylib) とリンクする。
# どちらも crates.io の juiz_app に同梱されていないので、juiz のソースから用意する。
#
#   JUIZ_SOURCE_DIR を指定した場合: そのディレクトリの juiz のソースを使う
#   指定しない場合: GitHub から JUIZ_GIT_TAG の版を取得する
#
# JUIZ_GIT_TAG の既定値は v0.0.10。crates.io の juiz_app 0.0.10 と組み合わせて使う。
#
# libjuiz_sdk は cargo でビルドし、プラグインと同じ出力ディレクトリ (JUIZ_PLUGIN_DIR) にコピーする。
# プラグインには RPATH として自身の場所 ($ORIGIN / @loader_path) を埋め込むので、
# juiz がプラグインを読み込むと隣の libjuiz_sdk も見つかる。

include(FetchContent)

set(JUIZ_GIT_REPOSITORY "https://github.com/OpenJUIZ/juiz.git" CACHE STRING "juiz の Git リポジトリ")
set(JUIZ_GIT_TAG "v0.0.10" CACHE STRING "使用する juiz の版 (タグかコミット。cargo install juiz_app で入れた版と合わせる)")
set(JUIZ_SOURCE_DIR "" CACHE PATH "手元にある juiz のソースのディレクトリ (空なら GitHub から取得)")
set(JUIZ_PLUGIN_DIR "${CMAKE_BINARY_DIR}/plugins" CACHE PATH "プラグインの出力先")

if(NOT JUIZ_SOURCE_DIR)
  message(STATUS "Fetching juiz ${JUIZ_GIT_TAG} from ${JUIZ_GIT_REPOSITORY}")
  FetchContent_Declare(juiz
    GIT_REPOSITORY ${JUIZ_GIT_REPOSITORY}
    GIT_TAG ${JUIZ_GIT_TAG}
    GIT_SUBMODULES ""
  )
  # juiz のルートには CMakeLists.txt が無いので、ソースを取得するだけになる
  FetchContent_MakeAvailable(juiz)
  set(JUIZ_SOURCE_DIR ${juiz_SOURCE_DIR} CACHE PATH "手元にある juiz のソースのディレクトリ (空なら GitHub から取得)" FORCE)
endif()

if(NOT EXISTS "${JUIZ_SOURCE_DIR}/bindings/cppjuiz/include/juiz/juiz.h")
  message(FATAL_ERROR "juiz の C++ ヘッダが見つかりません: ${JUIZ_SOURCE_DIR}/bindings/cppjuiz/include")
endif()

find_program(CARGO_EXECUTABLE cargo HINTS "$ENV{HOME}/.cargo/bin" REQUIRED)

set(JUIZ_SDK_LIBRARY_NAME "${CMAKE_SHARED_LIBRARY_PREFIX}juiz_sdk${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(JUIZ_SDK_TARGET_DIR "${CMAKE_BINARY_DIR}/juiz_sdk")
set(JUIZ_SDK_BUILT_LIBRARY "${JUIZ_SDK_TARGET_DIR}/release/${JUIZ_SDK_LIBRARY_NAME}")
set(JUIZ_SDK_LIBRARY "${JUIZ_PLUGIN_DIR}/${JUIZ_SDK_LIBRARY_NAME}")

# libjuiz_sdk を cargo でビルドしてプラグインの出力先にコピーする
add_custom_command(
  OUTPUT ${JUIZ_SDK_LIBRARY}
  COMMAND ${CARGO_EXECUTABLE} build --release -p juiz_sdk
          --manifest-path ${JUIZ_SOURCE_DIR}/Cargo.toml
          --target-dir ${JUIZ_SDK_TARGET_DIR}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${JUIZ_PLUGIN_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy ${JUIZ_SDK_BUILT_LIBRARY} ${JUIZ_SDK_LIBRARY}
  COMMENT "Building juiz_sdk with cargo"
  VERBATIM
)
add_custom_target(juiz_sdk_build DEPENDS ${JUIZ_SDK_LIBRARY})

add_library(juiz_sdk SHARED IMPORTED GLOBAL)
set_target_properties(juiz_sdk PROPERTIES
  IMPORTED_LOCATION ${JUIZ_SDK_LIBRARY}
  IMPORTED_NO_SONAME TRUE
  INTERFACE_INCLUDE_DIRECTORIES "${JUIZ_SOURCE_DIR}/bindings/cppjuiz/include"
)
add_dependencies(juiz_sdk juiz_sdk_build)

if(APPLE)
  set(JUIZ_PLUGIN_RPATH "@loader_path")
else()
  set(JUIZ_PLUGIN_RPATH "$ORIGIN")
endif()

# juiz のプラグイン (共有ライブラリ) を追加する。
# juiz は設定ファイルに書いた名前 NAME から lib<NAME>.so (macOS では lib<NAME>.dylib) を探すので、
# ターゲット名を設定ファイルの名前と同じにする。
# Process・Container・ContainerProcess・Component のどれも同じ方法でビルドする。
function(add_juiz_plugin NAME)
  cmake_parse_arguments(JUIZ "" "" "SOURCES" ${ARGN})
  add_library(${NAME} SHARED ${JUIZ_SOURCES})
  target_link_libraries(${NAME} PRIVATE juiz_sdk)
  set_target_properties(${NAME} PROPERTIES
    PREFIX "lib"
    LIBRARY_OUTPUT_DIRECTORY ${JUIZ_PLUGIN_DIR}
    RUNTIME_OUTPUT_DIRECTORY ${JUIZ_PLUGIN_DIR}
    BUILD_RPATH ${JUIZ_PLUGIN_RPATH}
  )
endfunction()

function(add_juiz_process NAME)
  add_juiz_plugin(${NAME} ${ARGN})
endfunction()

function(add_juiz_container NAME)
  add_juiz_plugin(${NAME} ${ARGN})
endfunction()

function(add_juiz_container_process NAME)
  add_juiz_plugin(${NAME} ${ARGN})
endfunction()

function(add_juiz_component NAME)
  add_juiz_plugin(${NAME} ${ARGN})
endfunction()
