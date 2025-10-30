cmake_minimum_required(VERSION 3.16)
project(repro_ddot C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Encourage strict floating semantics
add_compile_options(
  -Wall -Wextra -Wpedantic
  -fno-fast-math
  -ffp-contract=off
)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

add_library(reproblas STATIC
  src/reproblas/ddot.c
)
target_include_directories(reproblas PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

add_executable(test_ddot
  src/tests/test_ddot.c
)
target_link_libraries(test_ddot PRIVATE reproblas)

enable_testing()
add_test(NAME test_ddot COMMAND test_ddot)
set_target_properties(test_ddot PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
