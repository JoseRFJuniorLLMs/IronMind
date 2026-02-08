cmake_minimum_required(VERSION 3.10)

project(whisper_lib)

set(CMAKE_CXX_STANDARD 14)

# Define source files for v1.4.2 (No ggml-alloc or backend)
set(SOURCES
    whisper.cpp
    ggml.c
)

# Create shared library
add_library(whisper SHARED ${SOURCES})

# Include directories
target_include_directories(whisper PRIVATE .)

# Link libraries
find_library(log-lib log)
target_link_libraries(whisper ${log-lib})
