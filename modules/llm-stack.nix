##############################################################################
# modules/llm-stack.nix — Local TurboQuant llama.cpp + Whisper STT stack
#
# Provides two small, CUDA-accelerated inference servers that both fit in the
# 4 GB VRAM of the Quadro P2000 (Pascal, sm_61):
#
#   1. llama-server  (:8080)  — general LLM + vision: LiquidAI LFM2.5-VL-1.6B
#                                (Q4_0), served through the *TurboQuant* fork of
#                                llama.cpp, which adds turbo2/3/4 KV-cache
#                                quantization (Walsh-Hadamard rotated polar
#                                quant). A SigLIP2 `--mmproj` lets it ingest
#                                Pluely's screenshots. One model does text + vision.
#   2. whisper-server (:8081) — speech-to-text: whisper small (q5_1),
#                                CUDA-accelerated, OpenAI-compatible /inference.
#
# Enable with `services.llm-stack.enable = true;`.
# The general LLM endpoint (OpenAI-compatible) lives at
#   http://127.0.0.1:8080/v1  — point Pluely / other clients here.
##############################################################################
{ config, lib, pkgs, ... }:

let
  cfg = config.services.llm-stack;

  ##########################################################################
  # TurboQuant llama.cpp — nixpkgs' llama-cpp with the source swapped to the
  # TheTom/llama-cpp-turboquant fork (feature/turboquant-kv-cache) and CUDA on.
  ##########################################################################
  turboquant-llama = (pkgs.llama-cpp.override {
    cudaSupport = true;
  }).overrideAttrs (old: {
    pname = "llama-cpp-turboquant";
    version = "c3e6dbb";
    src = pkgs.fetchFromGitHub {
      owner = "TheTom";
      repo = "llama-cpp-turboquant";
      rev = "c3e6dbb13d40e2e42f7a964bd5d745fbf86e4495";
      hash = "sha256-jm77eJ7YLE9aoZGW/Ql1IMKVT6Dz5vuBtUxFPRtdh1c=";
      # nixpkgs' preConfigure reads a COMMIT file for LLAMA_BUILD_COMMIT.
      postFetch = ''
        echo -n "c3e6dbb" > $out/COMMIT
      '';
    };
    # The fork's tools/ui web deps differ from upstream → new npm deps hash.
    npmDepsHash = "sha256-TU4Gv+dd48WDpswhfVtm79IVIOwoCXz1fZ/DI/z40Wg=";
    # Restrict CUDA arch to Pascal (sm_61) — the Quadro P2000 — to cut build
    # time and binary size dramatically vs. building every arch.
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-DCMAKE_CUDA_ARCHITECTURES=61"
    ];
  });

  whisper-cuda = pkgs.whisper-cpp.override {
    cudaSupport = true;
  };

  # ---- Models (fetched into the store at build time) ---------------------
  # General + vision model: LFM2.5-VL-1.6B (does BOTH text chat and image
  # understanding — Pluely sends screenshots here too). Q4_0 keeps it tiny.
  lfm25vl-model = pkgs.fetchurl {
    name = "LFM2.5-VL-1.6B-Q4_0.gguf";
    url = "https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/main/LFM2.5-VL-1.6B-Q4_0.gguf";
    sha256 = "8186364a4e7c3ad30f6dd3d3b7a4e0074c77dd91eed6cad5d8be9090ce285804"; # LFM2.5-VL-1.6B Q4_0
  };
  # Multimodal projector (SigLIP2 image encoder → text space).
  lfm25vl-mmproj = pkgs.fetchurl {
    name = "mmproj-LFM2.5-VL-1.6b-Q8_0.gguf";
    url = "https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/main/mmproj-LFM2.5-VL-1.6b-Q8_0.gguf";
    sha256 = "2ce89e610c56f3198ece2b86cf61743a08b9307279c89125eb2412ebb908689d"; # mmproj Q8_0
  };

  whisper-model = pkgs.fetchurl {
    name = "ggml-small-q5_1.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin";
    sha256 = "1fqi0h90ig4ifpyb44cfc7dmnndv2vy5mr9g22yng9fp6nly91df";
  };
in
{
  ##########################################################################
  # Options
  ##########################################################################
  options.services.llm-stack = {
    enable = lib.mkEnableOption "local TurboQuant llama.cpp + Whisper STT stack";

    llamaPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for the general-LLM OpenAI-compatible server.";
    };

    whisperPort = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Port for the Whisper STT server.";
    };

    contextSize = lib.mkOption {
      type = lib.types.int;
      default = 8192;
      description = "LLM context window (tokens). TurboQuant KV keeps this cheap.";
    };

    kvCacheType = lib.mkOption {
      type = lib.types.str;
      default = "q8_0";
      description = ''
        KV-cache quantization type passed to llama-server for both K and V.
        The TurboQuant fork adds turbo2/turbo3/turbo4 types on top of the
        stock f16/q8_0/q4_0. q8_0 is a safe, high-quality default; try
        "turbo3" or "turbo4" for maximum VRAM savings.
      '';
    };

    gpuLayers = lib.mkOption {
      type = lib.types.int;
      default = 99;
      description = "Number of layers to offload to the GPU (99 = all).";
    };
  };

  ##########################################################################
  # Implementation
  ##########################################################################
  config = lib.mkIf cfg.enable {
    # CUDA + the two forks/models are unfree-adjacent; allow what we need.
    nixpkgs.config.cudaSupport = true;

    environment.systemPackages = [ turboquant-llama whisper-cuda ];

    # ---- General LLM server (TurboQuant llama.cpp) ----------------------
    systemd.services.llama-server = {
      description = "TurboQuant llama.cpp server (LFM2.5-VL-1.6B text+vision, CUDA)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = [
          "${turboquant-llama}/bin/llama-server"
          "--model" "${lfm25vl-model}"
          "--mmproj" "${lfm25vl-mmproj}"
          "--host" "127.0.0.1"
          "--port" (toString cfg.llamaPort)
          "--ctx-size" (toString cfg.contextSize)
          "--n-gpu-layers" (toString cfg.gpuLayers)
          "--cache-type-k" cfg.kvCacheType
          "--cache-type-v" cfg.kvCacheType
          "--flash-attn" "on"
          "--alias" "LFM2.5-VL-1.6B"
        ];
        Restart = "on-failure";
        RestartSec = 3;
        DynamicUser = true;
        # Needs access to the NVIDIA device nodes.
        SupplementaryGroups = [ "video" "render" ];
      };
    };

    # ---- Whisper STT server --------------------------------------------
    systemd.services.whisper-server = {
      description = "whisper.cpp STT server (small q5_1, CUDA)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = [
          "${whisper-cuda}/bin/whisper-server"
          "--model" "${whisper-model}"
          "--host" "127.0.0.1"
          "--port" (toString cfg.whisperPort)
        ];
        Restart = "on-failure";
        RestartSec = 3;
        DynamicUser = true;
        SupplementaryGroups = [ "video" "render" ];
      };
    };
  };
}
