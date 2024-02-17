c++ -o dashboard *.cpp imgui/backends/imgui_impl_sdl2.cpp imgui/backends/imgui_impl_opengl2.cpp imgui/*.cpp -lSDL2 -Iimgui -lGL -Ilib/logger #-Iimplot
# implot/implot.cpp 