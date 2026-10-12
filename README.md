# juiz_examples_cpp

ロボット・IoT 向けミドルウェア [juiz](https://github.com/OpenJUIZ/juiz) の C++ 版サンプル集です。
`juiz` コマンドは crates.io の [juiz_app](https://crates.io/crates/juiz_app) 0.0.10 を使います。C++ 用のヘッダと `libjuiz_sdk` はビルド時に CMake が juiz のリポジトリから自動で取得するので、juiz のソースを手元に用意する必要はありません。

Rust 版は [juiz_examples_rust](https://github.com/OpenJUIZ/juiz_examples_rust)、Python 版は [juiz_examples_python](https://github.com/OpenJUIZ/juiz_examples_python) にあります。

## しくみ

C++ で書いた Process や Container は共有ライブラリ (`lib*.so`、macOS では `lib*.dylib`) としてビルドし、`juiz` コマンドが設定ファイル (`*.conf`) を読んでプラグインとして読み込みます。

C++ のプラグインは juiz の C++ ヘッダ (`bindings/cppjuiz/include`) を使って書き、juiz_sdk の共有ライブラリ `libjuiz_sdk` とリンクします。
どちらも `cargo install juiz_app` では入らないので、このリポジトリの CMake ([cmake/Juiz.cmake](cmake/Juiz.cmake)) が次のことを行います。

1. GitHub から juiz のソースを取得する (ヘッダを使うため)
2. その中の juiz_sdk を `cargo build --release -p juiz_sdk` でビルドする
3. `libjuiz_sdk` をプラグインと同じ `build/plugins` に置き、プラグインには自分と同じ場所からライブラリを探す RPATH を付ける

## 必要なもの

- Linux (macOS は未確認)
- Rust (stable)。インストールは https://rustup.rs/ を参照してください。
- CMake 3.16 以降と C++17 対応のコンパイラ (Ubuntu なら `sudo apt install cmake g++`)
- git

## 1. juiz コマンドをインストールする

```sh
cargo install juiz_app
```

`juiz` コマンドが `~/.cargo/bin` に入ります。

## 2. サンプルをビルドする

```sh
git clone https://github.com/OpenJUIZ/juiz_examples_cpp.git
cd juiz_examples_cpp
cmake -S . -B build
cmake --build build
```

初回は juiz の取得と juiz_sdk のビルドに少し時間がかかります。
ビルドしたプラグインは `build/plugins` に出力されます。設定ファイルは `./build/plugins` からプラグインを探すので、**リポジトリのルートで** `juiz` を実行してください。

手元に juiz のソースがある場合は、それを使うこともできます。

```sh
cmake -S . -B build -DJUIZ_SOURCE_DIR=/path/to/juiz
```

## 3. 動かしてみる

### Process: increment_process_cpp

引数に 1 を足して返すだけの Process です ([process/increment_process_cpp](process/increment_process_cpp/increment_process_cpp.cpp))。

```cpp
#include "juiz/juiz.h"

auto manifest() {
    return ProcessManifest{"increment_process_cpp"}
        .description("Adds 1 to arg1.")
        .add_int_arg("arg1", "value to be incremented", 1);
}

std::optional<int64_t> increment_process_cpp(int64_t arg1) {
    return arg1 + 1;
}

PROCESS_FACTORY(manifest, increment_process_cpp);
```

`manifest()` で Process の名前と引数 (名前・説明・既定値) を宣言し、`PROCESS_FACTORY` で juiz から呼び出せるようにします。
関数の引数は `manifest()` で宣言した順に渡されます。値を返せないときは `std::nullopt` を返すとエラーになります。

```sh
juiz -f increment_process.conf -d
```

`-d` を付けると HTTP ブローカー (8000 番ポート) を立ち上げて待機します (Ctrl+C で終了)。
別のターミナルから呼び出せます。

```sh
juiz process list
juiz process call "http://127.0.0.1:8000/process/increment0::increment_process_cpp" '{"arg1": 3}' -p
# => CapsulePtr((value:Value(4), option: []))
```

ブラウザで http://127.0.0.1:8000/docs を開くと Swagger UI からも試せます。

`decrement_process.conf` も同じ使い方です (1 を引く Process)。

```sh
juiz -f decrement_process.conf -d
juiz process call "http://127.0.0.1:8000/process/decrement0::decrement_process_cpp" '{"arg1": 3}' -p
# => CapsulePtr((value:Value(2), option: []))
```

### Process の接続: talker / listener

`talker_cpp` の出力を `listener_cpp` の引数 `arg1` に Push 接続し、実行コンテキスト (main_loop_ec) で 1Hz で `talker_cpp` を動かします。

```sh
juiz -f talker_listener.conf -d
# talker_cpp: Hello, Juiz!
# listener_cpp: Hello, Juiz!
# ...
```

### Container: example_container_cpp

状態 (整数値) を持つ Container と、それを操作する ContainerProcess (`example_container_cpp_increment`、`example_container_cpp_get`) のサンプルです。
Container のクラス ([example_container_cpp.h](container/example_container_cpp/example_container_cpp.h)) を Container と ContainerProcess で共有します。

Container を作る関数は、設定ファイルの `containers` に書いた項目を `juiz::CapsuleMap` で受け取ります。この例では `value: 10` を初期値にしています。

```cpp
ExampleContainer* create_container(juiz::CapsuleMap args) {
    int64_t initial_value = 0;
    if (args.has("value")) {
        initial_value = args.get_int("value");
    }
    return new ExampleContainer(initial_value);
}

CONTAINER_FACTORY(manifest, create_container);
```

ContainerProcess は、最初の引数で Container を受け取ります。

```cpp
std::optional<int64_t> example_container_cpp_increment(ExampleContainer* container, int64_t arg1) {
    container->value += arg1;
    return container->value;
}

CONTAINER_PROCESS_FACTORY(ExampleContainer, manifest, example_container_cpp_increment);
```

```sh
juiz -f example_container.conf -d
```

別のターミナルから呼び出すたびに値が増えていきます。

```sh
juiz container-process call "http://127.0.0.1:8000/container_process/increment0::example_container_cpp_increment:container0" '{"arg1": 5}' -p
# => CapsulePtr((value:Value(15), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/get0::example_container_cpp_get:container0" '{}' -p
# => CapsulePtr((value:Value(15), option: []))
```

### Component: example_component_cpp

1 つのライブラリに Process・Container・ContainerProcess をまとめて入れる Component のサンプルです ([component/example_component_cpp](component/example_component_cpp/example_component_cpp.cpp))。
各要素を `COMPONENT_PROCESS_FACTORY` などで公開し、最後に `component_manifest()` でまとめて宣言します。

```sh
juiz -f example_component.conf -d
juiz process call "http://127.0.0.1:8000/process/proc0::example_component_cpp_increment" '{"arg1": 1}' -p
# => CapsulePtr((value:Value(2), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/increment0::example_component_cpp_container_increment:container0" '{"arg1": 5}' -p
# => CapsulePtr((value:Value(105), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/get0::example_component_cpp_container_get:container0" '{}' -p
# => CapsulePtr((value:Value(105), option: []))
```

Component に入れた Container を設定ファイルの `containers` で作るには juiz 0.0.10 以降が必要です (0.0.9 では起動時にエラーになります)。

## 構成

| パス | 内容 |
| --- | --- |
| `process/` | Process (入力と出力を持つ冪等な関数) のサンプル |
| `container/` | Container (状態を持つ) と ContainerProcess のサンプル |
| `component/` | 複数の要素を 1 つのライブラリにまとめた Component のサンプル |
| `cmake/Juiz.cmake` | juiz のヘッダと libjuiz_sdk を用意し、`add_juiz_process()` などを定義する |
| `*.conf` | 各サンプルを動かすための juiz の設定ファイル |

## 自分で書くときは

`.cpp` ファイルを作り、そのディレクトリの `CMakeLists.txt` に追加します。
ターゲット名は設定ファイルに書く名前 (`process_factories` などのキー) と同じにしてください。juiz はその名前から `lib<名前>.so` を探します。

```cmake
add_juiz_process(my_process SOURCES my_process/my_process.cpp)
```

Container は `add_juiz_container()`、ContainerProcess は `add_juiz_container_process()`、Component は `add_juiz_component()` で追加します。

## juiz の版について

CMake が取得する juiz の版は `JUIZ_GIT_TAG` で決まります。既定値は `v0.0.10` で、crates.io の juiz_app 0.0.10 と組み合わせて使います。
別の版を使うときは、`cargo install juiz_app` で入れた版と合わせて指定してください。

```sh
cmake -S . -B build -DJUIZ_GIT_TAG=<タグかコミット>
```
