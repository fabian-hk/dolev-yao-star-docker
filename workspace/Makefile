# ------------------------------------------------------------------------
# Toolchain Requirements
#
# This project is verified against:
#   - F*   commit 0cbbc9bd61f64977cc534977a858e9291eab69cc
#   - Z3   version 4.15.3
#
# Important:
#   The DY* and Comparse frameworks are assumed to be already verified
#   with the same F* and Z3 versions. Their cached artifacts
#   (cache/, obj/) are reused via --already_cached and --include.
# ------------------------------------------------------------------------

# Environment & Paths
PROJECT_HOME   := .
DY_HOME        ?= $(abspath $(PROJECT_HOME)/../dolev-yao-star-extrinsic)
COMPARSE_HOME  ?= $(abspath $(PROJECT_HOME)/../comparse)

# Executables
FSTAR_EXE ?= fstar.exe
Z3_EXE    ?= z3

# Project configuration (relative)
SOURCE_DIR := src
CACHE_DIR  := cache
HINT_DIR   := hints
OBJ_DIR    := obj
OUT_DIRS   := $(CACHE_DIR) $(HINT_DIR) $(OBJ_DIR)
MKDIR_P    ?= mkdir -p

# Dependency setup (explicit DY* dirs, local src dirs)
DY_SRC := $(DY_HOME)/src
DY_LIB := $(DY_SRC)/lib
DY_LIB_SUBDIRS := comparse event crypto state hpke utils communication label
DY_STAR_DIRS := \
	$(DY_SRC)/core \
	$(DY_LIB) \
	$(addprefix $(DY_LIB)/,$(DY_LIB_SUBDIRS))

SOURCE_DIRS := $(shell find $(SOURCE_DIR) -type d -name "_build" -prune -o -type d -print | sort)

INCLUDE_PATHS := \
	$(DY_HOME)/cache \
	$(COMPARSE_HOME)/cache \
	$(COMPARSE_HOME)/src \
	$(DY_STAR_DIRS) \
	$(SOURCE_DIRS)

FSTAR_INCLUDE_FLAGS := $(addprefix --include , $(INCLUDE_PATHS))

# F* flags
FSTAR_FLAGS := $(FSTAR_INCLUDE_FLAGS) \
	--cache_checked_modules \
	--already_cached '+Prims +FStar +DY.Core +DY.Lib +Comparse' \
	--cache_dir $(CACHE_DIR) \
	--record_hints \
	--use_hints \
	--hint_dir $(HINT_DIR) \
	--odir $(OBJ_DIR) \
	--cmi \
	--warn_error '@0..1000-335-333' \
	--smt $(Z3_EXE) \
	--z3version 4.15.3

# Source discovery (exclude _build subtree)
FSTAR_ROOTS := $(shell find $(SOURCE_DIR) \
	-type d -name "_build" -prune -o \
	-type f \( -name "*.fst" -o -name "*.fsti" \) -print)
FSTAR_ROOTS_FST := $(filter %.fst,$(FSTAR_ROOTS))
ALL_CHECKED_FILES := $(addprefix $(CACHE_DIR)/, $(addsuffix .checked, $(notdir $(FSTAR_ROOTS))))

# ------------------------------------------------------------------------
# Targets
# ------------------------------------------------------------------------

.PHONY: all verify clean debug .force-deps codegen test

# Dependency graph -> verification -> extraction
all: codegen

# Dependency graph generation
ifndef MAKE_RESTARTS
.depend: .force-deps
	@echo "[DEPENDENCY] Generating dependency graph..."
	@$(FSTAR_EXE) $(FSTAR_FLAGS) --dep full $(notdir $(FSTAR_ROOTS)) > .depend.tmp && mv .depend.tmp .depend
	@echo "[SUCCESS] Dependency graph extracted to $@"

.force-deps:
endif

ifneq ($(filter clean debug,$(MAKECMDGOALS)),)
# skip dependency inclusion for non-build targets
else
-include .depend
endif

# Verification rules
$(CACHE_DIR)/%.checked: $(SOURCE_DIR)/% | $(OUT_DIRS)

	@echo "[VERIFY] $*"
	@$(FSTAR_EXE) $(FSTAR_FLAGS) -c $< -o $@ && touch -c $@

verify: .depend $(ALL_CHECKED_FILES)
	@echo "[SUCCESS] All local files verified."

# Extraction (codegen) rule
codegen: verify | $(OBJ_DIR)
	@echo "[CODEGEN] Extracting OCaml..."
	@$(FSTAR_EXE) $(FSTAR_FLAGS) --codegen OCaml \
		--extract '* -Prims -FStar -DY.Core -DY.Lib -Comparse' \
		$(notdir $(FSTAR_ROOTS_FST))
	@echo "[SUCCESS] OCaml extracted to $(OBJ_DIR)"

# Directories
$(OUT_DIRS):
	@$(MKDIR_P) $@

clean:
	rm -rf $(CACHE_DIR) $(HINT_DIR) $(OBJ_DIR) .depend .depend.tmp

# Run extracted OCaml (local build)
OCAMLBUILD ?= ocamlbuild

OCAML_MAIN := DY_Example_Login_Debug
OCAML_EXE  := $(OCAML_MAIN).native
STAGE_DIR  := $(OBJ_DIR)/_ocaml_stage

# Rebuild if any extracted OCaml changes (project + DY* + Comparse)
DY_ML        = $(wildcard $(DY_HOME)/obj/*.ml)
COMPARSE_ML  = $(wildcard $(COMPARSE_HOME)/obj/*.ml)
PROJ_ML      = $(wildcard $(OBJ_DIR)/*.ml)
OCAML_INPUTS = $(DY_ML) $(COMPARSE_ML) $(PROJ_ML)

test: codegen $(STAGE_DIR)/$(OCAML_EXE)
	@$(STAGE_DIR)/$(OCAML_EXE)

$(STAGE_DIR):
	@mkdir -p $@

$(STAGE_DIR)/$(OCAML_EXE): $(OCAML_INPUTS) | $(STAGE_DIR)
	@echo "[OCAML] Staging .ml into $(STAGE_DIR)..."
	@rm -f "$(STAGE_DIR)"/*.ml 2>/dev/null || true
	@for d in "$(DY_HOME)/obj" "$(COMPARSE_HOME)/obj" "$(OBJ_DIR)"; do \
	  for f in "$$d"/*.ml; do \
	    [ -e "$$f" ] && ln -sf "$$(cd "$$d" && pwd)/$$(basename "$$f")" "$(STAGE_DIR)/"; \
	  done; \
	done; :

	@echo "[OCAML] Building $(OCAML_EXE)..."
	@cd "$(STAGE_DIR)" && \
	  OCAMLFIND_IGNORE_DUPS_IN="$(shell ocamlc -where):$(shell opam var lib)/num" \
	  $(OCAMLBUILD) -use-ocamlfind -pkg batteries -pkg fstar.lib \
	    -cflags "-w -a -thread" "$(OCAML_EXE)"

# Debugging
debug:
	@printf "FSTAR_EXE:      %s\n" "$(FSTAR_EXE)"
	@printf "Z3_EXE:         %s\n" "$(Z3_EXE)"
	@printf "PROJECT_HOME:   %s\n" "$(PROJECT_HOME)"
	@printf "DY_HOME:        %s\n" "$(DY_HOME)"
	@printf "COMPARSE_HOME:  %s\n" "$(COMPARSE_HOME)"
	@printf "F* FLAGS:\n"
	@for f in $(FSTAR_FLAGS); do printf "  %s\n" "$$f"; done
	@printf "F* ROOTS:\n"
	@for f in $(FSTAR_ROOTS); do printf "  - %s\n" "$$f"; done
	@printf "INCLUDE PATHS:\n"
	@for p in $(INCLUDE_PATHS); do printf "  - %s\n" "$$p"; done
	@printf "\n"
