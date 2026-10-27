# juiz_examples_cpp

ロボット・IoT 向けミドルウェア [juiz](https://github.com/OpenJUIZ/juiz) の C++ 版サンプル集です。
`juiz` コマンドは crates.io の [juiz_app](https://crates.io/crates/juiz_app) を使います (データ型のサンプルは juiz の次の版 0.0.23 で入る機能を使うので、公開までは juiz の main のコミットを使います。「[データ型](#データ型-言語をまたいで同じ型を使う)」を見てください)。C++ 用のヘッダと `libjuiz_sdk` はビルド時に CMake が juiz のリポジトリから自動で取得するので、juiz のソースを手元に用意する必要はありません。

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

Swagger UI は http://127.0.0.1:8000/docs/ で開けます。API の定義 (OpenAPI) は http://127.0.0.1:8000/api-docs/openapi.json で取得できます。

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

### ネームスペース: 同じ構成を並べて動かす

ネームスペースを使うと、同じ名前の Process を 1 つの System に並べて置けます。ID はクラスの後ろ・名前の前にネームスペースが入った `http://127.0.0.1:8000/process/robot1/talker0::talker_cpp` の形になります。

#### 1 つの設定ファイルで 2 台分を置く: namespace.conf

`talker0` と `listener0` を `robot1` と `robot2` の 2 つのネームスペースに置き、Topic `chatter` でつなぎます。Topic 名もネームスペースの中で解決される (`robot1/chatter` と `robot2/chatter`) ので、それぞれの `listener0` には同じネームスペースの `talker0` の出力だけが届きます。

```sh
juiz -f namespace.conf -d
# talker_cpp: Hello from robot1
# listener_cpp: Hello from robot1
# talker_cpp: Hello from robot2
# listener_cpp: Hello from robot2
# ...
```

別のターミナルから、ネームスペースの列つきで一覧を出したり、ネームスペース付きの ID で呼び出したりできます。

```sh
juiz process list --long
# NAMESPACE  NAME       TYPE        ID
# /robot1    talker0    talker_cpp  http://127.0.0.1:8000/process/robot1/talker0::talker_cpp
# ...
juiz process call "http://127.0.0.1:8000/process/robot1/talker0::talker_cpp" '{"message": "Hi"}' -p
# => CapsulePtr((value:Value("Hi"), option: []))
```

設定ファイルでは各要素に `namespace` を書きます (`/` で始めるとルートからの絶対指定)。トップレベルに `namespace` を書くと、全体の既定のネームスペースになります。

#### 同じ設定ファイルを 2 つ起動する: --namespace

`--namespace` を付けると、設定ファイルの既定のネームスペースを置き換えて起動できます。2 つのターミナルで次のように起動すると、2 つ目は 1 つ目のサブシステムになり (8001 番ポートで待ち受け)、1 つの System として扱えます。

```sh
juiz -f increment_process.conf --namespace robot1 -d
```

```sh
juiz -f increment_process.conf --namespace robot2 -d
```

```sh
juiz process list --namespace robot2
# => ["http://127.0.0.1:8001/process/robot2/increment0::increment_process_cpp"]
juiz process call "http://127.0.0.1:8000/process/robot1/increment0::increment_process_cpp" '{"arg1": 1}' -p
# => CapsulePtr((value:Value(2), option: []))
juiz process call "http://127.0.0.1:8001/process/robot2/increment0::increment_process_cpp" '{"arg1": 10}' -p
# => CapsulePtr((value:Value(11), option: []))
```

### データ型: 言語をまたいで同じ型を使う

Process の引数と戻り値に型を付けられます。型は IDL (JIDL) で書き、生成器 `juiz-idl` で各言語の型を作ります。
このリポジトリの [types/geometry.jidl](types/geometry.jidl) は、C++・[Rust](https://github.com/OpenJUIZ/juiz_examples_rust)・[Python](https://github.com/OpenJUIZ/juiz_examples_python)・[Haskell](https://github.com/OpenJUIZ/juiz_examples_haskell) の 4 つのサンプルリポジトリで同じ中身にしてあり、どの言語で作っても型の指紋 (`@sha256:…`) が同じになります。指紋が同じ型どうしは、言語が違ってもそのままつながります。

```text
namespace examples.geometry;

record Point2D { double x = 0.0; double y = 0.0; }
record Pose2D  { Point2D position = {"x": 0.0, "y": 0.0}; double theta = 0.0; string frame_id = "map"; }
record Twist2D { double linear = 0.0; double angular = 0.0; }
```

> データ型は juiz の次の版 (0.0.23) で入ります。公開までは、`JUIZ_GIT_TAG` の既定値を juiz の main のコミットにしてあるので、juiz コマンドも同じコミットから入れてください。
>
> ```sh
> cargo install juiz_app --git https://github.com/OpenJUIZ/juiz --rev 43a2210c7affaf62f93dc48ad1fd53d77f326df2 --locked
> pip install "pyjuiz @ git+https://github.com/OpenJUIZ/juiz@43a2210c7affaf62f93dc48ad1fd53d77f326df2#subdirectory=bindings/pyjuiz"
> ```

C++ の Process [process/pose_move_cpp](process/pose_move_cpp/pose_move_cpp.cpp) は、types/geometry.jidl から作った型 (`juiz_idl.h`) をそのまま引数と戻り値に使います。型は CMake の関数 `juiz_generate_types()` がビルドのときに作ります (`juiz-idl` は CMake が juiz のソースからビルドします)。

```cmake
add_juiz_process(pose_move_cpp SOURCES pose_move_cpp/pose_move_cpp.cpp)
juiz_generate_types(pose_move_cpp IDL ${PROJECT_SOURCE_DIR}/types/geometry.jidl)
```

```cpp
#include "juiz/juiz.h"
#include "juiz_idl.h"
using examples::geometry::Pose2D;
using examples::geometry::Twist2D;

auto manifest() {
    return ProcessManifest{"pose_move_cpp"}
        .add_typed_arg<Pose2D>("pose", "current pose", Pose2D{})
        .add_typed_arg<Twist2D>("twist", "velocity", Twist2D{})
        .add_float_arg("dt", "duration [s]", 1.0)
        .returns<Pose2D>();
}
std::optional<Pose2D> pose_move_cpp(const Pose2D& pose, const Twist2D& twist, double dt) { … }
PROCESS_FACTORY(manifest, pose_move_cpp);
```

#### C++ と Python をつなぐ: typed_pose.conf

Python の Process ([python/](python/)) が出した `Twist2D` を C++ の `pose_move_cpp` が受け取り、`pose_move_cpp` が出した `Pose2D` を Python の Process が受け取ります。Python の Process には pyjuiz が要ります。

```text
twist0 (Python, Twist2D) --Pull--> move0 (C++, pose_move_cpp) --Push--> print0 (Python, Pose2D を表示)
```

先に Python の型を `gen/` に作ってから起動します (設定ファイルの `option.pythonpath` で `gen/` を読みます)。

```sh
juiz idl -g python -o gen types/geometry.jidl
juiz -f typed_pose.conf -d
```

別のターミナルから `move0` を実行 (execute) すると、`twist0` から速度を取ってきて動き、結果を `print0` に送ります。

```sh
curl -X PATCH "http://127.0.0.1:8000/api/process/execute?identifier=core://core/process/move0::pose_move_cpp" -H "Content-Type: application/json" -d '{}'
# => {"frame_id":"map","position":{"x":0.5,"y":0.0},"theta":0.0}
```

```text
pose_move_cpp: (0.00, 0.00, 0.00) -> (0.50, 0.00, 0.00)
pose_print_python receives Pose2D(x=0.50, y=0.00, theta=0.00, frame_id=map)
```

型付きの引数も、CLI や curl からは今までどおり辞書で渡せます。書かなかったフィールドは既定値になります。

```sh
juiz process call "http://127.0.0.1:8000/process/move0::pose_move_cpp" '{"pose": {"position": {"x": 1.0, "y": 2.0}}, "twist": {"linear": 1.0}, "dt": 2.0}' -p
# => CapsulePtr((value:Value({"frame_id":"map","position":{"x":3.0,"y":2.0},"theta":0.0}), option: []))
```

読み込んだ型は `juiz type` で見られます。C++ と Python の型の指紋が同じなので、1 つの型として登録されています。

```sh
juiz type list
# => ["examples.geometry.Point2D@sha256:5649ab39…","examples.geometry.Pose2D@sha256:123b8c15…","examples.geometry.Twist2D@sha256:115b9e0f…"]
juiz type show examples.geometry.Twist2D
# // examples.geometry.Twist2D@sha256:115b9e0f…
# // used by: pose_move_cpp, twist_python
# ...
```

#### 型が合わないとつながらない: typed_mismatch.conf

`twist0` の `Twist2D` を `move0` の引数 `pose` (`Pose2D`) につなごうとする設定ファイルです。juiz は接続を作らず、エラーで終わります。

```sh
juiz -f typed_mismatch.conf -d
# Error:setup_objects() failed in setup in system.rs
# ...
#     2: Type examples.geometry.Twist2D@sha256:115b9e0f… cannot be read as examples.geometry.Pose2D@sha256:123b8c15… at 'Pose2D': record name examples.geometry.Twist2D does not match examples.geometry.Pose2D (add an alias to read it)
```

## 構成

| パス | 内容 |
| --- | --- |
| `process/` | Process (入力と出力を持つ冪等な関数) のサンプル |
| `container/` | Container (状態を持つ) と ContainerProcess のサンプル |
| `component/` | 複数の要素を 1 つのライブラリにまとめた Component のサンプル |
| `types/` | 4 つのサンプルリポジトリで共通に使う型 (JIDL) |
| `python/` | データ型のサンプルで C++ の Process とつなぐ Python の Process |
| `cmake/Juiz.cmake` | juiz のヘッダと libjuiz_sdk・juiz-idl を用意し、`add_juiz_process()`・`juiz_generate_types()` などを定義する |
| `*.conf` | 各サンプルを動かすための juiz の設定ファイル |
| `tests/test_examples.py` | 上のサンプルを起動して呼び出し、結果を確かめるテスト (ビルドのあと `python3 tests/test_examples.py`)。CI でも実行する |

## 自分で書くときは

`.cpp` ファイルを作り、そのディレクトリの `CMakeLists.txt` に追加します。
ターゲット名は設定ファイルに書く名前 (`process_factories` などのキー) と同じにしてください。juiz はその名前から `lib<名前>.so` を探します。

```cmake
add_juiz_process(my_process SOURCES my_process/my_process.cpp)
```

Container は `add_juiz_container()`、ContainerProcess は `add_juiz_container_process()`、Component は `add_juiz_component()` で追加します。

## juiz の版について

CMake が取得する juiz の版は `JUIZ_GIT_TAG` で決まります。既定値は、データ型のサンプルのため juiz の main のコミット (`43a2210…`) にしてあり、同じコミットから入れた juiz コマンドと組み合わせて使います (juiz 0.0.23 の公開後はそのタグに戻します)。
別の版を使うときは、`cargo install juiz_app` で入れた版と合わせて指定してください。

```sh
cmake -S . -B build -DJUIZ_GIT_TAG=<タグかコミット>
```

## ライセンス

このリポジトリのサンプルは、次のどちらかのライセンスを選んで利用できます(デュアルライセンス)。

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) または <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT License ([LICENSE-MIT](LICENSE-MIT) または <https://opensource.org/licenses/MIT>)

Licensed under either of Apache License, Version 2.0 or MIT license at your option.

### コントリビューション

明示的に別の意思表示をしない限り、このリポジトリに提出されたコントリビューションは、Apache-2.0 ライセンスの定義に従い、追加の条件なしに上記と同じデュアルライセンスで提供されるものとします。

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
