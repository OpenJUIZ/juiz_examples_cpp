// Transformations のサンプル: 台車 → 雲台 → カメラ の部品 (OpenJUIZ/juiz#374)。
//
// 位置姿勢 (ContainerPose) は juiz が Container ごとに持ち、利用者の状態とは別にある。
// 部品のつながり (Transform) と基点 (Anchor) は transformations.conf に書く:
//
//   map (Periodic) → odom (Static) → base0 (mobile_base_cpp) → pantilt0 (pantilt_cpp) → camera0 (camera_cpp)
//
// - mobile_base_cpp_move はオドメトリを積分して、odom から見た自分の位置姿勢を juiz::set_pose で書く。
// - pantilt_cpp_set_pan はパン角を書く (台車から見た自分の向きだけを変える)。
// - camera_cpp_pose は基準から見た自分の位置姿勢を juiz::pose で読む。カメラは Transform で雲台につながっているだけ。
//   読むだけなので readonly にしている。
// - pose_print_cpp は Pose 通知 (conf の pose_listeners:) で呼ばれる Process。
// MSVC の <cmath> は _USE_MATH_DEFINES が無いと M_PI を定義しない。最初の include より前に書く
#define _USE_MATH_DEFINES
#include <cmath>
#include <cstdio>
#include <iostream>
#include <string>
#include "juiz/juiz.h"

// z 軸まわりに yaw [rad] 回す姿勢で、位置 (x, y, z) の juiz_pose を作る
static juiz_pose yaw_pose(double x, double y, double z, double yaw) {
    return juiz::make_pose(x, y, z, 0.0, 0.0, std::sin(yaw / 2), std::cos(yaw / 2));
}

// 台車。オドメトリ (odom から見た x, y, 向き theta) を自分で積分して持つ
class MobileBase {
public:
    double x = 0.0, y = 0.0, theta = 0.0;
};

static auto mobile_base_cpp_manif = ContainerManifest("mobile_base_cpp");
MobileBase* mobile_base_cpp(juiz::CapsuleMap) {
    return new MobileBase();
}
COMPONENT_CONTAINER_FACTORY(mobile_base_cpp_manif, mobile_base_cpp);

// 速度 vx [m/s]・角速度 omega [rad/s] で dt [s] 動かし、基準 reference (odom) から見た位置姿勢を書く
static auto mobile_base_cpp_move_manif = ProcessManifest("mobile_base_cpp_move")
    .add_float_arg("vx", "velocity [m/s]", 0.0)
    .add_float_arg("omega", "angular velocity [rad/s]", 0.0)
    .add_float_arg("dt", "time step [s]", 1.0)
    .add_string_arg("reference", "reference container", "odom");
std::optional<juiz::Value> mobile_base_cpp_move(MobileBase* base, const double vx, const double omega, const double dt,
                                                const std::string& reference) {
    base->x += vx * std::cos(base->theta) * dt;
    base->y += vx * std::sin(base->theta) * dt;
    base->theta += omega * dt;
    // odom → base0 の Transform が書き換わり、Pose 通知が出る
    auto p = juiz::set_pose(base, reference, yaw_pose(base->x, base->y, 0.0, base->theta));
    return juiz::pose_to_value(p, reference);
}
COMPONENT_CONTAINER_PROCESS_FACTORY(MobileBase, mobile_base_cpp_move_manif, mobile_base_cpp_move);

// 雲台。パン角を持つ
class Pantilt {
public:
    double pan = 0.0;
};

static auto pantilt_cpp_manif = ContainerManifest("pantilt_cpp");
Pantilt* pantilt_cpp(juiz::CapsuleMap) {
    return new Pantilt();
}
COMPONENT_CONTAINER_FACTORY(pantilt_cpp_manif, pantilt_cpp);

// パン角 pan [rad] にする。取り付け位置はそのままで、基準 reference (台車) から見た向きだけを変える
static auto pantilt_cpp_set_pan_manif = ProcessManifest("pantilt_cpp_set_pan")
    .add_float_arg("pan", "pan angle [rad]", 0.0)
    .add_string_arg("reference", "reference container", "base0");
std::optional<juiz::Value> pantilt_cpp_set_pan(Pantilt* pantilt, const double pan, const std::string& reference) {
    pantilt->pan = pan;
    auto mount = juiz::pose(pantilt, reference).pose.position;
    auto p = juiz::set_pose(pantilt, reference, yaw_pose(mount.x, mount.y, mount.z, pan));
    return juiz::pose_to_value(p, reference);
}
COMPONENT_CONTAINER_PROCESS_FACTORY(Pantilt, pantilt_cpp_set_pan_manif, pantilt_cpp_set_pan);

// カメラ。利用者の状態は持たない
class Camera {};

static auto camera_cpp_manif = ContainerManifest("camera_cpp");
Camera* camera_cpp(juiz::CapsuleMap) {
    return new Camera();
}
COMPONENT_CONTAINER_FACTORY(camera_cpp_manif, camera_cpp);

// 基準 reference から見た自分の位置姿勢 (juiz_std.geometry.PoseStamped の辞書)。
// 読むだけなので readonly にする (OpenJUIZ/juiz#377)。manifest に readonly() を付け、Container を const のポインタで受け取る。
// juiz は Container を読み出しロックで呼ぶので、同じ Container の readonly 同士は並行に走る。
// const の Container では juiz::set_pose はコンパイルエラーになる
static auto camera_cpp_pose_manif = ProcessManifest("camera_cpp_pose")
    .readonly()
    .add_string_arg("reference", "reference container", "map");
std::optional<juiz::Value> camera_cpp_pose(const Camera* camera, const std::string& reference) {
    return juiz::pose_to_value(juiz::pose(camera, reference), reference);
}
COMPONENT_CONTAINER_PROCESS_FACTORY(Camera, camera_cpp_pose_manif, camera_cpp_pose);

// 辞書の数 (整数でも小数でもよい)
static double number(const juiz::Value& v) {
    if (v.isDoubleValue()) return v.doubleValue();
    if (v.isIntValue()) return static_cast<double>(v.intValue());
    return 0.0;
}

// Pose 通知の受け手。受け取った位置姿勢 (juiz_std.geometry.PoseStamped の辞書) を表示する
static auto pose_print_cpp_manif = ProcessManifest("pose_print_cpp")
    .add_object_arg("pose", "juiz_std.geometry.PoseStamped");
std::optional<std::string> pose_print_cpp(const juiz::Value& pose) {
    const auto& position = pose["pose"]["position"];
    const auto& q = pose["pose"]["orientation"];
    const double qx = number(q["x"]), qy = number(q["y"]), qz = number(q["z"]), qw = number(q["w"]);
    const double yaw = std::atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz));
    char buf[160];
    std::snprintf(buf, sizeof(buf), "pose_print_cpp: x=%.2f y=%.2f yaw=%.1fdeg (from %s)", number(position["x"]),
                  number(position["y"]), yaw * 180.0 / M_PI, pose["header"]["frame_id"].stringValue().c_str());
    std::cout << buf << std::endl;
    return std::string(buf);
}
COMPONENT_PROCESS_FACTORY(pose_print_cpp_manif, pose_print_cpp);

auto component_manifest() {
    return ComponentManifest("mobile_robot_cpp")
        .add_process(pose_print_cpp_manifest())
        .add_container(mobile_base_cpp_manifest().add_process(mobile_base_cpp_move_manifest()))
        .add_container(pantilt_cpp_manifest().add_process(pantilt_cpp_set_pan_manifest()))
        .add_container(camera_cpp_manifest().add_process(camera_cpp_pose_manifest()));
}
DEFINE_COMPONENT_MANIFEST_ENTRY_POINT(component_manifest)
