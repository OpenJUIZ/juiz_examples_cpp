add_juiz_process(increment_process_cpp SOURCES increment_process_cpp/increment_process_cpp.cpp)
add_juiz_process(decrement_process_cpp SOURCES decrement_process_cpp/decrement_process_cpp.cpp)
add_juiz_process(talker_cpp SOURCES talker_cpp/talker_cpp.cpp)
add_juiz_process(listener_cpp SOURCES listener_cpp/listener_cpp.cpp)

# 型付きの Process。サンプル共通の型 (types/geometry.jidl) から C++ の型 (juiz_idl.h) を作って使う
add_juiz_process(pose_move_cpp SOURCES pose_move_cpp/pose_move_cpp.cpp)
juiz_generate_types(pose_move_cpp IDL ${PROJECT_SOURCE_DIR}/types/geometry.jidl)
