#include <cmath>
#include <cstdio>

#include "juiz/juiz.h"
// types/geometry.jidl から juiz-idl が作った型 (process/CMakeLists.txt の juiz_generate_types)
#include "juiz_idl.h"

using examples::geometry::Point2D;
using examples::geometry::Pose2D;
using examples::geometry::Twist2D;

// 姿勢 pose から速度 twist で dt 秒動いた姿勢を返す Process
//
// 引数と戻り値が型付き (examples.geometry の Pose2D・Twist2D) なので、
// 型の合わない Process とは接続できない。既定値は型の値 (Pose2D{} は全フィールドが既定値) で書く。
auto manifest() {
    return ProcessManifest{"pose_move_cpp"}
        .description("Moves the pose by the twist for dt seconds.")
        .add_typed_arg<Pose2D>("pose", "current pose", Pose2D{})
        .add_typed_arg<Twist2D>("twist", "velocity", Twist2D{})
        .add_float_arg("dt", "duration [s]", 1.0)
        .returns<Pose2D>();
}

std::optional<Pose2D> pose_move_cpp(const Pose2D& pose, const Twist2D& twist, double dt) {
    const double distance = twist.linear * dt;
    Pose2D moved = pose;
    moved.position = Point2D{pose.position.x + distance * std::cos(pose.theta),
                             pose.position.y + distance * std::sin(pose.theta)};
    moved.theta = pose.theta + twist.angular * dt;
    std::printf("pose_move_cpp: (%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f)\n",
                pose.position.x, pose.position.y, pose.theta, moved.position.x, moved.position.y, moved.theta);
    std::fflush(stdout);
    return moved;
}

PROCESS_FACTORY(manifest, pose_move_cpp);
