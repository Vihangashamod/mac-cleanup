#!/bin/zsh
# ─────────────────────────────────────────
#  CleanMyMac — Mac Cleanup Script
#  Run manually or via CleanMyMac.app
# ─────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"
echo "${BOLD}${CYAN}║         🧹  CleanMyMac               ║${NC}"
echo "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

BEFORE_AVAIL=$(df -k / | tail -1 | awk '{print $4}')
BEFORE_HUMAN=$(df -h / | tail -1 | awk '{print $4}')
echo "${YELLOW}  Disk free before: ${BEFORE_HUMAN}${NC}"
echo ""

BEFORE_KB=$BEFORE_AVAIL

_del() {
  local label="$1"; shift
  local found=0
  for p in "$@"; do
    [ -e "$p" ] && found=1 && break
  done
  if [ $found -eq 1 ]; then
    for p in "$@"; do rm -rf "$p" 2>/dev/null; done
    echo "  ${GREEN}✅ $label${NC}"
  else
    echo "  ${CYAN}—  $label${NC} (already clean)"
  fi
}

# ── 1. System caches & logs ──────────────
echo "${BOLD}📦 System caches & logs${NC}"
_del "User Library Caches"       ~/Library/Caches/
_del "System Logs"               ~/Library/Logs/

# ── 2. VS Code ───────────────────────────
echo ""
echo "${BOLD}💻 VS Code${NC}"
_del "Extension installer cache" ~/Library/Application\ Support/Code/CachedExtensionVSIXs/
_del "VS Code logs"              ~/Library/Application\ Support/Code/logs/
_del "VS Code CachedData"        ~/Library/Application\ Support/Code/CachedData/
_del "VS Code GPUCache"          ~/Library/Application\ Support/Code/GPUCache/

# ── 3. Notion ────────────────────────────
echo ""
echo "${BOLD}📝 Notion${NC}"
NOTION=~/Library/Application\ Support/Notion/Partitions/notion
_del "Notion Cache"              "$NOTION/Cache/"
_del "Notion Service Worker"     "$NOTION/Service Worker/"
_del "Notion GPU Cache"          "$NOTION/GPUCache/"
_del "Notion Code Cache"         "$NOTION/Code Cache/"
_del "Notion Dawn WebGPU Cache"  "$NOTION/DawnWebGPUCache/"
_del "Notion Graphite Cache"     "$NOTION/DawnGraphiteCache/"

# ── 4. Claude ────────────────────────────
echo ""
echo "${BOLD}🤖 Claude${NC}"
_del "Claude vm_bundles"         ~/Library/Application\ Support/Claude/vm_bundles/

# ── 5. Browsers ──────────────────────────
echo ""
echo "${BOLD}🌐 Browsers${NC}"
_del "Chrome Cache"              ~/Library/Caches/Google/Chrome/
_del "Chrome GPU Cache"          ~/Library/Application\ Support/Google/Chrome/Default/GPUCache/
_del "Brave Cache"               ~/Library/Application\ Support/BraveSoftware/Brave-Browser/Default/Cache/

# ── 6. Spotify ───────────────────────────
echo ""
echo "${BOLD}🎵 Spotify${NC}"
_del "Spotify Cache"             ~/Library/Caches/com.spotify.client/
_del "Spotify Persistent Cache"  ~/Library/Application\ Support/Spotify/PersistentCache/

# ── 7. Kimi ──────────────────────────────
echo ""
echo "${BOLD}💬 Kimi${NC}"
_del "Kimi Cache"                ~/Library/Application\ Support/kimi-desktop/Cache/
_del "Kimi GPU Cache"            ~/Library/Application\ Support/kimi-desktop/GPUCache/

# ── 8. Build tools ───────────────────────
echo ""
echo "${BOLD}🔧 Build tools${NC}"

# npm cache
npm cache clean --force &>/dev/null && echo "  ${GREEN}✅ npm cache${NC}" || echo "  ${CYAN}—  npm (not found)${NC}"

# conda cache
if command -v /opt/anaconda3/bin/conda &>/dev/null; then
  /opt/anaconda3/bin/conda clean --all --yes &>/dev/null
  echo "  ${GREEN}✅ conda cache${NC}"
fi

# Python __pycache__
COUNT=$(find ~/Projects ~/Desktop ~/Documents -name "__pycache__" \
  -not -path "*/venv/*" -not -path "*/.venv/*" -not -path "*/node_modules/*" \
  2>/dev/null | wc -l | tr -d ' ')
find ~/Projects ~/Desktop ~/Documents -name "__pycache__" \
  -not -path "*/venv/*" -not -path "*/.venv/*" -not -path "*/node_modules/*" \
  -exec rm -rf {} + 2>/dev/null
echo "  ${GREEN}✅ Python __pycache__ ($COUNT folders)${NC}"

# Word temp files
find ~/Documents ~/Desktop ~/Downloads -name "~\$*" -delete 2>/dev/null
echo "  ${GREEN}✅ Word temp files${NC}"

# ── 9. Network ───────────────────────────
echo ""
echo "${BOLD}🌍 Network${NC}"
dscacheutil -flushcache 2>/dev/null
killall -HUP mDNSResponder 2>/dev/null
echo "  ${GREEN}✅ DNS cache flushed${NC}"

# ── 10. Trash ────────────────────────────
echo ""
echo "${BOLD}🗑  Trash${NC}"
TRASH_SIZE=$(du -sk ~/.Trash 2>/dev/null | awk '{print $1}')
if [ "${TRASH_SIZE:-0}" -gt 0 ]; then
  FREED=$((FREED + TRASH_SIZE))
  rm -rf ~/.Trash/* 2>/dev/null
  mb=$((TRASH_SIZE / 1024))
  echo "  ${GREEN}✅ Trash emptied${NC} — ${mb}MB"
else
  echo "  ${CYAN}—  Trash already empty${NC}"
fi

# ── Results ──────────────────────────────
AFTER_AVAIL=$(df -k / | tail -1 | awk '{print $4}')
AFTER_HUMAN=$(df -h / | tail -1 | awk '{print $4}')
FREED_KB=$((AFTER_AVAIL - BEFORE_KB))
FREED_MB=$((FREED_KB / 1024))

echo ""
echo "${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
echo "${BOLD}${GREEN}║        ✅ Cleanup Complete!           ║${NC}"
echo "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo "  Before : ${YELLOW}${BEFORE_HUMAN}${NC} free"
echo "  After  : ${GREEN}${AFTER_HUMAN}${NC} free"
echo "  Freed  : ${BOLD}${GREEN}~${FREED_MB} MB${NC}"
echo ""
echo "${CYAN}  💡 For RAM: sudo purge${NC}"
echo "${CYAN}  💡 Claude vm_bundles cleared — will rebuild on next open${NC}"
echo ""
