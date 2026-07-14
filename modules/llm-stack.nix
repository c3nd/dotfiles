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
#   1b. llama-server (:8082)  — OPTIONAL A/B comparison endpoint: OpenBMB
#                                MiniCPM-V 4.6 (1.3B, Q4_K_M) + its mmproj.
#                                Same OpenAI-compatible /v1 API as :8080, so
#                                Pluely (or you) can compare OCR/vision quality
#                                head-to-head. OFF by default — running three
#                                models at once is tight on 4 GB VRAM. Enable
#                                with `services.llm-stack.enableComparison = true;`.
#   2. meow-stt      (:8081) — speech-to-text: faster-whisper (small, GPU/
#                                CUDA float32) + offline Resemblyzer speaker
#                                diarization, served by a Flask server in the
#                                meow-stt venv (~/opt/meow-stt). Replaces the old
#                                whisper.cpp whisper-server: nix whisper-cpp
#                                silently ships the non-CUDA binary, and the
#                                P2000 (Pascal) needs the PyPI ctranslate2 cu12
#                                wheel + system CUDA 12.9 (see meow-stt-faster-
#                                whisper.md). Diarization runs in a
#                                CUDA_VISIBLE_DEVICES="" subprocess (torch's
#                                Resemblyzer LSTM has no Pascal CUDA kernel).
#
# Enable with `services.llm-stack.enable = true;`.
# The general LLM endpoint (OpenAI-compatible) lives at
#   http://127.0.0.1:8080/v1  — point Pluely / other clients here.
# The comparison endpoint (also OpenAI-compatible) lives at
#   http://127.0.0.1:8082/v1  — flip on enableComparison to use it.
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
    # MUST be numeric: nixpkgs sets LLAMA_BUILD_NUMBER = version (used as a C int
    # in build-info.cpp). A git hash here breaks the compile.
    version = "0";
    src = pkgs.fetchFromGitHub {
      owner = "TheTom";
      repo = "llama-cpp-turboquant";
      rev = "c3e6dbb13d40e2e42f7a964bd5d745fbf86e4495";
      hash = "sha256-jm77eJ7YLE9aoZGW/Ql1IMKVT6Dz5vuBtUxFPRtdh1c=";
    };
    # Disable the heavy web-UI (vite/esbuild) build — it spawns 100+ node
    # workers and eats ~15GB RAM for nothing. Pluely only needs the HTTP API.
    # nixpkgs' llama-cpp hardcodes `npm run build` in preConfigure and pulls in
    # nodejs + npmHooks; we drop both and skip the UI assets.
    nativeBuildInputs = lib.filter (p: let n = (p.name or ""); in
      !(lib.hasInfix "nodejs" n) && !(lib.hasInfix "npm-" n)
    ) (old.nativeBuildInputs or [ ]);
    # Drop the npm-deps fixed-output derivation entirely so it's never built.
    npmDeps = null;
    npmDepsHash = null;
    npmRoot = null;
    # Replace nixpkgs' preConfigure: keep the COMMIT cmake flag, DROP the
    # `npm run build` (vite/esbuild UI build that eats ~15GB RAM).
    preConfigure = ''
      prependToVar cmakeFlags "-DLLAMA_BUILD_COMMIT:STRING=$(cat COMMIT)"
    '';
    # Restrict CUDA arch to Pascal (sm_61) — the Quadro P2000.
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-DCMAKE_CUDA_ARCHITECTURES=61"
      "-DLLAMA_SERVER_UI=OFF"
    ];
  });

  # ---- meow-stt: faster-whisper (GPU) + Resemblyzer diarization ---------
  # The server + venv live at ~/opt/meow-stt (built by the meow-stt tracker,
  # not nix — pip deps + HF model cache can't live in the read-only store).
  # ctranslate2's PyPI CUDA wheel has no RPATH to the store's CUDA libs, so the
  # unit MUST export LD_LIBRARY_PATH to the system CUDA 12.9 + driver shim.
  meow-stt-home = "/home/kepler452/opt/meow-stt";
  meow-stt-venv-python = "${meow-stt-home}/venv/bin/python";
  cudaLib = pkgs.cudaPackages_12_9.cudatoolkit.lib;   # /nix/store ...-cuda-merged-12.9
  # libcuda.so (driver shim) is provided at runtime by the OpenGL driver at
  # /run/opengl-driver/lib; include it so ctranslate2 can open the device.
  meow-stt-ld = lib.makeLibraryPath [ cudaLib ] + ":/run/opengl-driver/lib";

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

  # (faster-whisper fetches its model from HF cache on first run; no store
  #  model fetch needed for meow-stt.)

  # ---- Comparison vision model: MiniCPM-V 4.6 (1.3B, Q4_K_M) -------------
  # Used only when enableComparison = true. Smaller than LFM (fits easily on
  # the P2000) and stronger on OCR per OpenCompass/OCRBench — handy for
  # reading Pluely's screenshots / docs. Fork-native (minicpmv arch).
  minicpm46-model = pkgs.fetchurl {
    name = "MiniCPM-V-4.6-Q4_K_M.gguf";
    url = "https://huggingface.co/ggml-org/MiniCPM-V-4.6-GGUF/resolve/main/MiniCPM-V-4.6-Q4_K_M.gguf";
    sha256 = "saWqdrXvA5wuV5Jy6jPUu+1+ebSbs/8e/bIzFtavUZk="; # MiniCPM-V 4.6 Q4_K_M
  };
  minicpm46-mmproj = pkgs.fetchurl {
    name = "mmproj-MiniCPM-V-4.6-Q8_0.gguf";
    url = "https://huggingface.co/ggml-org/MiniCPM-V-4.6-GGUF/resolve/main/mmproj-MiniCPM-V-4.6-Q8_0.gguf";
    sha256 = "PYJJzdDhy2mWROsCH7zAQyCq2J+l3JI075TbCEZVZYE="; # MiniCPM-V 4.6 mmproj Q8_0
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

    enableComparison = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Also launch a second vision server (MiniCPM-V 4.6, 1.3B Q4_K_M) on
        port 8082 for A/B comparison against the primary LFM2.5-VL endpoint.
        Off by default: running LFM + MiniCPM + whisper together is tight on
        the 4 GB Quadro P2000. Turn on only when you want to compare models.
      '';
    };

    comparisonPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Port for the optional MiniCPM-V comparison server.";
    };
  };

  ##########################################################################
  # Implementation
  ##########################################################################
  config = lib.mkIf cfg.enable {
    # CUDA + the two forks/models are unfree-adjacent; allow what we need.
    nixpkgs.config.cudaSupport = true;

    environment.systemPackages = [ turboquant-llama ];

    # ---- General LLM server (TurboQuant llama.cpp) ----------------------
    # NOTE: named llm-stack-vl (not llama-server) to avoid colliding with
    # nixpkgs' stock services.llama-cpp.server unit.
    # ExecStart MUST be a single string — a list emits multiple ExecStart=
    # lines, which systemd rejects (bad unit file).
    systemd.services.llm-stack-vl = {
      description = "TurboQuant llama.cpp server (LFM2.5-VL-1.6B text+vision, CUDA)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${turboquant-llama}/bin/llama-server --model ${lfm25vl-model} --mmproj ${lfm25vl-mmproj} --host 127.0.0.1 --port ${toString cfg.llamaPort} --ctx-size ${toString cfg.contextSize} --n-gpu-layers ${toString cfg.gpuLayers} --cache-type-k ${cfg.kvCacheType} --cache-type-v ${cfg.kvCacheType} --flash-attn on --alias LFM2.5-VL-1.6B";
        Restart = "on-failure";
        RestartSec = 3;
        DynamicUser = true;
        # Needs access to the NVIDIA device nodes.
        SupplementaryGroups = [ "video" "render" ];
      };
    };

    # ---- meow-stt STT server (faster-whisper GPU + diarization) ---------
    # Runs the venv Flask server on :8081. LD_LIBRARY_PATH is required so the
    # PyPI ctranslate2 cu12 wheel can find the system CUDA 12.9 runtime + the
    # libcuda.so driver shim. Runs as the human user (not DynamicUser) because
    # it reads the persistent venv + HF cache under /home/kepler452.
    # Restart=always (not on-failure) so the unit respawns even after a clean
    # stop / SIGTERM, and survives transient GPU-memory errors (the server
    # unloads whisper between requests to share the 4 GB VRAM with LFM).
    systemd.services.meow-stt = {
      description = "meow-stt: faster-whisper (GPU) + Resemblyzer diarization";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${meow-stt-venv-python} ${meow-stt-home}/server.py";
        Restart = "always";
        RestartSec = 3;
        User = "kepler452";
        WorkingDirectory = meow-stt-home;
        Environment = [
          "LD_LIBRARY_PATH=${meow-stt-ld}"
          "MEOW_STT_UNLOAD=1"
          "MEOW_STT_MODEL=small"
          "MEOW_STT_DEVICE=cuda"
          "MEOW_STT_COMPUTE=float32"
          "MEOW_STT_PYTHON=${meow-stt-venv-python}"
        ];
        SupplementaryGroups = [ "video" "render" ];
        # server binds 127.0.0.1:8081; protect from the net
        NoNewPrivileges = true;
      };
    };

    # ---- Optional MiniCPM-V 4.6 comparison server ----------------------
    systemd.services.llm-stack-vl-minicpm = lib.mkIf cfg.enableComparison {
      description = "TurboQuant llama.cpp comparison server (MiniCPM-V 4.6 vision, CUDA)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "llm-stack-vl.service" ];
      serviceConfig = {
        ExecStart = "${turboquant-llama}/bin/llama-server --model ${minicpm46-model} --mmproj ${minicpm46-mmproj} --host 127.0.0.1 --port ${toString cfg.comparisonPort} --ctx-size ${toString cfg.contextSize} --n-gpu-layers ${toString cfg.gpuLayers} --cache-type-k ${cfg.kvCacheType} --cache-type-v ${cfg.kvCacheType} --flash-attn on --alias MiniCPM-V-4.6";
        Restart = "on-failure";
        RestartSec = 3;
        DynamicUser = true;
        SupplementaryGroups = [ "video" "render" ];
      };
    };
  };
}
