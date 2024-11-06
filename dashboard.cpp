#include "imgui/imgui.h"
#include "imgui_internal.h"
#include "implot/implot.h"
#include "imgui/backends/imgui_impl_sdl2.h"
#include "imgui/backends/imgui_impl_opengl2.h"
#include "MathUtils.h"
#include "Telemetry.h"
#include <SDL.h>
#include <SDL_opengl.h>
#include <csignal>
#include <cstdio>
#include <unistd.h>

#define Telometer Telemetry

#define GRID_SPACING 41.0

const char* Telometer::packet_id_names[] = {
  PACKETS(PACKET_ID_NAME)
};

float receivedUpdateDecay[(int) Telometer::packetIdsCount] = {0};

struct ScrollingBuffer {
    int MaxSize;
    int Offset;
    ImVector<ImVec2> Data;
    ScrollingBuffer(int max_size = 10000) {
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
  bool plotVars[Telometer::packetIdsCount];
  ScrollingBuffer buffers[Telometer::packetIdsCount];
  bool paused;
  float time;
  float timescale;
};

LivePlot testplot = {
  .name = "test",
  .paused = false,
  .time = 0,
  .timescale = 10,
};

LivePlot lineSensorGraph = {
    .name = "lineSensor",
    .paused = false,
    .time = 0,
    .timescale = 10,
};


void lineSensorPlot(struct LivePlot *plot){
  if(ImPlot::BeginPlot(plot->name, ImVec2(-1, -1))) {
    ImPlot::SetupAxes(nullptr, nullptr, 0, 0);

    ImPlot::SetupAxisLimits(ImAxis_X1, -1, 6, ImPlotCond_Always);
    ImPlot::SetupAxisLimits(ImAxis_Y1, 0, 4100, ImPlotCond_Always);



    float linePos[6] = {0, 1, 2, 3, 4, 5};
    float lineData[6] = {}; 
    // memcpy(lineData, Telometer::data_values[Telometer::lineSensorRaw], sizeof(lineData));

    ImPlot::SetNextMarkerStyle(ImPlotMarker_Circle);
    ImPlot::PlotLine(
        "linedata",
        linePos,
        lineData,
        6,
        0,
        0,
        1 * sizeof(float)
    );
    ImPlot::EndPlot();
  }
}


void create_plot(struct LivePlot *plot) {
  plot->time += ImGui::GetIO().DeltaTime;

  if(ImGui::Button(plot->paused?"resume":"pause")) { plot->paused = !plot->paused; }
  ImGui::SameLine();
  ImGui::SliderFloat("timescale", &plot->timescale,  0, 50);

  ImGui::BeginGroup();

  for(int i = 0; i < Telometer::packetIdsCount; i++) {
    if(ImGui::Checkbox(Telometer::packet_id_names[i], &(plot->plotVars[i]))) {
      plot->buffers[i].Erase();
    }
  }

  ImGui::EndGroup();
  ImGui::SameLine();

  
  if(ImPlot::BeginPlot(plot->name, ImVec2(-1, -1))) {

    if(!plot->paused) {
      ImPlot::SetupAxes(nullptr, nullptr, ImPlotAxisFlags_LockMax);
      ImPlot::SetupAxisLimits(ImAxis_X1, plot->time - plot->timescale, plot->time, ImPlotCond_Always);

      for(int i = 0; i < Telometer::packetIdsCount; i++) {
        if(plot->plotVars[i]) {
          float new_val = 0;
          switch(Telometer::packet_id_types[i]) {
            case Telometer::uint16_t_packet:
              new_val = *(uint16_t*) Telometer::data_values[i];
              break;
            case Telometer::float_packet:
              new_val = *(float*) Telometer::data_values[i];
              break;

            default:
              break;
          }
          plot->buffers[i].AddPoint(plot->time, new_val);
        }
      }
    } else {    
      ImPlot::SetupAxes(nullptr, nullptr, 0, 0);
      // ImPlot::SetupAxisLimits(ImAxis_X1, plot->time - plot->timescale, plot->time, Im);
    }

    for(int i = 0; i < Telometer::packetIdsCount; i++) {
      if(plot->plotVars[i]) {
        ImPlot::PlotLine(
          Telometer::packet_id_names[i], 
          &plot->buffers[i].Data[0].x, 
          &plot->buffers[i].Data[0].y, 
          plot->buffers[i].Data.size(), 
          0,
          plot->buffers[i].Offset,
          2 * sizeof(float)
        );
      }
    }
    ImPlot::EndPlot();
  }
  
}


bool inputFloatVector(const char* label, float* v, int len) {
  // bool modified = false;
  // ImGui::PushItemWidth(ImGui::CalcItemWidth() / (float)len - 13);
  // for(int i = 0; i < len; i++ ) {
  //   // ImGui::Text("%s", &labels[i*2]);
  //   // ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
  //   modified = modified || ImGui::InputFloat(&labels[i*2], v + i);
  //   ImGui::SetItemTooltip("%s", &labels[i*2]);
  //   ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
  // }
  // ImGui::PopItemWidth();
  // ImGui::Text("%s", label);
  // return modified;
  return false;
}

void displayFloatVec(const char* label, float* v, int len) {
  ImGui::PushItemWidth(ImGui::CalcItemWidth() / (float)len - 13);
  
  for(int i = 0; i < len; i++ ) {
    float temp = (int) v[i];
    ImGui::InputFloat(" ", &temp);
    ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
  }
  ImGui::PopItemWidth();
  ImGui::Text("%s", label);

}


ImVec2 to_screen_coords(vec2<float> vec, ImVec2 start, ImVec2 size, float sf){
  return {vec.x * sf + start.x + size.x / 2, (start.y + size.y / 2) - vec.y * sf};
}

void drawRobot(ImDrawList *draw_list, vec2<float> robotPos, angle robotHeading, float robotSize, float line_thickness, ImVec2 start, ImVec2 size, float sf, ImU32 color) {
  draw_list->AddCircle(to_screen_coords(robotPos, start, size, sf), robotSize * sf, color, 0, line_thickness * sf);
  draw_list->AddLine(
    to_screen_coords(robotPos, start, size, sf), 
    to_screen_coords(robotPos + robotHeading.angle * robotSize, start, size, sf),
    color, line_thickness* sf);
}



void plot_field(const char* name) {
  static const float field_x = 1;
  static const float field_y = 1;


  if(!ImGui::Begin("X, Y")) {
    ImGui::End();
    return;
  };
  
  ImDrawList *draw_list = ImGui::GetWindowDrawList();
  
  ImVec2 start = ImGui::GetCursorScreenPos();
  ImVec2 field_max = ImGui::GetContentRegionAvail();
  float sf;
  float line_thickness = 0.03; //cm 


  if(field_max.x * field_y / field_x < field_max.y) {
    sf = field_max.x / (field_x * 2); 
    start.y = start.y + (field_max.y - field_y * sf) / 2;
  }
  else {
    sf = field_max.y / (field_y * 2);
    start.x = start.x + (field_max.x - field_x * sf) / 2;
  }

  ImVec2 size = {field_x * 2 * sf, field_y * sf * 2};
  
  draw_list->AddRectFilled({start}, {start.x + size.x, start.y + size.y}, IM_COL32(50, 50, 50, 100));
  // for(int i = 0; i < 3; i ++) {
  //   draw_list->AddLine(to_screen_coords({0, (float)(20 + i * GRID_SPACING)}, start, size, sf), to_screen_coords({field_x, (float)(20 + i * GRID_SPACING)}, start, size, sf), IM_COL32(255, 255, 255, 150), 2*sf);
  // }
  // for(int i = 0; i < 6; i ++) {
  //   draw_list->AddLine(to_screen_coords({(float)(20 + i * GRID_SPACING), 0}, start, size, sf), to_screen_coords({(float)(20 + i * GRID_SPACING), field_y}, start, size, sf), IM_COL32(255, 255, 255, 150), 2*sf);
  // }

  
  draw_list->AddCircle(to_screen_coords((vec2<float>){.x = *(float*)Telemetry::getValue(Telemetry::cos),.y =*(float*)Telemetry::getValue(Telemetry::sin)}, start, size, sf), 0.01 * sf, IM_COL32(29, 245, 187, 255), 0, line_thickness * sf);

  // constexpr int count = 1000;
  // static vec2<float> urfTracing[count] = {};
  // static int bufferPointer = 0;
  // // urfTracing[bufferPointer] = robot_pos + (robot_heading.angle * (*(uint16_t*)Telemetry::getValue(Telemetry::urfDistance) / 10.0 + 5));

  // for(int i = 0; i < count; i ++) {
  //   float fade = (float)((i - bufferPointer) % count) / count;

  //   draw_list->AddCircleFilled(to_screen_coords(urfTracing[i], start, size, sf), 1 * sf, IM_COL32(255, 255, 255, 150* fade), 0);

  // }
  // bufferPointer ++;
  // bufferPointer = bufferPointer % count;

  ImGui::End();
}

void update() {
  Telometer::update();

  if(ImGui::Begin("Data")) {
    float temp_angle;

    for(int i = 0;i < Telometer::packetIdsCount; i++) {
      receivedUpdateDecay[i] *= 0.99;
      if(Telometer::receivedUpdates[i]) {
        receivedUpdateDecay[i] = 1;
        Telometer::receivedUpdates[i] = 0;
      }
      if(ImGui::ColorButton("Updated?", ImVec4(0.1, 0.9 * receivedUpdateDecay[i], 0.05, receivedUpdateDecay[i]))) {
        printf("test\n");
        Telometer::sendPacket((Telometer::packet_id)i);
      }
      ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);

      switch(Telometer::packet_id_types[i]) {
        case Telometer::uint16_t_packet: {
          int temp_int = *(uint16_t*)Telometer::data_values[i];
          if(ImGui::InputInt(Telometer::packet_id_names[i], &temp_int)) {
            *(int16_t*)Telometer::data_values[i] = temp_int;
            Telometer::sendPacket((Telometer::packet_id)i);
          }
        }
          break;
        case Telometer::int16_t_packet: {
          int temp_int = *(int16_t*)Telometer::data_values[i];
          if(ImGui::InputInt(Telometer::packet_id_names[i], &temp_int)) {
            *(int16_t*)Telometer::data_values[i]= temp_int;
            Telometer::sendPacket((Telometer::packet_id)i);
          }
        }
          break;
        case Telometer::float_packet:
          if(ImGui::DragFloat(Telometer::packet_id_names[i], (float*)Telometer::data_values[i], 0.01, 0.0001, 1))
            Telometer::sendPacket((Telometer::packet_id)i);
          break;
       case Telometer::uint32_t_packet: {
          // displayFloatVec(Telometer::packet_id_names[i], (float*)Telometer::data_values[i], 6);
          ImGui::Text("%c, %c, %c", ((char*)Telometer::data_values[i])[0],((char*)Telometer::data_values[i])[1], ((char*)Telometer::data_values[i])[2]);
          // ImGui::InputInt3(Telometer::packet_id_names[i], (int*)Telometer::data_values[i], 6);
          }
          break;
      }
    };
  };

  ImGui::End();

  if(ImGui::Begin("settings")){
    // char *device = "/dev/ttyACM0";
    // ImGui::InputText("Change Device", device, strlen(device));
  }
  ImGui::End();

  if(ImGui::Begin("Plots")) {
    create_plot(&testplot);
  }
  ImGui::End();

  // if(ImGui::Begin("Line Sensor")) {
  //   lineSensorPlot(&lineSensorGraph);
  // }
  // ImGui::End();

  if(ImGui::IsKeyPressed(ImGui::GetKeyIndex(ImGuiKey_Space))) {
    *(int16_t*)Telometer::data_values[Telometer::robotEnabled] = 0;
    Telometer::sendPacket(Telometer::robotEnabled);
  }

  if(
    (
      ImGui::IsKeyPressed(ImGui::GetKeyIndex(ImGuiKey_Backslash)) ||
      ImGui::IsKeyPressed(ImGui::GetKeyIndex(ImGuiKey_RightBracket)) ||
      ImGui::IsKeyPressed(ImGui::GetKeyIndex(ImGuiKey_LeftBracket))
    ) &&(
      ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_Backslash)) &&
      ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_LeftBracket)) &&
      ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_RightBracket))   
    )
    ) {
    *(uint16_t*)Telometer::data_values[Telometer::robotEnabled] = !*(uint16_t*)Telometer::data_values[Telometer::robotEnabled];
    Telometer::sendPacket(Telometer::robotEnabled);
  }

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
  Telometer::init();
  
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


  ImGui::GetIO().ConfigFlags |= ImGuiConfigFlags_DockingEnable;


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

    ImGui::DockSpaceOverViewport();

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
  Telometer::end();
}

