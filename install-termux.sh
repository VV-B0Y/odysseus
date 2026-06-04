#!/usr/bin/env bash
# install-termux.sh — Interactive Odysseus installer for Termux (Android ARM64)
#
# Usage:  bash install-termux.sh
#
# What it does:
#   1. Installs required Termux system packages (openssl, libffi, …)
#   2. Presents a feature menu so you choose which optional modules to include
#   3. Writes requirements-termux-selected.txt from your choices
#   4. pip-installs the selected requirements
#   5. Writes a .env with Termux-safe defaults and your feature choices
#
# Run from the Odysseus repo root directory.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${HOME}/odysseus-data"
REQS_OUT="${REPO_DIR}/requirements-termux-selected.txt"
ENV_OUT="${REPO_DIR}/.env"

# ── Colour helpers ──────────────────────────────────────────────────────────
_bold()  { printf '\033[1m%s\033[0m' "$*"; }
_green() { printf '\033[32m%s\033[0m' "$*"; }
_cyan()  { printf '\033[36m%s\033[0m' "$*"; }
_yellow(){ printf '\033[33m%s\033[0m' "$*"; }

echo ""
echo "$(_bold "╔══════════════════════════════════════════╗")"
echo "$(_bold "║   Odysseus — Termux Installer            ║")"
echo "$(_bold "╚══════════════════════════════════════════╝")"
echo ""

# ── Phase 0 — Termux system packages ────────────────────────────────────────
echo "$(_bold "Phase 0: Installing Termux system packages...")"
echo "(This may take a minute on first run.)"
echo ""

pkg update -y 2>/dev/null || true
pkg install -y \
    python \
    openssl \
    libffi \
    libjpeg-turbo \
    libpng \
    zlib \
    clang \
    make \
    2>/dev/null || true

echo "$(_green "✓") System packages ready."
echo ""

# ── Phase 1 — Feature menu ──────────────────────────────────────────────────
echo "$(_bold "Phase 1: Choose optional features")"
echo "The following features are $(_bold "disabled by default") on Termux (GPU/desktop-only)."
echo "They will be turned off in your .env automatically."
echo ""
echo "  $(_yellow "Disabled (desktop/GPU only):")"
echo "  • STT (Speech-to-Text / faster-whisper) — 1–2 GB, fragile ARM wheel"
echo "  • TTS (Text-to-Speech)                  — needs Android audio stack"
echo "  • Image Gallery + Editor                — Stable Diffusion / GPU"
echo "  • Email (IMAP/SMTP)                     — Dovecot not on Android"
echo "  • Vault (Bitwarden CLI)                 — bw binary not on Termux"
echo "  • Cookbook (model download/serve)       — GPU model management"
echo "  • Shell / PTY execution                 — dangerous on a phone"
echo "  • Signature stamping                    — desktop PDF workflow"
echo "  • Companion bridge                      — LAN phone-to-desktop"
echo "  • HWFit (GPU profiler)                  — CUDA/ROCm meaningless"
echo "  • Codex / Claude integrations           — desktop IDE plugins"
echo ""
echo "$(_bold "The following OPTIONAL features are available. Choose which to install:")"
echo ""

# Helper: ask yes/no, default passed as 2nd arg ("y" or "n")
_ask() {
    local prompt="$1" default="${2:-y}"
    local yn
    if [[ "$default" == "y" ]]; then
        printf "%s [Y/n] " "$prompt"
    else
        printf "%s [y/N] " "$prompt"
    fi
    read -r yn </dev/tty
    yn="${yn:-$default}"
    [[ "${yn,,}" == "y" || "${yn,,}" == "yes" ]]
}

WANT_RAG=false
WANT_CALDAV=false
WANT_DEEP_RESEARCH=false
WANT_CONTACTS=false
WANT_YOUTUBE=false
WANT_DOCS=false
WANT_MCP=false
WANT_WEBHOOKS=false
WANT_DDG=false
WANT_COMPARE=false

echo "$(_cyan "[A]") RAG / Semantic memory"
echo "     Adds chromadb (embedded) + fastembed (~200 MB ONNX download on first run)"
_ask "     Install RAG?" "n" && WANT_RAG=true

echo ""
echo "$(_cyan "[B]") Deep Research (multi-step LLM search loop)"
echo "     No extra deps — uses your configured LLM + search."
_ask "     Enable Deep Research?" "y" && WANT_DEEP_RESEARCH=true

echo ""
echo "$(_cyan "[C]") Calendar + CalDAV sync (Nextcloud / Radicale / Apple / Fastmail)"
echo "     Core calendar is already included. CalDAV adds the 'caldav' sync library."
_ask "     Install CalDAV sync?" "n" && WANT_CALDAV=true

echo ""
echo "$(_cyan "[D]") Contacts (CardDAV — no extra deps, uses httpx)"
_ask "     Enable CardDAV Contacts?" "y" && WANT_CONTACTS=true

echo ""
echo "$(_cyan "[E]") YouTube transcript fetching"
echo "     Adds 'youtube-transcript-api' (already in core txt, always included)."
WANT_YOUTUBE=true  # already in core, no prompt needed

echo ""
echo "$(_cyan "[F]") Document extraction (Office / EPUB via markitdown)"
echo "     Adds markitdown + mammoth/lxml/pptx — heavy transitive deps."
_ask "     Install document extraction?" "n" && WANT_DOCS=true

echo ""
echo "$(_cyan "[G]") MCP tools protocol"
echo "     Adds 'mcp' package for external MCP server connections."
_ask "     Install MCP?" "n" && WANT_MCP=true

echo ""
echo "$(_cyan "[H]") Webhooks / ntfy notifications"
echo "     No extra deps — webhooks are always available in the core."
WANT_WEBHOOKS=true  # no extra deps

echo ""
echo "$(_cyan "[I]") DuckDuckGo search provider"
echo "     Adds 'duckduckgo-search'. Skip if you use SearXNG / Brave / Tavily."
_ask "     Install DuckDuckGo search?" "n" && WANT_DDG=true

echo ""
echo "$(_cyan "[J]") Model A/B comparison"
echo "     No extra deps — lightweight route."
_ask "     Enable model comparison?" "y" && WANT_COMPARE=true

echo ""

# ── Phase 2 — Write requirements file ────────────────────────────────────────
echo "$(_bold "Phase 2: Writing ${REQS_OUT}...")"

{
    echo "# Auto-generated by install-termux.sh — do not edit manually"
    echo "# Re-run install-termux.sh to regenerate."
    echo ""
    cat "${REPO_DIR}/requirements-termux-core.txt" | grep -v '^#' | grep -v '^$'
    echo ""
    echo "# ── Selected optional features ──"

    if $WANT_RAG; then
        echo "chromadb"
        echo "fastembed"
        echo "# Add openblas via: pkg install openblas"
    fi

    if $WANT_CALDAV; then
        echo "caldav"
    fi

    if $WANT_DOCS; then
        echo "markitdown[docx,pptx,xlsx,xls]==0.1.5"
    fi

    if $WANT_MCP; then
        echo "mcp"
    fi

    if $WANT_DDG; then
        echo "duckduckgo-search"
    fi
} > "${REQS_OUT}"

echo "$(_green "✓") Written: ${REQS_OUT}"
echo ""

# ── Phase 3 — pip install ───────────────────────────────────────────────────
echo "$(_bold "Phase 3: Installing Python packages...")"
echo "(This may take several minutes on first run.)"
echo ""

pip install -r "${REQS_OUT}"

echo ""
echo "$(_green "✓") Python packages installed."
echo ""

# ── Phase 4 — Write .env ────────────────────────────────────────────────────
echo "$(_bold "Phase 4: Writing Termux .env defaults...")"

if [[ -f "${ENV_OUT}" ]]; then
    echo "$(_yellow "⚠") ${ENV_OUT} already exists — backing up to ${ENV_OUT}.bak"
    cp "${ENV_OUT}" "${ENV_OUT}.bak"
fi

mkdir -p "${DATA_DIR}"

# ── Feature flags: everything disabled defaults to false ──
feat_tts="false"
feat_stt="false"
feat_gallery="false"
feat_email="false"
feat_vault="false"
feat_cookbook="false"
feat_shell="false"
feat_signature="false"
feat_companion="false"
feat_hwfit="false"
feat_codex="false"

feat_research="true"
if ! $WANT_DEEP_RESEARCH; then feat_research="false"; fi

feat_mcp="false"
if $WANT_MCP; then feat_mcp="true"; fi

feat_compare="false"
if $WANT_COMPARE; then feat_compare="true"; fi

feat_contacts="false"
if $WANT_CONTACTS; then feat_contacts="true"; fi

# Contacts route is unconditional in app.py (no feature flag) so this is
# informational only; the env var is kept for future guards.

cat > "${ENV_OUT}" << ENVEOF
# .env — generated by install-termux.sh for Termux (Android ARM64)
# Edit this file to customise your setup.

# ────────────────────────────────────────────────────────────────
# Paths
# ────────────────────────────────────────────────────────────────
BASE_DIR=${REPO_DIR}
DATA_DIR=${DATA_DIR}

# ────────────────────────────────────────────────────────────────
# LLM — point to your Ollama (or any OpenAI-compatible) server
# ────────────────────────────────────────────────────────────────
LLM_HOST=localhost
# OPENAI_API_KEY=your_key_here

# ────────────────────────────────────────────────────────────────
# Search — SearXNG (recommended) or set a provider key below
# ────────────────────────────────────────────────────────────────
SEARXNG_INSTANCE=http://localhost:8080

# ────────────────────────────────────────────────────────────────
# Auth & Security
# ────────────────────────────────────────────────────────────────
AUTH_ENABLED=true
# LOCALHOST_BYPASS=false  # keep false; set true only if you know the risks
# BASEDCODE_AI_ADMIN_PASSWORD=change_me_before_first_boot

# ────────────────────────────────────────────────────────────────
# ChromaDB (vector RAG) — embedded mode, no separate server
# ────────────────────────────────────────────────────────────────
# When CHROMADB_HOST is unset, the app uses chromadb in embedded mode.
# CHROMADB_HOST=
# CHROMADB_PORT=

# HuggingFace model cache (fastembed ONNX model, ~50 MB)
HF_HOME=${HOME}/.cache/huggingface

# ────────────────────────────────────────────────────────────────
# Feature flags — desktop/GPU features disabled for Termux
# ────────────────────────────────────────────────────────────────
FEATURE_TTS=${feat_tts}
FEATURE_STT=${feat_stt}
FEATURE_GALLERY=${feat_gallery}
FEATURE_EMAIL=${feat_email}
FEATURE_VAULT=${feat_vault}
FEATURE_COOKBOOK=${feat_cookbook}
FEATURE_SHELL=${feat_shell}
FEATURE_SIGNATURE=${feat_signature}
FEATURE_COMPANION=${feat_companion}
FEATURE_HWFIT=${feat_hwfit}
FEATURE_CODEX=${feat_codex}
FEATURE_MCP=${feat_mcp}
FEATURE_COMPARE=${feat_compare}

# ────────────────────────────────────────────────────────────────
# Performance tuning for a mobile device
# ────────────────────────────────────────────────────────────────
# Reduce context window to save RAM on low-memory devices
# LLM_MAX_CONTEXT_MESSAGES=30
# REQUEST_HARD_TIMEOUT=60
ENVEOF

echo "$(_green "✓") Written: ${ENV_OUT}"
echo ""

# ── Done ─────────────────────────────────────────────────────────────────────
echo "$(_bold "═══════════════════════════════════════════════")"
echo "$(_green "✓ Install complete!")"
echo ""
echo "  Start the server:"
echo "    cd ${REPO_DIR}"
echo "    python -m uvicorn app:app --host 0.0.0.0 --port 7000"
echo ""
echo "  Then open in your browser (or another device on the same LAN):"
echo "    http://127.0.0.1:7000"
echo ""
if $WANT_RAG; then
    echo "  $(_yellow "Note:") RAG is enabled. On first message the ONNX embedding model (~50 MB)"
    echo "  will be downloaded to ${HOME}/.cache/huggingface — this takes a moment."
    echo ""
fi
echo "  Edit $(_bold ".env") to change the LLM host, search provider, or other settings."
echo "$(_bold "═══════════════════════════════════════════════")"
