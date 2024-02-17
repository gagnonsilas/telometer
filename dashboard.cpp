#include "imgui/imgui.h"
// #include "implot/implot.h"
#include "imgui/backends/imgui_impl_sdl2.h"
#include "imgui/backends/imgui_impl_opengl2.h"
#include "lib/logger/maths.h"
#include "lib/logger/log.h"
#include "serial.h"
#include <SDL2/SDL.h>
#include <SDL2/SDL_opengl.h>
#include <csignal>
#include <cstdio>

data* data_values[(int) packet_ids_count];


void update() {
    // printf("loop start\n");
    serial_update();

    ImGui::Begin("data");
    float temp_data;

    for(int i = 0;i < packet_ids_count; i++) {
      switch(packet_id_types[i]) {
        case int_packet:
          if(ImGui::InputInt(packet_id_names[i], &(data_values[i]->int_packet)))
            update_packet((packet_id)i);
          break;
        case float_packet:
          if(ImGui::InputFloat(packet_id_names[i], &(data_values[i]->float_packet)))
            update_packet((packet_id)i);
          break;
        case angle_packet:
          temp_data = getDegrees(data_values[i]->angle_packet);
          if(ImGui::InputFloat(packet_id_names[i], &temp_data)) {
            *data_values[i] = {.angle_packet = angleFromDegrees(temp_data)};
            // printf("did this work\n");
            update_packet((packet_id)i);
          }
          break;
        case vec2_packet:
          if(ImGui::InputFloat2(packet_id_names[i], &(data_values[i]->vec2_packet.x)))
            update_packet((packet_id)i);
          break;
      }
    };

    ImGui::End();

    // ImGui::Begin("settings");
    // char *device = "/dev/ttyACM0";
    // ImGui::InputText("Change Device", device, strlen(device));

    // ImGui::End();

}


int main(int, char**) {
  // Setup SDL
  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_GAMECONTROLLER) != 0)
  {
      printf("Error: %s\n", SDL_GetError());
      return -1;
  }

  // Setup logger
  serial_setup();
  // for(unsigned int i = 0; i < sizeof(data_values)/sizeof(union data*); i++) {
  //   data_values[i] = (data*) malloc(sizeof(union data));
  // }

  // From 2.0.18: Enable native IME.
#ifdef SDL_HINT_IME_SHOW_UI
  SDL_SetHint(SDL_HINT_IME_SHOW_UI, "1");
#endif

  // Setup window
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
  SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
  SDL_WindowFlags window_flags = (SDL_WindowFlags)(SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
  SDL_Window* window = SDL_CreateWindow("Dear ImGui SDL2+OpenGL example", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, window_flags);
  if (window == nullptr)
  {
      printf("Error: SDL_CreateWindow(): %s\n", SDL_GetError());
      return -1;
  }

  SDL_GLContext gl_context = SDL_GL_CreateContext(window);
  SDL_GL_MakeCurrent(window, gl_context);
  SDL_GL_SetSwapInterval(1); // Enable vsync

  // Setup Dear ImGui context
  IMGUI_CHECKVERSION();
  ImGui::CreateContext();
  // ImPlot::CreateContext();

  ImGuiIO& io = ImGui::GetIO(); (void)io;
  io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
  io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

  // Setup Dear ImGui style
  ImGui::StyleColorsDark();
  //ImGui::StyleColorsLight();

  // Setup Platform/Renderer backends
  ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
  ImGui_ImplOpenGL2_Init();
  ImGui_ImplSDL2_NewFrame();

  // Our state
  bool show_demo_window = true;
  bool show_another_window = false;
  ImVec4 clear_color = ImVec4(0.45f, 0.55f, 0.60f, 1.00f);

  
  bool done = false;
  while(!done) {
    SDL_Event event;
    while (SDL_PollEvent(&event))
    {
        ImGui_ImplSDL2_ProcessEvent(&event);
        if (event.type == SDL_QUIT)
            done = true;
        if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window))
            done = true;
    }

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL2_NewFrame();
    ImGui_ImplSDL2_NewFrame();
    ImGui::NewFrame();

    update();

    // Rendering
    ImGui::Render();

    // ImPlot::BeginDragDropSourcePlot();
    
    // ImPlot::EndDragDropTarget();
    glViewport(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y);
    glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
    glClear(GL_COLOR_BUFFER_BIT);
    //glUseProgram(0); // You may want this if using this code in an OpenGL 3+ context where shaders may be bound
    ImGui_ImplOpenGL2_RenderDrawData(ImGui::GetDrawData());
    SDL_GL_SwapWindow(window);
  }


  // Cleanup
  ImGui_ImplOpenGL2_Shutdown();
  ImGui_ImplSDL2_Shutdown();

  // ImPlot::DestroyContext();
  ImGui::DestroyContext();

  SDL_GL_DeleteContext(gl_context);
  SDL_DestroyWindow(window);
  SDL_Quit();

  kill(getpid(), 9);
  close_serial();
}

