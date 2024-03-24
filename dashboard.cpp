#include "imgui/imgui.h"
#include "implot/implot.h"
#include "imgui/backends/imgui_impl_sdl2.h"
#include "imgui/backends/imgui_impl_opengl2.h"
#include "lib/Math/maths.h"
#include "lib/Telemetry/telemetry.h"
#include "serial.h"
#include <SDL2/SDL.h>
#include <SDL2/SDL_opengl.h>
#include <csignal>
#include <cstdint>
#include <cstdio>

data* data_values[(int) packet_ids_count];

struct ScrollingBuffer {
    int MaxSize;
    int Offset;
    ImVector<ImVec2> Data;
    ScrollingBuffer(int max_size = 2000) {
        MaxSize = max_size;
        Offset  = 0;
        Data.reserve(MaxSize);
    }
    void AddPoint(float x, float y) {
        if (Data.size() < MaxSize)
            Data.push_back(ImVec2(x,y));
        else {
            Data[Offset] = ImVec2(x,y);
            Offset =  (Offset + 1) % MaxSize;
        }
    }

    void Erase() {
        if (Data.size() > 0) {
            Data.shrink(0);
            Offset  = 0;
        }
    }
};

struct LivePlot {
  const char* name;
  bool plotVars[packet_ids_count];
  ScrollingBuffer buffers[packet_ids_count];
  bool paused;
};

LivePlot testplot = {
  .name = "test"
};

void create_plot(struct LivePlot *plot) {
  ImGui::BeginGroup();

  for(int i = 0; i < packet_ids_count; i++) {
    ImGui::Checkbox(packet_id_names[i], &(plot->plotVars[i]));
  }

  if(ImGui::Button("pause")) {
    plot->paused = !plot->paused;
  }


  ImGui::EndGroup();
  ImGui::SameLine();
  
  // ImPlot::BeginPlot(plot->name,);
}


bool inputFloatVector(const char* label, float* v, int len, const char labels[]) {
  bool modified = false;
  ImGui::PushItemWidth(ImGui::CalcItemWidth() / (float)len - 13);
  for(int i = 0; i < len; i++ ) {
    // ImGui::Text("%s", &labels[i*2]);
    // ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
    modified = modified || ImGui::InputFloat(&labels[i*2], v + i);
    ImGui::SetItemTooltip("%s", &labels[i*2]);
    ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
  }
  ImGui::PopItemWidth();
  ImGui::Text("%s", label);
  return modified;
}


ImVec2 to_screen_coords(vec2 vec, ImVec2 start, ImVec2 size, float sf){
  return {vec.x * sf + start.x, (start.y + size.y) - vec.y * sf};
}

void plot_field(const char* name) {
  static bool plots[packet_ids_count];
  static float field_x = 200;
  static float field_y = 100;
  static float robot_size = 16.3 / 2.0; //cm


  vec2 robot_pos = data_values[position]->vec2_packet;
  angle robot_heading = data_values[heading]->angle_packet;

  ImGui::Begin("Field");
  
  ImDrawList *draw_list = ImGui::GetWindowDrawList();
  
  ImVec2 start = ImGui::GetCursorScreenPos();
  ImVec2 field_max = ImGui::GetContentRegionAvail();
  float sf;
  float line_thickness = 1; //cm 


  if(field_max.x * field_y / field_x < field_max.y) {
    sf = field_max.x / field_x; 
    start.y = start.y + (field_max.y - field_y * sf) / 2;
  }
  else {
    sf = field_max.y / field_y;
    start.x = start.x + (field_max.x - field_x * sf) / 2;
  }

  ImVec2 size = {field_x * sf, field_y * sf};
  
  draw_list->AddRectFilled({start}, {start.x + field_x * sf, start.y + field_y *sf}, IM_COL32(50, 50, 50, 100));
  
  draw_list->AddCircle(to_screen_coords(robot_pos, start, size, sf), robot_size * sf, IM_COL32(255, 0, 255, 255), 0, line_thickness * sf);
  draw_list->AddLine(
    to_screen_coords(robot_pos, start, size, sf), 
    to_screen_coords(maths::add<vec2>(robot_pos, maths::scale<vec2>(robot_heading.angle, robot_size)), start, size, sf),
    IM_COL32(204, 204, 255, 255), line_thickness* sf);
  
  draw_list->AddCircle(to_screen_coords(data_values[target_path_point]->vec2_packet, start, size, sf), 2 * sf, IM_COL32(0, 125, 255, 255), 0, line_thickness * sf);
  // ImPlot::Draw
  // ImPlot::Plot("Robot", );

  // for(int i = 0; i < packet_ids_count; i++) {
  //   ImGui::Checkbox(packet_id_names[i], &(plots[i]));
  //   if(plots[i]) {
  //   }
  // }

  draw_list->AddDrawCmd();
  

  ImGui::End();
}

void update() {
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
        temp_data = maths::getDegrees(data_values[i]->angle_packet);
        if(ImGui::InputFloat(packet_id_names[i], &temp_data)) {
          *data_values[i] = {.angle_packet = maths::angleFromDegrees(temp_data)};
          // printf("did this work\n");
          update_packet((packet_id)i);
        }
        break;
      case vec2_packet:
        if(ImGui::InputFloat2(packet_id_names[i], &data_values[i]->vec2_packet.x))
          update_packet((packet_id)i);
        // if(inputFloatVector(packet_id_names[i], &(data_values[i]->vec2_packet.x), 2, "X\0Y"))
          // update_packet((packet_id)i);
        break;
      case PID_constants_packet:
        if(ImGui::InputFloat3(packet_id_names[i], &data_values[i]->PID_constants_packet.p))
          update_packet((packet_id)i);
        // if(inputFloatVector(packet_id_names[i], &(data_values[i]->PID_constants_packet.p), 2, "P\0D"))
        //   update_packet((packet_id)i);
        break;
    }
  };

  ImGui::End();

  ImGui::Begin("settings");
  char *device = "/dev/ttyACM0";
  ImGui::InputText("Change Device", device, strlen(device));

  ImGui::End();

  ImGui::Begin("Plots");

  create_plot(&testplot);

  ImGui::End();

  plot_field("field");
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
  ImPlot::CreateContext();

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

  ImPlot::DestroyContext();
  ImGui::DestroyContext();

  SDL_GL_DeleteContext(gl_context);
  SDL_DestroyWindow(window);
  SDL_Quit();

  kill(getpid(), 9);
  close_serial();
}

