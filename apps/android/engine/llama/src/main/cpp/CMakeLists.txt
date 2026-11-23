cmake_minimum_required(VERSION 3.22.1)
project(hopa_llama CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# llama.cpp is fetched at a pinned tag instead of being vendored: the tree is
# large, and a tag is a smaller promise to keep than a copy of the sources.
include(FetchContent)

set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    llama
    GIT_REPOSITORY https://github.com/ggml-org/llama.cpp.git
    GIT_TAG v1.0.0
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(llama)

add_library(hopa_llama SHARED src/hopa_llama.cpp)
target_link_libraries(hopa_llama PRIVATE llama)
target_compile_options(hopa_llama PRIVATE -O2 -fvisibility=hidden)
