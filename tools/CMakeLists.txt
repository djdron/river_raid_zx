# Host tools: mkpalette (writes src/palette.inc) and nxcheck (runs the viewer on Xpeccy+'s
# Next core and compares it with the C++ port). Needs deps/ (tools/get_deps.sh).
#
#	cmake -S tools -B build/tools -DCMAKE_BUILD_TYPE=Release
#	cmake --build build/tools
cmake_minimum_required(VERSION 3.13)
project(river_raid_zx_tools C CXX)

set(DEPS ${CMAKE_CURRENT_SOURCE_DIR}/../deps)
set(RR_SRC ${DEPS}/river_raid/port/src)
set(XLIB ${DEPS}/xpeccy-plus/src/libxpeccy)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(rrcore STATIC ${RR_SRC}/river_gen.cpp ${RR_SRC}/river_state_io.cpp ${RR_SRC}/river_draw.cpp ${RR_SRC}/palette.cpp
	${RR_SRC}/game.cpp ${RR_SRC}/game_ram.cpp ${RR_SRC}/display.cpp ${RR_SRC}/status_bar.cpp ${RR_SRC}/os_font.cpp ${RR_SRC}/pokey_sound.cpp)
target_include_directories(rrcore PUBLIC ${RR_SRC} ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(mkpalette mkpalette.cpp)
target_link_libraries(mkpalette rrcore)
add_executable(mkfont mkfont.cpp)
target_link_libraries(mkfont rrcore)
add_executable(mkrandom mkrandom.cpp)
add_executable(mkpoly mkpoly.cpp)

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

add_executable(nxcheck nxcheck.cpp)
target_link_libraries(nxcheck rrcore xpeccycore)
