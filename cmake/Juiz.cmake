# juiz の C++ 機能要素をビルドするための設定
#
# C++ の機能要素は、juiz の C++ ヘッダ (cppjuiz) を使って書き、
# juiz_sdk の共有ライブラリ (libjuiz_sdk.so / libjuiz_sdk.dylib / juiz_sdk.dll) とリンクする。
# どちらも crates.io の juiz_app に同梱されていないので、次のどちらかで用意する。
#
#   アーカイブ (既定): JUIZ_GIT_TAG がタグ (v<版>) なら、GitHub Releases にある
#     juiz_sdk-<版>-<ターゲット>.tar.gz (libjuiz_sdk とヘッダ、0.0.26 から) を build/juiz_sdk_archive に取得する。
#     cargo も juiz のソースも要らない。配布しているのは Linux (x86_64・aarch64) と macOS (arm64・x86_64)、
#     0.0.27 からは Windows (x86_64、MSVC。.zip に juiz_sdk.dll とインポートライブラリ juiz_sdk.dll.lib)。
#   ソース: JUIZ_SOURCE_DIR を指定した場合はそのディレクトリの juiz のソースを、
#     JUIZ_GIT_TAG がタグでない場合・JUIZ_SDK_FROM_SOURCE=ON の場合・アーカイブを取得できなかった場合は
#     GitHub から取得した JUIZ_GIT_TAG のソースを使い、libjuiz_sdk を cargo でビルドする。
#
# JUIZ_GIT_TAG の既定値は v0.0.26。crates.io の juiz_app 0.0.26 と組み合わせて使う。
#
# libjuiz_sdk はプラグインと同じ出力ディレクトリ (JUIZ_PLUGIN_DIR) に置く。
# プラグインには RPATH として自身の場所 ($ORIGIN / @loader_path) を埋め込むので、
# juiz がプラグインを読み込むと隣の libjuiz_sdk も見つかる。
# Windows には RPATH が無いが、juiz (0.0.27 から) はプラグインの DLL が使う DLL をプラグインの隣から探す。

include(FetchContent)

set(JUIZ_GIT_REPOSITORY "https://github.com/OpenJUIZ/juiz.git" CACHE STRING "juiz の Git リポジトリ")
set(JUIZ_GIT_TAG "v0.0.26" CACHE STRING "使用する juiz の版 (タグかコミット。cargo install juiz_app で入れた版と合わせる)")
set(JUIZ_SOURCE_DIR "" CACHE PATH "手元にある juiz のソースのディレクトリ (空ならアーカイブか GitHub から取得)")
option(JUIZ_SDK_FROM_SOURCE "libjuiz_sdk をアーカイブを使わずに juiz のソースからビルドする" OFF)
set(JUIZ_SDK_RELEASE_URL "https://github.com/OpenJUIZ/juiz/releases/download" CACHE STRING "libjuiz_sdk のアーカイブの取得元")
set(JUIZ_PLUGIN_DIR "${CMAKE_BINARY_DIR}/plugins" CACHE PATH "プラグインの出力先")

set(JUIZ_SDK_LIBRARY_NAME "${CMAKE_SHARED_LIBRARY_PREFIX}juiz_sdk${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(JUIZ_SDK_LIBRARY "${JUIZ_PLUGIN_DIR}/${JUIZ_SDK_LIBRARY_NAME}")
# Windows の DLL はアーカイブでは bin/ に、リンクに使うインポートライブラリ (juiz_sdk.dll.lib) は lib/ にある
if(WIN32)
  set(JUIZ_SDK_ARCHIVE_LIBRARY_SUBDIR "bin")
else()
  set(JUIZ_SDK_ARCHIVE_LIBRARY_SUBDIR "lib")
endif()

# GitHub Releases から libjuiz_sdk のアーカイブを取得して展開する。
# 展開したディレクトリを OUT_DIR に返す。取得できなければ空にする
function(juiz_fetch_sdk_archive VERSION OUT_DIR)
  set(${OUT_DIR} "" PARENT_SCOPE)
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" arch)
  if(arch MATCHES "^(x86_64|amd64)$")
    set(arch x86_64)
  elseif(arch MATCHES "^(aarch64|arm64)$")
    set(arch aarch64)
  else()
    message(STATUS "${CMAKE_SYSTEM_PROCESSOR} 向けの libjuiz_sdk のアーカイブは配布していません")
    return()
  endif()
  set(ext "tar.gz")
  if(APPLE)
    set(target "${arch}-apple-darwin")
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(target "${arch}-unknown-linux-gnu")
  elseif(WIN32 AND arch STREQUAL "x86_64")
    set(target "${arch}-pc-windows-msvc")
    set(ext "zip")
  else()
    message(STATUS "${CMAKE_SYSTEM_NAME} 向けの libjuiz_sdk のアーカイブは配布していません")
    return()
  endif()

  set(name "juiz_sdk-${VERSION}-${target}")
  set(archive_root "${CMAKE_BINARY_DIR}/juiz_sdk_archive")
  set(dir "${archive_root}/${name}")
  if(EXISTS "${dir}/${JUIZ_SDK_ARCHIVE_LIBRARY_SUBDIR}/${JUIZ_SDK_LIBRARY_NAME}" AND EXISTS "${dir}/cppjuiz/include/juiz/juiz.h")
    set(${OUT_DIR} "${dir}" PARENT_SCOPE)
    return()
  endif()

  set(url "${JUIZ_SDK_RELEASE_URL}/v${VERSION}/${name}.${ext}")
  set(tarball "${archive_root}/${name}.${ext}")
  message(STATUS "Downloading libjuiz_sdk ${VERSION} from ${url}")
  file(DOWNLOAD "${url}.sha256" "${tarball}.sha256" STATUS st)
  list(GET st 0 code)
  if(NOT code EQUAL 0)
    message(STATUS "${url}.sha256 を取得できません: ${st}")
    return()
  endif()
  file(READ "${tarball}.sha256" sha)
  string(REGEX MATCH "^[0-9a-fA-F]+" sha "${sha}")
  file(DOWNLOAD "${url}" "${tarball}" EXPECTED_HASH SHA256=${sha} STATUS st)
  list(GET st 0 code)
  if(NOT code EQUAL 0)
    message(STATUS "${url} を取得できません: ${st}")
    file(REMOVE "${tarball}")
    return()
  endif()
  file(REMOVE_RECURSE "${dir}")
  # cmake -E tar は .tar.gz も .zip も展開できる
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf "${tarball}"
                  WORKING_DIRECTORY "${archive_root}" RESULT_VARIABLE res)
  if(NOT res EQUAL 0 OR NOT EXISTS "${dir}/${JUIZ_SDK_ARCHIVE_LIBRARY_SUBDIR}/${JUIZ_SDK_LIBRARY_NAME}")
    message(STATUS "${tarball} を展開できません")
    return()
  endif()
  set(${OUT_DIR} "${dir}" PARENT_SCOPE)
endfunction()

set(JUIZ_SDK_ARCHIVE_DIR "")
if(NOT JUIZ_SOURCE_DIR AND NOT JUIZ_SDK_FROM_SOURCE AND JUIZ_GIT_TAG MATCHES "^v([0-9]+\\.[0-9]+\\.[0-9]+)$")
  juiz_fetch_sdk_archive(${CMAKE_MATCH_1} JUIZ_SDK_ARCHIVE_DIR)
  if(NOT JUIZ_SDK_ARCHIVE_DIR)
    message(STATUS "libjuiz_sdk のアーカイブを取得できなかったので、juiz のソースからビルドします")
  endif()
endif()

if(JUIZ_SDK_ARCHIVE_DIR)
  # アーカイブ: libjuiz_sdk をプラグインの出力先にコピーし、ヘッダはアーカイブのものを使う
  # (cppjuiz のヘッダは cjuiz のヘッダを相対パスで include するので、アーカイブの配置のまま使う)
  message(STATUS "Using libjuiz_sdk from ${JUIZ_SDK_ARCHIVE_DIR}")
  set(JUIZ_CPP_INCLUDE_DIR "${JUIZ_SDK_ARCHIVE_DIR}/cppjuiz/include")
  file(MAKE_DIRECTORY ${JUIZ_PLUGIN_DIR})
  file(COPY "${JUIZ_SDK_ARCHIVE_DIR}/${JUIZ_SDK_ARCHIVE_LIBRARY_SUBDIR}/${JUIZ_SDK_LIBRARY_NAME}" DESTINATION ${JUIZ_PLUGIN_DIR})
  set(JUIZ_SDK_IMPORT_LIBRARY "${JUIZ_SDK_ARCHIVE_DIR}/lib/juiz_sdk.dll.lib")
else()
  # ソース: juiz のソースを用意し、libjuiz_sdk を cargo でビルドしてプラグインの出力先にコピーする
  if(NOT JUIZ_SOURCE_DIR)
    message(STATUS "Fetching juiz ${JUIZ_GIT_TAG} from ${JUIZ_GIT_REPOSITORY}")
    FetchContent_Declare(juiz
      GIT_REPOSITORY ${JUIZ_GIT_REPOSITORY}
      GIT_TAG ${JUIZ_GIT_TAG}
      GIT_SUBMODULES ""
    )
    # juiz のルートには CMakeLists.txt が無いので、ソースを取得するだけになる
    FetchContent_MakeAvailable(juiz)
    set(JUIZ_SOURCE_DIR ${juiz_SOURCE_DIR} CACHE PATH "手元にある juiz のソースのディレクトリ (空ならアーカイブか GitHub から取得)" FORCE)
  endif()

  set(JUIZ_CPP_INCLUDE_DIR "${JUIZ_SOURCE_DIR}/bindings/cppjuiz/include")
  if(NOT EXISTS "${JUIZ_CPP_INCLUDE_DIR}/juiz/juiz.h")
    message(FATAL_ERROR "juiz の C++ ヘッダが見つかりません: ${JUIZ_CPP_INCLUDE_DIR}")
  endif()

  find_program(CARGO_EXECUTABLE cargo HINTS "$ENV{HOME}/.cargo/bin" REQUIRED)

  set(JUIZ_SDK_TARGET_DIR "${CMAKE_BINARY_DIR}/juiz_sdk")
  set(JUIZ_SDK_BUILT_LIBRARY "${JUIZ_SDK_TARGET_DIR}/release/${JUIZ_SDK_LIBRARY_NAME}")
  set(JUIZ_SDK_IMPORT_LIBRARY "${JUIZ_SDK_TARGET_DIR}/release/juiz_sdk.dll.lib")
  add_custom_command(
    OUTPUT ${JUIZ_SDK_LIBRARY}
    BYPRODUCTS ${JUIZ_SDK_IMPORT_LIBRARY}
    COMMAND ${CARGO_EXECUTABLE} build --release -p juiz_sdk
            --manifest-path ${JUIZ_SOURCE_DIR}/Cargo.toml
            --target-dir ${JUIZ_SDK_TARGET_DIR}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${JUIZ_PLUGIN_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy ${JUIZ_SDK_BUILT_LIBRARY} ${JUIZ_SDK_LIBRARY}
    COMMENT "Building juiz_sdk with cargo"
    VERBATIM
  )
  add_custom_target(juiz_sdk_build DEPENDS ${JUIZ_SDK_LIBRARY})
endif()

add_library(juiz_sdk SHARED IMPORTED GLOBAL)
set_target_properties(juiz_sdk PROPERTIES
  IMPORTED_LOCATION ${JUIZ_SDK_LIBRARY}
  IMPORTED_NO_SONAME TRUE
  INTERFACE_INCLUDE_DIRECTORIES "${JUIZ_CPP_INCLUDE_DIR}"
  # ヘッダとサンプルは日本語のコメントを含む BOM なしの UTF-8。MSVC は既定でシステムのコードページ
  # (日本語の Windows では CP932) で読むので /utf-8 を付ける
  INTERFACE_COMPILE_OPTIONS "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>"
)
if(WIN32)
  set_target_properties(juiz_sdk PROPERTIES IMPORTED_IMPLIB ${JUIZ_SDK_IMPORT_LIBRARY})
endif()
if(TARGET juiz_sdk_build)
  add_dependencies(juiz_sdk juiz_sdk_build)
endif()

# データ型: IDL (types/geometry.jidl) から C++ の型を作る生成器 juiz-idl と、CMake の関数 juiz_generate_types()。
# JUIZ_IDL_EXECUTABLE を指定しなければ、
#   アーカイブのとき: PATH の juiz-idl を使う。無ければ juiz コマンドの `juiz idl` (juiz-idl と同じ引数を取る) を使う
#   ソースのとき: juiz-idl を同じソースから cargo でビルドして使う (同じ版の生成器になる)
if(JUIZ_SDK_ARCHIVE_DIR)
  if(NOT JUIZ_IDL_EXECUTABLE)
    find_program(JUIZ_IDL_PROGRAM juiz-idl HINTS "$ENV{HOME}/.cargo/bin")
    find_program(JUIZ_PROGRAM juiz HINTS "$ENV{HOME}/.cargo/bin")
    if(JUIZ_IDL_PROGRAM)
      set(JUIZ_IDL_EXECUTABLE "${JUIZ_IDL_PROGRAM}")
    elseif(JUIZ_PROGRAM AND WIN32)
      # juiz_generate_types() は 1 つの実行ファイルを呼ぶので、`juiz idl` を呼ぶ小さなバッチファイルを作る
      file(TO_NATIVE_PATH "${JUIZ_PROGRAM}" juiz_program_native)
      file(WRITE "${CMAKE_BINARY_DIR}/juiz-idl.cmd" "@\"${juiz_program_native}\" idl %*\r\n")
      set(JUIZ_IDL_EXECUTABLE "${CMAKE_BINARY_DIR}/juiz-idl.cmd")
    elseif(JUIZ_PROGRAM)
      # juiz_generate_types() は 1 つの実行ファイルを呼ぶので、`juiz idl` を呼ぶ小さなスクリプトを作る
      file(WRITE "${CMAKE_BINARY_DIR}/juiz_idl_wrapper/juiz-idl" "#!/bin/sh\nexec \"${JUIZ_PROGRAM}\" idl \"$@\"\n")
      file(COPY "${CMAKE_BINARY_DIR}/juiz_idl_wrapper/juiz-idl" DESTINATION "${CMAKE_BINARY_DIR}"
           FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
      set(JUIZ_IDL_EXECUTABLE "${CMAKE_BINARY_DIR}/juiz-idl")
    else()
      message(FATAL_ERROR "juiz-idl も juiz コマンドも見つかりません。`cargo install juiz_app` で juiz を入れるか、"
        "-DJUIZ_IDL_EXECUTABLE=<juiz-idl のパス> を指定してください")
    endif()
  endif()
  message(STATUS "Using juiz-idl: ${JUIZ_IDL_EXECUTABLE}")
  # juiz_generate_types() を定義する juiz_idl.cmake はアーカイブに入っていないので、同じ版のものを取得する
  set(JUIZ_IDL_CMAKE "${CMAKE_BINARY_DIR}/juiz_sdk_archive/juiz_idl-${JUIZ_GIT_TAG}.cmake")
  if(NOT EXISTS "${JUIZ_IDL_CMAKE}")
    string(REGEX REPLACE "\\.git$" "" repo_url "${JUIZ_GIT_REPOSITORY}")
    string(REPLACE "https://github.com/" "https://raw.githubusercontent.com/" raw_url "${repo_url}")
    file(DOWNLOAD "${raw_url}/${JUIZ_GIT_TAG}/bindings/cppjuiz/cmake/juiz_idl.cmake" "${JUIZ_IDL_CMAKE}.tmp" STATUS st)
    list(GET st 0 code)
    if(NOT code EQUAL 0)
      file(REMOVE "${JUIZ_IDL_CMAKE}.tmp")
      message(FATAL_ERROR "juiz_idl.cmake を取得できません: ${st}")
    endif()
    file(RENAME "${JUIZ_IDL_CMAKE}.tmp" "${JUIZ_IDL_CMAKE}")
  endif()
  include(${JUIZ_IDL_CMAKE})
else()
  if(NOT JUIZ_IDL_EXECUTABLE)
    message(STATUS "Building juiz-idl with cargo")
    execute_process(
      COMMAND ${CARGO_EXECUTABLE} build --release -p juiz_idl
              --manifest-path ${JUIZ_SOURCE_DIR}/Cargo.toml
              --target-dir ${JUIZ_SDK_TARGET_DIR}
      RESULT_VARIABLE JUIZ_IDL_BUILD_RESULT)
    if(NOT JUIZ_IDL_BUILD_RESULT EQUAL 0)
      message(FATAL_ERROR "juiz-idl のビルドに失敗しました")
    endif()
    set(JUIZ_IDL_EXECUTABLE "${JUIZ_SDK_TARGET_DIR}/release/juiz-idl${CMAKE_EXECUTABLE_SUFFIX}")
  endif()
  include(${JUIZ_SOURCE_DIR}/bindings/cppjuiz/cmake/juiz_idl.cmake)
endif()

if(APPLE)
  set(JUIZ_PLUGIN_RPATH "@loader_path")
else()
  set(JUIZ_PLUGIN_RPATH "$ORIGIN")
endif()

# juiz のプラグイン (共有ライブラリ) を追加する。
# juiz は設定ファイルに書いた名前 NAME から lib<NAME>.so (macOS では lib<NAME>.dylib、Windows では <NAME>.dll) を
# 探すので、ターゲット名を設定ファイルの名前と同じにする。
# Process・Container・ContainerProcess・Component のどれも同じ方法でビルドする。
function(add_juiz_plugin NAME)
  cmake_parse_arguments(JUIZ "" "" "SOURCES" ${ARGN})
  add_library(${NAME} SHARED ${JUIZ_SOURCES})
  target_link_libraries(${NAME} PRIVATE juiz_sdk)
  # $<1:...> で囲むと、Visual Studio などの複数構成のジェネレータでも plugins/Release のように構成名が足されない
  set_target_properties(${NAME} PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "$<1:${JUIZ_PLUGIN_DIR}>"
    RUNTIME_OUTPUT_DIRECTORY "$<1:${JUIZ_PLUGIN_DIR}>"
    BUILD_RPATH ${JUIZ_PLUGIN_RPATH}
  )
  # MinGW の既定の接頭辞 lib も付けない
  if(WIN32)
    set_target_properties(${NAME} PROPERTIES PREFIX "")
  else()
    set_target_properties(${NAME} PROPERTIES PREFIX "lib")
  endif()
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
