#include "imgui/imgui.h"
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


const char* Telometer::packet_id_names[] = {
  PACKETS(PACKET_ID_NAME)
};

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
            case Telometer::angle_packet:
              new_val = MathUtils::getRadians(*(angle*)Telometer::data_values[i]);
              break;
            case Telometer::vec2f_packet:
              new_val = *(float*)  Telometer::data_values[i];
              break;
            case Telometer::vec3i16_packet:
              new_val = (float)*(int*)Telometer::data_values[i];
            case Telometer::vec3f_packet:
              new_val = *(float*)Telometer::data_values[i];
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


ImVec2 to_screen_coords(vec2<float> vec, ImVec2 start, ImVec2 size, float sf){
  return {vec.x * sf + start.x, (start.y + size.y) - vec.y * sf};
}

void plot_field(const char* name) {
  static const float field_x = 40 * 6;
  static const float field_y = 40 * 3;
  static const float robot_size = 16.3 / 2.0; //cm


  vec2<float> robot_pos = *(vec2<float>*) Telometer::data_values[Telometer::position];
  angle robot_heading = *(angle*)Telometer::data_values[Telometer::heading];

  if(!ImGui::Begin("Field")) {
    ImGui::End();
    return;
  };
  
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
    to_screen_coords(robot_pos + robot_heading.angle * robot_size, start, size, sf),
    IM_COL32(204, 204, 255, 255), line_thickness* sf);


  for(int i = 0; i < 3; i ++) {
    draw_list->AddLine(to_screen_coords({0, (float)(20 + i * 40)}, start, size, sf), to_screen_coords({field_x, (float)(20 + i * 40)}, start, size, sf), IM_COL32(255, 255, 255, 200), 2*sf);
  }
  for(int i = 0; i < 6; i ++) {
    draw_list->AddLine(to_screen_coords({(float)(20 + i * 40), 0}, start, size, sf), to_screen_coords({(float)(20 + i * 40), field_y}, start, size, sf), IM_COL32(255, 255, 255, 200), 2*sf);
  }
  
  // draw_list->AddCircle(to_screen_coords(Telometer::data_values[Telometer::targetPathPoint]->vec2f_packet, start, size, sf), 2 * sf, IM_COL32(0, 125, 255, 255), 0, line_thickness * sf);
  // ImPlot::Draw
  // ImPlot::Plot("Robot", );

  // for(int i = 0; i < packetIdsCount; i++) {
  //   ImGui::Checkbox(packet_id_names[i], &(plots[i]));
  //   if(plots[i]) {
  //   }
  // }

  draw_list->AddDrawCmd();
  

  ImGui::End();
}

void update() {
  Telometer::update();

  if(ImGui::Begin("Data")) {
    float temp_angle;

    for(int i = 0;i < Telometer::packetIdsCount; i++) {
      switch(Telometer::packet_id_types[i]) {
        case Telometer::uint16_t_packet: {
          int temp_int = *(uint16_t*)Telometer::data_values[i];
          if(ImGui::InputInt(Telometer::packet_id_names[i], &temp_int)) {
            *(int16_t*)Telometer::data_values[i] = temp_int;
            Telometer::sendPacket((Telometer::packet_id)i);
          }
        }
          break;
<<<<<<< HEAD
        case Telemetry::float_packet:
          if(ImGui::InputFloat(Telemetry::packet_id_names[i], &(Telemetry::data_values[i]->float_packet)))
            Telemetry::sendPacket((Telemetry::packet_id)i);
=======
        case Telometer::int16_t_packet: {
          int temp_int = *(int16_t*)Telometer::data_values[i];
          if(ImGui::InputInt(Telometer::packet_id_names[i], &temp_int)) {
            *(int16_t*)Telometer::data_values[i]= temp_int;
            Telometer::sendPacket((Telometer::packet_id)i);
          }
        }
>>>>>>> main
          break;
        case Telometer::float_packet:
          if(ImGui::DragFloat(Telometer::packet_id_names[i], (float*)Telometer::data_values[i], 0.01, 0.0001, 1))
            Telometer::sendPacket((Telometer::packet_id)i);
          break;
        case Telometer::angle_packet:
          temp_angle = MathUtils::getDegrees(*(angle*)Telometer::data_values[i]);
          if(ImGui::DragFloat(Telometer::packet_id_names[i], &temp_angle)) {
            *(angle*)Telometer::data_values[i] = MathUtils::angleFromDegrees(temp_angle);
            Telometer::sendPacket((Telometer::packet_id)i);
          }
          break;
        case Telometer::vec2f_packet:
          if(ImGui::DragFloat2(Telometer::packet_id_names[i], (float*)Telometer::data_values[i]))
            Telometer::sendPacket((Telometer::packet_id)i);
          break;
        case Telometer::vec3f_packet:
          if(ImGui::DragFloat3(Telometer::packet_id_names[i], (float*)Telometer::data_values[i]))
            Telometer::sendPacket((Telometer::packet_id)i);
          break;
        case Telometer::vec3i16_packet: {
          int vec3i16_temp[3]; 
          vec3i16_temp[0] = (*(vec3<int16_t>*)Telometer::data_values[i]).x;
          vec3i16_temp[1] = (*(vec3<int16_t>*)Telometer::data_values[i]).y;
          vec3i16_temp[2] = (*(vec3<int16_t>*)Telometer::data_values[i]).z;

          if(ImGui::InputInt3(Telometer::packet_id_names[i], &vec3i16_temp[0]))
            Telometer::sendPacket((Telometer::packet_id)i);
           (*(vec3<int16_t>*)Telometer::data_values[i]).x = vec3i16_temp[0];
           (*(vec3<int16_t>*)Telometer::data_values[i]).y = vec3i16_temp[1];
           (*(vec3<int16_t>*)Telometer::data_values[i]).z = vec3i16_temp[2];
          }
          break;
        case Telometer::vec2i16_packet: {
          int vec2i16_temp[2]; 
          vec2i16_temp[0] = (*(vec2<int16_t>*)Telometer::data_values[i]).x;
          vec2i16_temp[1] = (*(vec2<int16_t>*)Telometer::data_values[i]).y;

          if(ImGui::InputInt2(Telometer::packet_id_names[i], &vec2i16_temp[0])) {
            (*(vec2<int16_t>*)Telometer::data_values[i]).x = vec2i16_temp[0];
            (*(vec2<int16_t>*)Telometer::data_values[i]).y = vec2i16_temp[1];
            
            Telometer::sendPacket((Telometer::packet_id)i);
          }
          }
          break;
        // case Telometer::PID_constants_packet:
        //   if(ImGui::DragFloat3(Telometer::packet_id_names[i], &Telometer::data_values[i].p))
        //     Telometer::sendPacket((Telometer::packet_id)i);
        //   break;
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

  if(ImGui::IsKeyPressed(ImGui::GetKeyIndex(ImGuiKey_Space))) {
    *(int16_t*)Telometer::data_values[Telometer::robotEnabled] = 0;
    Telometer::sendPacket(Telometer::robotEnabled);
  }

  if(
    ImGui::IsKeyPressed(ImGui::GetKeyIndex(ImGuiKey_Backslash)) &&
    ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_RightBracket)) &&
    ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_LeftBracket))
  ) {
    *(uint16_t*)Telometer::data_values[Telometer::robotEnabled] = !*(uint16_t*)Telometer::data_values[Telometer::robotEnabled];
    Telometer::sendPacket(Telometer::robotEnabled);
  }

  const int speed = 2;
  const int turnSpeed = 2;

  static vec2<int16_t> *volts = (vec2<int16_t>*) Telometer::data_values[Telometer::motorsVolt];

  int forward = speed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_W)) - speed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_R));
  int turn = turnSpeed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_A)) - turnSpeed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_S));

  if(forward || turn) {
    *volts = {static_cast<short>(forward + turn), static_cast<short>(forward - turn)};
  }
  else  {
    *volts = {0, 0};
  }

  Telometer::sendPacket(Telometer::motorsVolt);
  

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
#include <unistd.h>
#define Telometer Telemetry

const char* Telometer::packet_id_names[] = {
  bool plotVars[Telometer::packetIdsCount];
  ScrollingBuffer buffers[Telometer::packetIdsCount];
  for(int i = 0; i < Telometer::packetIdsCount; i++) {
    if(ImGui::Checkbox(Telometer::packet_id_names[i], &(plot->plotVars[i]))) {
      for(int i = 0; i < Telometer::packetIdsCount; i++) {
          switch(Telometer::packet_id_types[i]) {
            case Telometer::uint16_t_packet:
              new_val = *(uint16_t*) Telometer::data_values[i];
            case Telometer::float_packet:
              new_val = *(float*) Telometer::data_values[i];
            case Telometer::angle_packet:
              new_val = MathUtils::getRadians(*(angle*)Telometer::data_values[i]);
            case Telometer::vec2f_packet:
              new_val = *(float*)  Telometer::data_values[i];
            case Telometer::vec3i16_packet:
              new_val = (float)*(int*)Telometer::data_values[i];
            case Telometer::vec3f_packet:
              new_val = *(float*)Telometer::data_values[i];
    for(int i = 0; i < Telometer::packetIdsCount; i++) {
          Telometer::packet_id_names[i],
  static const float field_x = 40 * 6;
  static const float field_y = 40 * 3;
  static const float robot_size = 16.3 / 2.0; //cm
  vec2<float> robot_pos = *(vec2<float>*) Telometer::data_values[Telometer::position];
  angle robot_heading = *(angle*)Telometer::data_values[Telometer::heading];


  for(int i = 0; i < 3; i ++) {
    draw_list->AddLine(to_screen_coords({0, (float)(20 + i * 40)}, start, size, sf), to_screen_coords({field_x, (float)(20 + i * 40)}, start, size, sf), IM_COL32(255, 255, 255, 200), 2*sf);
  }
  for(int i = 0; i < 6; i ++) {
    draw_list->AddLine(to_screen_coords({(float)(20 + i * 40), 0}, start, size, sf), to_screen_coords({(float)(20 + i * 40), field_y}, start, size, sf), IM_COL32(255, 255, 255, 200), 2*sf);
  }
  // draw_list->AddCircle(to_screen_coords(Telometer::data_values[Telometer::targetPathPoint]->vec2f_packet, start, size, sf), 2 * sf, IM_COL32(0, 125, 255, 255), 0, line_thickness * sf);
  Telometer::update();
    for(int i = 0;i < Telometer::packetIdsCount; i++) {
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
        case Telometer::float_packet:
          if(ImGui::DragFloat(Telometer::packet_id_names[i], (float*)Telometer::data_values[i], 0.01, 0.0001, 1))
            Telometer::sendPacket((Telometer::packet_id)i);
        case Telometer::angle_packet:
          temp_angle = MathUtils::getDegrees(*(angle*)Telometer::data_values[i]);
          if(ImGui::DragFloat(Telometer::packet_id_names[i], &temp_angle)) {
            *(angle*)Telometer::data_values[i] = MathUtils::angleFromDegrees(temp_angle);
            Telometer::sendPacket((Telometer::packet_id)i);
        case Telometer::vec2f_packet:
          if(ImGui::DragFloat2(Telometer::packet_id_names[i], (float*)Telometer::data_values[i]))
            Telometer::sendPacket((Telometer::packet_id)i);
        case Telometer::vec3f_packet:
          if(ImGui::DragFloat3(Telometer::packet_id_names[i], (float*)Telometer::data_values[i]))
            Telometer::sendPacket((Telometer::packet_id)i);
        case Telometer::vec3i16_packet: {
          int vec3i16_temp[3];
          vec3i16_temp[0] = (*(vec3<int16_t>*)Telometer::data_values[i]).x;
          vec3i16_temp[1] = (*(vec3<int16_t>*)Telometer::data_values[i]).y;
          vec3i16_temp[2] = (*(vec3<int16_t>*)Telometer::data_values[i]).z;
          if(ImGui::InputInt3(Telometer::packet_id_names[i], &vec3i16_temp[0]))
            Telometer::sendPacket((Telometer::packet_id)i);
           (*(vec3<int16_t>*)Telometer::data_values[i]).x = vec3i16_temp[0];
           (*(vec3<int16_t>*)Telometer::data_values[i]).y = vec3i16_temp[1];
           (*(vec3<int16_t>*)Telometer::data_values[i]).z = vec3i16_temp[2];
          }
        case Telometer::vec2i16_packet: {
          int vec2i16_temp[2];
          vec2i16_temp[0] = (*(vec2<int16_t>*)Telometer::data_values[i]).x;
          vec2i16_temp[1] = (*(vec2<int16_t>*)Telometer::data_values[i]).y;

          if(ImGui::InputInt2(Telometer::packet_id_names[i], &vec2i16_temp[0])) {
            (*(vec2<int16_t>*)Telometer::data_values[i]).x = vec2i16_temp[0];
            (*(vec2<int16_t>*)Telometer::data_values[i]).y = vec2i16_temp[1];

            Telometer::sendPacket((Telometer::packet_id)i);
          }
          }
        // case Telometer::PID_constants_packet:
        //   if(ImGui::DragFloat3(Telometer::packet_id_names[i], &Telometer::data_values[i].p))
        //     Telometer::sendPacket((Telometer::packet_id)i);
        //   break;
    *(int16_t*)Telometer::data_values[Telometer::robotEnabled] = 0;
    Telometer::sendPacket(Telometer::robotEnabled);
    *(uint16_t*)Telometer::data_values[Telometer::robotEnabled] = !*(uint16_t*)Telometer::data_values[Telometer::robotEnabled];
    Telometer::sendPacket(Telometer::robotEnabled);
  }

  const int speed = 2;
  const int turnSpeed = 2;

  static vec2<int16_t> *volts = (vec2<int16_t>*) Telometer::data_values[Telometer::motorsVolt];

  int forward = speed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_W)) - speed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_R));
  int turn = turnSpeed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_A)) - turnSpeed * ImGui::IsKeyDown(ImGui::GetKeyIndex(ImGuiKey_S));

  if(forward || turn) {
    *volts = {static_cast<short>(forward + turn), static_cast<short>(forward - turn)};
  else  {
    *volts = {0, 0};
  }

  Telometer::sendPacket(Telometer::motorsVolt);

  Telometer::init();
  Telometer::end();
}

