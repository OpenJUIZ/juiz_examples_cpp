# juiz_examples_cpp

ロボット・IoT 向けミドルウェア [juiz](https://github.com/OpenJUIZ/juiz) の C++ 版サンプル集です。
`juiz` コマンドは crates.io の [juiz_app](https://crates.io/crates/juiz_app) 0.2.8 を使います。C++ 用のヘッダと `libjuiz_sdk` はビルド時に CMake が juiz の [GitHub Releases](https://github.com/OpenJUIZ/juiz/releases) から自動で取得するので、juiz のソースを手元に用意したり、`libjuiz_sdk` をビルドしたりする必要はありません。

Rust 版は [juiz_examples_rust](https://github.com/OpenJUIZ/juiz_examples_rust)、Python 版は [juiz_examples_python](https://github.com/OpenJUIZ/juiz_examples_python) にあります。

> **自分の部品を新しく作り始めるときは**、サンプルを写す代わりに `juiz pkg create my_robot -b cpp` で雛形を作れます (juiz 0.2.6 から)。ビルド・起動・呼び出し・`.juizapp` での配布までそのまま通る形で、SDK の版も `juiz` コマンドと同じ版で書かれます。詳しくは公式サイトの [雛形から始める (juiz pkg)](https://openjuiz.github.io/ja/guides/pkg/) を見てください。

## しくみ

C++ で書いた Process や Container は共有ライブラリ (`lib*.so`、macOS では `lib*.dylib`、Windows では `*.dll`) としてビルドし、`juiz` コマンドが設定ファイル (`*.conf`) を読んでプラグインとして読み込みます。

C++ のプラグインは juiz の C++ ヘッダ (`bindings/cppjuiz/include`) を使って書き、juiz_sdk の共有ライブラリ `libjuiz_sdk` とリンクします。
どちらも `cargo install juiz_app` では入らないので、このリポジトリの CMake ([cmake/Juiz.cmake](cmake/Juiz.cmake)) が次のことを行います。

1. juiz の GitHub Releases から、`juiz` コマンドと同じ版の `juiz_sdk-<版>-<ターゲット>.tar.gz` (Windows は `.zip`。`libjuiz_sdk` と C / C++ のヘッダ) を `build/juiz_sdk_archive` に取得する (チェックサムも確かめる)
2. `libjuiz_sdk` をプラグインと同じ `build/plugins` に置き、プラグインには自分と同じ場所からライブラリを探す RPATH を付ける (Windows では、juiz がプラグインの隣の `juiz_sdk.dll` を探す)
3. データ型のサンプルでは、`juiz idl` (`juiz` コマンドに入っている型の生成器) で C++ の型を作る

アーカイブを配布しているのは Linux (x86_64・aarch64) と macOS (arm64・x86_64) で、juiz 0.0.26 からです。Windows (x86_64) は 0.0.27 からです。
アーカイブを取得できないときは、これまでどおり juiz のソースを取得して `cargo build --release -p juiz_sdk` でビルドします ([ソースからビルドする](#ソースからビルドする))。

## 必要なもの

- Linux・macOS・Windows (x86_64)
- Rust (stable)。Linux・macOS で `juiz` コマンドのインストールに使います。インストールは https://rustup.rs/ を参照してください。
- CMake 3.16 以降と C++17 対応のコンパイラ (Ubuntu なら `sudo apt install cmake g++`、Windows は Visual Studio 2022 か Build Tools for Visual Studio 2022)
- Windows では Python 3.10 以降 (`juiz` コマンドを pip で入れます)

## 1. juiz コマンドをインストールする

```sh
cargo install juiz_app
```

`juiz` コマンドが `~/.cargo/bin` に入ります。

Windows では、pip で [juiz-cli](https://pypi.org/project/juiz-cli/) を入れます (PowerShell)。

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install juiz-cli
```

## 2. サンプルをビルドする

```sh
git clone https://github.com/OpenJUIZ/juiz_examples_cpp.git
cd juiz_examples_cpp
cmake -S . -B build
cmake --build build
```

Windows (Visual Studio のジェネレータ) では `cmake --build build --config Release` でビルドします。

初回は `libjuiz_sdk` のアーカイブを取得します。
ビルドしたプラグインは `build/plugins` に出力されます。設定ファイルは `./build/plugins` からプラグインを探すので、**リポジトリのルートで** `juiz` を実行してください。

### ソースからビルドする

アーカイブの代わりに juiz のソースから `libjuiz_sdk` と `juiz-idl` をビルドすることもできます (Rust と git が要ります)。
juiz 本体を手元で直しながら試すときなどに使います。

```sh
# 手元にある juiz のソースを使う
cmake -S . -B build -DJUIZ_SOURCE_DIR=/path/to/juiz
# GitHub から JUIZ_GIT_TAG のソースを取得してビルドする
cmake -S . -B build -DJUIZ_SDK_FROM_SOURCE=ON
```

`JUIZ_GIT_TAG` にタグ (`v<版>`) 以外 (ブランチやコミット) を指定したときも、ソースからビルドします。

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

> データ型は juiz 0.0.23 から使えます。juiz コマンドと、Python の Process が使う pyjuiz は 0.0.23 以降を入れてください。
>
> ```sh
> cargo install juiz_app --version 0.2.8 --locked
> pip install pyjuiz==0.2.8
> ```

C++ の Process [process/pose_move_cpp](process/pose_move_cpp/pose_move_cpp.cpp) は、types/geometry.jidl から作った型 (`juiz_idl.h`) をそのまま引数と戻り値に使います。型は CMake の関数 `juiz_generate_types()` がビルドのときに作ります (生成器は PATH の `juiz-idl`、無ければ `juiz idl` を使います。ソースからビルドするときは同じソースの `juiz-idl` をビルドして使います)。

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

### Transformations: 部品の位置関係を木にする

ロボットの部品 (台車・雲台・カメラ) を Container にし、部品同士のつながり (Transform) と基点 (Anchor) を設定ファイルに書くと、juiz が各部品の位置姿勢 (ContainerPose) を計算します。

> juiz 0.2.0 から使える機能です。

`transformations.conf` の木は次のとおりです。`map` と `odom` は juiz に組み込みの Anchor で、プラグインは要りません。

```text
map (PeriodicExecutionAnchor, 10 Hz)     … 10 Hz で木をたどって位置姿勢を計算し直す
└─ odom (StaticAnchor)                   … 書き込みがあったときだけ計算し直す。map から (1, 2, 0) ずれている
   └─ base0 (台車 mobile_base_cpp)        … move0 がオドメトリを set_pose で書く
      └─ pantilt0 (雲台 pantilt_cpp)      … 台車の (0.1, 0, 0.3) に付く。pan0 がパン角を書く
         └─ camera0 (カメラ camera_cpp)   … 雲台の (0.05, 0, 0.02) に付く。Transform だけ
```

部品は `component/mobile_robot_cpp` の 1 つの Component です。ContainerProcess の中では `juiz::pose(container, "map")` で読み、`juiz::set_pose(container, "odom", pose)` で書きます (`juiz/pose.h`)。`set_pose` は親 → 自分の Transform を書き換えるので、子の雲台・カメラも一緒に動きます。

```cpp
std::optional<juiz::Value> mobile_base_cpp_move(MobileBase* base, const double vx, const double omega, const double dt,
                                                const std::string& reference) {
    base->x += vx * std::cos(base->theta) * dt;
    base->y += vx * std::sin(base->theta) * dt;
    base->theta += omega * dt;
    auto p = juiz::set_pose(base, reference, yaw_pose(base->x, base->y, 0.0, base->theta));
    return juiz::pose_to_value(p, reference);
}
```

また `pose_listeners:` で、台車の位置姿勢が書かれたら Process `print0` (`pose_print_cpp`) を呼ぶ Pose 通知を登録しています。

```sh
juiz -f transformations.conf -d
```

別の端末で台車を動かし、雲台を 90 度回します。

```sh
juiz container-process call "http://127.0.0.1:8000/container_process/move0::mobile_base_cpp_move:base0" '{"vx": 1.0, "dt": 1.0}' -p
# => CapsulePtr((value:Value({"header":{"frame_id":"odom",...},"pose":{"orientation":{...},"position":{"x":1.0,"y":0.0,"z":0.0}}}), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/pan0::pantilt_cpp_set_pan:pantilt0" '{"pan": 1.5707963267948966}' -p
```

1 つ目の呼び出しで、juiz を起動した端末に Pose 通知の出力が出ます。

```text
pose_print_cpp: x=1.00 y=0.00 yaw=0.0deg (from odom)
```

カメラの位置姿勢を読みます。雲台が回ったので、カメラは台車の左 (y = 0.05) に来ています。`map` から見ると `map` → `odom` のずれ (1, 2, 0) が足されます。

```sh
juiz container pose camera0 --reference odom
# => position: x=1.1, y=0.05, z=0.32 (JSON の PoseStamped)
juiz container pose camera0 --reference map
# => position: x=2.1, y=2.05, z=0.32
juiz container-process call "http://127.0.0.1:8000/container_process/camera_pose0::camera_cpp_pose:camera0" '{"reference": "map"}' -p
juiz anchor tree map
# map  position (0, 0, 0)  orientation (0, 0, 0, 1)
# └─ odom  position (1, 2, 0)  orientation (0, 0, 0, 1)
#    └─ base0  position (2, 2, 0)  orientation (0, 0, 0, 1)
#       └─ pantilt0  position (2.1, 2, 0.3)  orientation (0, 0, 0.7071067811865475, 0.7071067811865476)
#          └─ camera0  position (2.1, 2.05, 0.32)  orientation (0, 0, 0.7071067811865475, 0.7071067811865476)
```

`map` は Periodic なので、書き込みの直後に読むと最大 1 周期 (0.1 秒) 古い値が返ります。`odom` は Static なので、`set_pose` が戻った時点で新しい値になっています。
管理画面 (`http://127.0.0.1:8000/ui`) の「変換木」でも木と位置姿勢を見られます。

#### 読むだけの ContainerProcess: readonly

カメラの `camera_cpp_pose` は位置姿勢を読むだけなので、readonly の ContainerProcess にしています。manifest に `.readonly()` を付け、Container を `const` のポインタで受け取ります。

```cpp
static auto camera_cpp_pose_manif = ProcessManifest("camera_cpp_pose")
    .readonly()
    .add_string_arg("reference", "reference container", "map");
std::optional<juiz::Value> camera_cpp_pose(const Camera* camera, const std::string& reference) {
    return juiz::pose_to_value(juiz::pose(camera, reference), reference);
}
COMPONENT_CONTAINER_PROCESS_FACTORY(Camera, camera_cpp_pose_manif, camera_cpp_pose);
```

juiz は readonly の ContainerProcess を Container の読み出しロックで呼ぶので、同じ Container の readonly 同士は並行に走ります (readonly でないものとは順番に走ります)。`const` の Container に `juiz::set_pose` を呼ぶとコンパイルエラーになります。
readonly かどうかは ContainerProcess の情報 (HTTP の API) に出ます。

```sh
curl "http://127.0.0.1:8000/api/container_process/profile_full?identifier=core://core/container_process/camera_pose0::camera_cpp_pose:camera0"
# => {..."readonly":true,...}
```

> juiz 0.2.2 から使える機能です。

#### System をまたぐ: transformations_map.conf と transformations_robot.conf

上の木を、地図の System とロボットの System の 2 つに分けた版です。地図 (`map`) を持つ System と、台車・雲台・カメラを持つ System を別のプロセスで動かし、ロボットの System から `map` を基準に読めます。

> juiz 0.2.1 から使える機能です。

```text
地図の System (transformations_map.conf、ポート 8000)
map (PeriodicExecutionAnchor, 10 Hz)
 ┊  map → odom の Transform はロボットの System が持ち、map の位置を取りに来る (写し)
ロボットの System (transformations_robot.conf、ポート 8001)
└─ odom (StaticAnchor) → base0 (台車) → pantilt0 (雲台) → camera0 (カメラ)
```

`map → odom` の Transform は、子の `odom` を持つロボットの System の設定ファイルに書きます。始点は地図の System の `map` をブローカー付きの ID で書き、取りに行く頻度 `rate` (Hz) と、つながらないときに写しを消すまでの `timeout` (秒) を付けます。地図の System の設定ファイルには `map` を置くだけです。

```yaml
# transformations_robot.conf (抜粋)
transforms:
  - source: http://127.0.0.1:8000/container/map::periodic_anchor
    destination: odom
    translation: {x: 1.0, y: 2.0, z: 0.0}
    rate: 10.0
    timeout: 3.0
```

2 つの端末で、地図の System、ロボットの System の順に起動します (逆の順でも、地図の System が起動した時点で取り込みが始まります)。

```sh
juiz -f transformations_map.conf -d
juiz -f transformations_robot.conf -d
```

別の端末で、上と同じく台車を動かし雲台を回します (ロボットの System はポート 8001)。

```sh
juiz container-process call "http://127.0.0.1:8001/container_process/move0::mobile_base_cpp_move:base0" '{"vx": 1.0, "dt": 1.0}' -p
juiz container-process call "http://127.0.0.1:8001/container_process/pan0::pantilt_cpp_set_pan:pantilt0" '{"pan": 1.5707963267948966}' -p
```

ロボットの System には `map` がありませんが、名前 `map` は地図の System の `map` の写しに解決します。基準 (`frame_id`) は写しの ID です。

```sh
juiz -s http://127.0.0.1:8001 container pose camera0 --reference map
# => position: x=2.1, y=2.05, z=0.32、frame_id: http://127.0.0.1:8000/container/map::periodic_anchor
juiz -s http://127.0.0.1:8001 transform list --long
# http://127.0.0.1:8000/container/map::periodic_anchor -> core://core/container/odom::static_anchor  translation (1, 2, 0)  rotation (0, 0, 0, 1)  (remote: ok)
# ...
juiz -s http://127.0.0.1:8001 anchor tree map
# map  position (0, 0, 0)  orientation (0, 0, 0, 1)
# └─ odom  position (1, 2, 0)  orientation (0, 0, 0, 1)
#    └─ ...
```

地図の System からも、ロボットの System の Container を ID で指定すれば `map` から見て読めます (ロボットの System に回ります)。地図の System の木にはロボットの部品は入らず、`map` に「取りに来ている System がある」印だけが付きます。

```sh
juiz container pose "http://127.0.0.1:8001/container/camera0::camera_cpp" --reference map
# => position: x=2.1, y=2.05, z=0.32、frame_id: map
juiz container list --long
# /          map   periodic_anchor  http://127.0.0.1:8000/container/map::periodic_anchor
#     anchor: periodic (10 Hz)
#     remote child: <ロボットの System の UUID> -> core://core/container/odom::static_anchor
```

地図の System を止めると、ロボットの System は `timeout` (3 秒) の後に写しを消し、`transform list --long` が `(remote: lost)` になります。`map` を基準に読むと「つながらない」エラーになりますが、`odom` を基準にした読み書きはそのまま続けられます。地図の System を起動し直すと、自動で写しが戻ります。
管理画面 (`http://127.0.0.1:8001/ui`) の「変換木」では、写しが破線と「写し」の印で表示されます。

### アプリを .juizapp で配る

`packages/talker_listener/` を、1 つのファイル (`.juizapp`、zip) にまとめて配れます (juiz 0.0.28 から)。受け取った人は、CMake も C++ のコンパイラも無しに `juiz run` だけで動かせます。

```sh
python3 scripts/make_packages.py      # 先に cmake --build build でビルドしておく
# Packed talker_listener 0.1.0 (x86_64-unknown-linux-gnu; 6 files) into .../dist/talker_listener-0.1.0-x86_64-unknown-linux-gnu.juizapp
juiz run dist/talker_listener-0.1.0-x86_64-unknown-linux-gnu.juizapp
# talker_cpp: Hello, Juiz!
# listener_cpp: Hello, Juiz!
```

`packages/talker_listener/` に置くのはマニフェスト `juizapp.yaml` と設定ファイル `app.conf` だけです。`app.conf` はプラグインを `path: "plugins/{target}"` で参照し、`scripts/make_packages.py` が `build/plugins` のプラグインと `libjuiz_sdk` を `plugins/<この機械のターゲット>/` に写してから `juiz pack --target <ターゲット>` を呼びます。
プラグインの RPATH は自身の場所 (`$ORIGIN` / `@loader_path`) だけにしてあるので (`cmake/Juiz.cmake`)、隣に置いた `libjuiz_sdk` が使われます。Windows の juiz はプラグインの DLL の隣から `juiz_sdk.dll` を探します。
タグ (`v*`) を付けると、CI が Linux (x86_64) と Windows (x86_64) で作った `.juizapp` を [Releases](https://github.com/OpenJUIZ/juiz_examples_cpp/releases) に載せます。

## 構成

| パス | 内容 |
| --- | --- |
| `process/` | Process (入力と出力を持つ冪等な関数) のサンプル |
| `container/` | Container (状態を持つ) と ContainerProcess のサンプル |
| `component/` | 複数の要素を 1 つのライブラリにまとめた Component のサンプル (`mobile_robot_cpp` は Transformations の部品) |
| `types/` | 4 つのサンプルリポジトリで共通に使う型 (JIDL) |
| `python/` | データ型のサンプルで C++ の Process とつなぐ Python の Process |
| `cmake/Juiz.cmake` | juiz のヘッダと libjuiz_sdk (Releases のアーカイブ)・juiz-idl を用意し、`add_juiz_process()`・`juiz_generate_types()` などを定義する |
| `*.conf` | 各サンプルを動かすための juiz の設定ファイル |
| `packages/` | `.juizapp` にするアプリのマニフェストと設定ファイル |
| `scripts/make_packages.py` | ビルドしたプラグインを `packages/` のアプリに写し、`dist/` に `.juizapp` を作るスクリプト |
| `tests/test_examples.py` | 上のサンプルを起動して呼び出し、結果を確かめるテスト (ビルドのあと `python3 tests/test_examples.py`)。CI でも実行する |

## 自分で書くときは

`.cpp` ファイルを作り、そのディレクトリの `CMakeLists.txt` に追加します。
ターゲット名は設定ファイルに書く名前 (`process_factories` などのキー) と同じにしてください。juiz はその名前から `lib<名前>.so` を探します。

```cmake
add_juiz_process(my_process SOURCES my_process/my_process.cpp)
```

Container は `add_juiz_container()`、ContainerProcess は `add_juiz_container_process()`、Component は `add_juiz_component()` で追加します。

## juiz の版について

CMake が取得する juiz (libjuiz_sdk のアーカイブ) の版は `JUIZ_GIT_TAG` で決まります。既定値は `v0.2.8` で、crates.io の juiz_app 0.2.8 と組み合わせて使います。

別の版を使うときは、`cargo install juiz_app` で入れた版と合わせて指定してください。juiz は版の違う libjuiz_sdk でビルドしたプラグインを読み込みません。

```sh
cmake -S . -B build -DJUIZ_GIT_TAG=v<版>
```

PowerShell では、`-` で始まる引数が `.` の位置で切られ、CMake に `JUIZ_GIT_TAG=v0` だけが渡ってしまいます (`Failed to checkout tag: 'v0'` になります)。引数全体を引用符で囲んでください。

```powershell
cmake -S . -B build '-DJUIZ_GIT_TAG=v0.2.8'
```

アーカイブは 0.0.26 からなので、それより前の版やコミットを指定したときは juiz のソースからビルドします。

## ライセンス

このリポジトリのサンプルは、次のどちらかのライセンスを選んで利用できます(デュアルライセンス)。

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) または <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT License ([LICENSE-MIT](LICENSE-MIT) または <https://opensource.org/licenses/MIT>)

Licensed under either of Apache License, Version 2.0 or MIT license at your option.

### コントリビューション

明示的に別の意思表示をしない限り、このリポジトリに提出されたコントリビューションは、Apache-2.0 ライセンスの定義に従い、追加の条件なしに上記と同じデュアルライセンスで提供されるものとします。

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
