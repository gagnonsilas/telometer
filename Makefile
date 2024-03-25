CXX = g++

EXE = telometer
TARGET = target
IMGUI_DIR = imgui
SOURCES = dashboard.cpp serial.cpp
SOURCES += $(IMGUI_DIR)/imgui.cpp $(IMGUI_DIR)/imgui_demo.cpp $(IMGUI_DIR)/imgui_draw.cpp $(IMGUI_DIR)/imgui_tables.cpp $(IMGUI_DIR)/imgui_widgets.cpp implot/implot.cpp implot/implot_items.cpp
SOURCES += $(IMGUI_DIR)/backends/imgui_impl_sdl2.cpp $(IMGUI_DIR)/backends/imgui_impl_opengl2.cpp
SOURCES += /lib/Math/maths.cpp
OBJS = $(addprefix $(TARGET)/, $(addsuffix .o, $(basename $(notdir $(SOURCES)))))
UNAME_S := $(shell uname -s)

CXXFLAGS = -std=c++11 -I$(IMGUI_DIR) -I$(IMGUI_DIR)/backends -Ilib/Math -Ilib/Telemetry -Ilib/Controllers -Iimplot
CXXFLAGS += -g -Wall -Wformat 
LIBS =


##---------------------------------------------------------------------
## BUILD FLAGS PER PLATFORM
##---------------------------------------------------------------------

ifeq ($(UNAME_S), Linux) #LINUX
	ECHO_MESSAGE = "Linux"
	LIBS += -lGL -ldl `sdl2-config --libs`

	CXXFLAGS += `sdl2-config --cflags`
	CFLAGS = $(CXXFLAGS)
endif

ifeq ($(UNAME_S), Darwin) #APPLE
	ECHO_MESSAGE = "Mac OS X"
	LIBS += -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo `sdl2-config --libs`
	LIBS += -L/usr/local/lib -L/opt/local/lib

	CXXFLAGS += `sdl2-config --cflags`
	CXXFLAGS += -I/usr/local/include -I/opt/local/include
	CFLAGS = $(CXXFLAGS)
endif

ifeq ($(OS), Windows_NT)
	ECHO_MESSAGE = "MinGW"
	LIBS += -lgdi32 -lopengl32 -limm32 `pkg-config --static --libs sdl2`

	CXXFLAGS += `pkg-config --cflags sdl2`
	CFLAGS = $(CXXFLAGS)
endif

##---------------------------------------------------------------------
## BUILD RULES
##---------------------------------------------------------------------

$(TARGET)/%.o:%.cpp %.h
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(TARGET)/%.o:%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(TARGET)/%.o:$(IMGUI_DIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(TARGET)/%.o:implot/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(TARGET)/%.o:lib/*/%.cpp lib/*/%.h
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(TARGET)/%.o:$(IMGUI_DIR)/backends/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

all: $(EXE)
	@echo Build complete for $(ECHO_MESSAGE)

$(EXE): $(OBJS) lib/*/*.h
	$(CXX) -o $@ $(OBJS) $(CXXFLAGS) $(LIBS)

clean:
	rm -f $(EXE) $(OBJS)