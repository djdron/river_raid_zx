# The TS-Conf port's host tools: tscheck (runs a program on Xpeccy+'s TSConf core with no
# window and writes its frame). Uses the repository's deps/ (make deps at the top).
#
#	cmake -S tools -B build/tools -DCMAKE_BUILD_TYPE=Release
#	cmake --build build/tools
cmake_minimum_required(VERSION 3.13)
project(river_raid_tsconf_tools C CXX)

set(DEPS ${CMAKE_CURRENT_SOURCE_DIR}/../../deps)
set(XLIB ${DEPS}/xpeccy-plus/src/libxpeccy)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Xpeccy+'s core as its own quick tests build it (tests/CMakeLists.txt there)
include(TestBigEndian)
test_big_endian(BIG_ENDIAN)
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
find_package(ZLIB REQUIRED)
file(GLOB_RECURSE XLIB_SOURCES ${XLIB}/*.c ${XLIB}/*.cpp)
list(REMOVE_ITEM XLIB_SOURCES ${XLIB}/filetypes/unpackers/lh1/bit_stream_reader.c)
add_library(xpeccycore STATIC ${XLIB_SOURCES})
target_include_directories(xpeccycore PUBLIC ${XLIB} ${ZLIB_INCLUDE_DIR})
if(BIG_ENDIAN)
	target_compile_definitions(xpeccycore PUBLIC WORDS_BIG_ENDIAN)
else()
	target_compile_definitions(xpeccycore PUBLIC WORDS_LITTLE_ENDIAN)
endif()
target_compile_options(xpeccycore PRIVATE $<$<COMPILE_LANGUAGE:C>:-std=gnu99> -w)
set_target_properties(xpeccycore PROPERTIES CXX_STANDARD 14)
target_link_libraries(xpeccycore PUBLIC ${ZLIB_LIBRARY} Threads::Threads)

add_executable(tscheck tscheck.cpp)
target_link_libraries(tscheck xpeccycore)
