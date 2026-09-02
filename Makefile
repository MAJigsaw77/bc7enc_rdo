ifeq ($(OS), Windows_NT)
    HOST_OS := Windows
else
    UNAME_S := $(shell uname -s 2>/dev/null || echo Unknown)
    ifeq ($(findstring MINGW,$(UNAME_S)), MINGW)
        HOST_OS := Windows
    else ifeq ($(findstring MSYS,$(UNAME_S)), MSYS)
        HOST_OS := Windows
    else ifeq ($(findstring CYGWIN,$(UNAME_S)), CYGWIN)
        HOST_OS := Windows
    else
        HOST_OS := $(UNAME_S)
    endif
endif

UNAME_M := $(shell uname -m 2>/dev/null || echo unknown)

ARCH ?= native

ifeq ($(ARCH), x86_64)
    BUILD_X64   := 1
    BUILD_ARM64 := 0
else ifeq ($(ARCH), arm64)
    BUILD_X64   := 0
    BUILD_ARM64 := 1
else ifeq ($(ARCH), aarch64)
    BUILD_X64   := 0
    BUILD_ARM64 := 1
else ifeq ($(UNAME_M), x86_64)
    BUILD_X64   := 1
    BUILD_ARM64 := 0
else ifneq ($(filter arm64 aarch64 AMD64 x86_64,$(UNAME_M) $(PROCESSOR_ARCHITECTURE)),)
    BUILD_X64   := 0
    BUILD_ARM64 := 1
else
    BUILD_X64   := 0
    BUILD_ARM64 := 0
endif

BUILD_TYPE ?= Release

SRC_DIR     := src
INCLUDE_DIR := include
OBJ_DIR     := obj
BIN_DIR     := bin
SLICE_DIR   := build_slices

ifeq ($(HOST_OS), Windows)
    EXE_EXT := .exe
    OBJ_EXT := .o
else
    EXE_EXT :=
    OBJ_EXT := .o
endif

ifeq ($(HOST_OS), Darwin)
    CXX ?= clang++
    CC  ?= clang
else ifeq ($(HOST_OS), Windows)
    CXX ?= g++
    CC  ?= gcc
else
    CXX ?= g++
    CC  ?= gcc
endif

WARN_FLAGS := -Wall -Wextra \
              -Wno-unused-function \
              -Wno-unused-variable \
              -Wno-unused-parameter \
              -Wno-unused-const-variable \
              -Wno-unused-but-set-variable \
              -Wno-tautological-negation-compare \
              -Wno-tautological-compare

INCLUDES := -I$(SRC_DIR) -iquote $(INCLUDE_DIR) -I$(INCLUDE_DIR)

CFLAGS   ?= -fno-strict-aliasing $(WARN_FLAGS) $(INCLUDES)
CXXFLAGS ?= -fno-strict-aliasing $(WARN_FLAGS) $(INCLUDES) -DSUPPORT_BC7E=0
LDFLAGS  ?= 

ifeq ($(HOST_OS), Windows)
    LDFLAGS += -static -static-libgcc -static-libstdc++
endif

ifeq ($(HOST_OS), Darwin)
    ifeq ($(ARCH), x86_64)
        CFLAGS   += -arch x86_64
        CXXFLAGS += -arch x86_64
        LDFLAGS  += -arch x86_64
    else ifeq ($(ARCH), arm64)
        CFLAGS   += -arch arm64
        CXXFLAGS += -arch arm64
        LDFLAGS  += -arch arm64
    endif
endif

ifeq ($(BUILD_TYPE), Debug)
    CFLAGS   += -g -D_DEBUG
    CXXFLAGS += -g -D_DEBUG
else
    CFLAGS   += -O3
    CXXFLAGS += -O3
endif

ifneq ($(HOST_OS), Windows)
    LDLIBS += -lm
    ifeq ($(HOST_OS), Linux)
        LDLIBS += -pthread
    endif
endif

CPP_SRCS := bc7enc.cpp \
            bc7decomp.cpp \
            bc7decomp_ref.cpp \
            lodepng.cpp \
            test.cpp \
            rgbcx.cpp \
            utils.cpp \
            ert.cpp \
            rdo_bc_encoder.cpp

OBJS := $(addprefix $(OBJ_DIR)/, $(CPP_SRCS:.cpp=$(OBJ_EXT)))
TARGET := $(BIN_DIR)/bc7enc$(EXE_EXT)

ifeq ($(OS), Windows_NT)
    ifneq ($(SHELL), sh.exe)
        ifneq ($(findstring sh,$(SHELL)), sh)
            RMDIR = if exist $(1) rmdir /s /q $(1)
            MKDIR = if not exist $(1) mkdir $(1)
        else
            RMDIR = rm -rf $(1)
            MKDIR = mkdir -p $(1)
        endif
    else
        RMDIR = rm -rf $(1)
        MKDIR = mkdir -p $(1)
    endif
else
    RMDIR = rm -rf $(1)
    MKDIR = mkdir -p $(1)
endif

.PHONY: all clean print_start universal

all: print_start $(TARGET)

print_start:
	@echo "Starting build process for bc7enc ($(BUILD_TYPE), OS=$(HOST_OS), ARCH=$(ARCH))..."

universal:
ifeq ($(HOST_OS), Darwin)
	@$(call RMDIR,$(SLICE_DIR))
	@echo "[UNIVERSAL] Building x86_64 slice..."
	@$(MAKE) -C . clean
	@$(MAKE) -C . all ARCH=x86_64
	@$(call MKDIR,$(SLICE_DIR)/x86_64)
	@cp $(TARGET) $(SLICE_DIR)/x86_64/bc7enc
	@echo "[UNIVERSAL] Building arm64 slice..."
	@$(MAKE) -C . clean
	@$(MAKE) -C . all ARCH=arm64
	@$(call MKDIR,$(SLICE_DIR)/arm64)
	@cp $(TARGET) $(SLICE_DIR)/arm64/bc7enc
	@$(call MKDIR,$(BIN_DIR))
	@echo "[UNIVERSAL] Creating Universal Binary with lipo..."
	@lipo -create $(SLICE_DIR)/x86_64/bc7enc $(SLICE_DIR)/arm64/bc7enc -output $(TARGET)
	@$(call RMDIR,$(SLICE_DIR))
	@echo "[UNIVERSAL] Done! Target generated at: $(TARGET)"
else
	@echo "[UNIVERSAL] Universal targets are only supported on macOS. Building native binary..."
	@$(MAKE) -C . all
endif

$(TARGET): $(OBJS) | $(BIN_DIR)
	@echo " [LINK] $@"
	@$(CXX) $(CXXFLAGS) $(LDFLAGS) $^ -o $@ $(LDLIBS)

$(OBJ_DIR)/%$(OBJ_EXT): $(SRC_DIR)/%.cpp | $(OBJ_DIR)
	@echo " [CXX ] $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR) $(BIN_DIR):
	@$(call MKDIR,$@)

clean:
	@echo "[CLEAN] $(BIN_DIR)"
	@$(call RMDIR,$(BIN_DIR))
	@echo "[CLEAN] $(OBJ_DIR)"
	@$(call RMDIR,$(OBJ_DIR))
