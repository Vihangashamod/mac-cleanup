#!/bin/bash
# CleanMyMac v2 — scan your Mac, choose what to clean, clean it.
#
#   cleanmymac.sh                    interactive menu (Terminal)
#   cleanmymac.sh --quick            safe everyday clean
#   cleanmymac.sh --items a,b,c      clean specific items (see --list)
#   cleanmymac.sh --all              everything
#   cleanmymac.sh --dry-run [...]    preview only, nothing is removed
#   cleanmymac.sh --scan             machine-readable scan (used by the app)
set -euo pipefail

VERSION="2.0.0"
LOG_FILE="$HOME/Library/Logs/CleanMyMac.log"
AS="$HOME/Library/Application Support"
# ~/Desktop/Programming is deliberately not listed: it is never touched.
PROJECT_ROOTS=("$HOME/Projects" "$HOME/Desktop/Projects" "$HOME/Desktop/Companies")
STALE_DAYS=7
INSTALLER_AGE_DAYS=14

QUICK_ITEMS="caches logs vscode notion browsers spotify npm pycache wordtemp"
ADVANCED_ITEMS="trash claude xcode gradle brew conda docker node_modules next_builds venvs old_installers dup_downloads system large_files"
COMMAND_ITEMS="trash brew conda docker system large_files"
TRASH_INSTEAD="old_installers dup_downloads"

DRY_RUN=0
NOTIFY=0
MODE=""
SELECTED=""
ITEMS_TOTAL=0
LOG_PARTS=""

if [ -t 1 ]; then
  G=$'\033[0;32m' C=$'\033[0;36m' Y=$'\033[1;33m' B=$'\033[1m' N=$'\033[0m'
else
  G="" C="" Y="" B="" N=""
fi

ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
skip() { printf '  %s–%s %s\n' "$C" "$N" "$*"; }
has()  { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }
human() { awk -v k="${1:-0}" 'BEGIN { if (k >= 1048576) printf "%.1f GB", k/1048576; else if (k >= 1024) printf "%.0f MB", k/1024; else printf "%d KB", k }'; }
kb_of() { local s; s=$(du -sk "$1" 2>/dev/null | cut -f1) || true; echo "${s:-0}"; }
free_kb() { df -k / | awk 'NR==2 { print $4 }'; }
app_running() {
  case "$(ps -axo comm=)" in *"/$1.app/Contents/MacOS/"*) return 0 ;; esac
  return 1
}
trash_size() { if ls "$HOME/.Trash" >/dev/null 2>&1; then human "$(kb_of "$HOME/.Trash")"; else echo "size unknown"; fi; }
conda_bin() { command -v conda 2>/dev/null || echo /opt/anaconda3/bin/conda; }

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

label_for() {
  case "$1" in
    caches)         echo "System & app caches" ;;
    logs)           echo "Log files" ;;
    vscode)         echo "VS Code caches" ;;
    notion)         echo "Notion caches" ;;
    browsers)       echo "Chrome & Brave code caches" ;;
    spotify)        echo "Spotify cache" ;;
    npm)            echo "npm cache" ;;
    pycache)        echo "Python __pycache__ folders" ;;
    wordtemp)       echo "Word temp files (~\$...)" ;;
    trash)          echo "Empty the Trash" ;;
    claude)         echo "Claude vm_bundles" ;;
    xcode)          echo "Xcode DerivedData" ;;
    gradle)         echo "Gradle caches" ;;
    brew)           echo "Homebrew downloads" ;;
    conda)          echo "Conda unused packages" ;;
    docker)         echo "Docker unused images & containers" ;;
    node_modules)   echo "node_modules (projects idle ${STALE_DAYS}+ days)" ;;
    next_builds)    echo ".next builds (projects idle ${STALE_DAYS}+ days)" ;;
    venvs)          echo "Python venvs (projects idle ${STALE_DAYS}+ days)" ;;
    old_installers) echo "Old .dmg/.pkg/.zip in Downloads → Trash" ;;
    dup_downloads)  echo "Duplicate downloads like 'file (1)' → Trash" ;;
    system)         echo "Free RAM + reset font & DNS caches (password)" ;;
    large_files)    echo "List files over 500 MB (report only)" ;;
    *) return 1 ;;
  esac
}

# Prints the app that must be closed before an item is cleaned, if it is open.
blocking_app() {
  local app
  case "$1" in
    claude)  app="Claude" ;;
    notion)  app="Notion" ;;
    spotify) app="Spotify" ;;
    vscode)  app="Visual Studio Code" ;;
    *) return 1 ;;
  esac
  if app_running "$app"; then echo "$app"; return 0; fi
  return 1
}

# Build folders inside projects that have had no file edits for STALE_DAYS.
find_stale() {
  local args=() n root d proj recent
  for n in "$@"; do
    if [ ${#args[@]} -gt 0 ]; then args+=(-o); fi
    args+=(-name "$n")
  done
  for root in "${PROJECT_ROOTS[@]}"; do
    if [ -d "$root" ]; then find "$root" -type d \( "${args[@]}" \) -prune -print 2>/dev/null; fi
  done | while IFS= read -r d; do
    proj=$(dirname "$d")
    case "$proj" in */node_modules*|*/.next*) continue ;; esac
    recent=$(find "$proj" -maxdepth 3 \( -name node_modules -o -name .next -o -name .venv -o -name venv -o -name .git \) -prune \
      -o -type f -mtime -"$STALE_DAYS" -print 2>/dev/null | head -1) || true
    if [ -z "$recent" ]; then echo "$d"; fi
  done
  return 0
}

paths_for() {
  local r
  case "$1" in
    caches)   find "$HOME/Library/Caches" -mindepth 1 -maxdepth 1 ;;
    logs)     find "$HOME/Library/Logs" -mindepth 1 -maxdepth 1 ! -name CleanMyMac.log ;;
    vscode)   r="$AS/Code"; printf '%s\n' "$r/CachedExtensionVSIXs" "$r/CachedData" "$r/logs" "$r/GPUCache" ;;
    notion)   r="$AS/Notion/Partitions/notion"
              printf '%s\n' "$r/Cache" "$r/Service Worker" "$r/Code Cache" "$r/GPUCache" "$r/DawnWebGPUCache" "$r/DawnGraphiteCache" ;;
    browsers) if ! app_running "Google Chrome"; then
                printf '%s\n' "$AS/Google/Chrome/Default/Code Cache" "$AS/Google/Chrome/Default/GPUCache"
              fi
              if ! app_running "Brave Browser"; then
                printf '%s\n' "$AS/BraveSoftware/Brave-Browser/Default/Cache" "$AS/BraveSoftware/Brave-Browser/Default/Code Cache"
              fi ;;
    spotify)  printf '%s\n' "$HOME/Library/Caches/com.spotify.client" "$AS/Spotify/PersistentCache" ;;
    npm)      echo "$HOME/.npm/_cacache" ;;
    pycache)  for r in "${PROJECT_ROOTS[@]}" "$HOME/Documents"; do
                if [ -d "$r" ]; then
                  find "$r" -type d \( -name node_modules -o -name venv -o -name .venv \) -prune -o -type d -name __pycache__ -prune -print
                fi
              done ;;
    wordtemp) find "$HOME/Documents" "$HOME/Desktop" "$HOME/Downloads" -path "$HOME/Desktop/Programming" -prune -o -type f -name '~$*' -print ;;
    claude)   echo "$AS/Claude/vm_bundles" ;;
    xcode)    echo "$HOME/Library/Developer/Xcode/DerivedData" ;;
    gradle)   echo "$HOME/.gradle/caches" ;;
    node_modules) find_stale node_modules ;;
    next_builds)  find_stale .next ;;
    venvs)        find_stale venv .venv ;;
    old_installers) find "$HOME/Downloads" -maxdepth 1 -type f \( -name '*.dmg' -o -name '*.pkg' -o -name '*.zip' \) -mtime +"$INSTALLER_AGE_DAYS" ;;
    dup_downloads)  find "$HOME/Downloads" -mindepth 1 -maxdepth 1 \( -name '* ([0-9])' -o -name '* ([0-9]).*' \) ;;
  esac
  return 0
}

# Finder's delete keeps "Put Back" working.
move_to_trash() {
  osascript -e 'on run argv' -e 'tell application "Finder" to delete (POSIX file (item 1 of argv) as alias)' -e 'end run' "$1" >/dev/null 2>&1 || true
}

clean_paths() {
  local id=$1 label=$2 p kb total=0 count=0
  while IFS= read -r p; do
    if [ -z "$p" ] || [ ! -e "$p" ]; then continue; fi
    kb=$(kb_of "$p")
    count=$((count + 1))
    if [ "$DRY_RUN" = 1 ]; then total=$((total + kb)); continue; fi
    if has "$TRASH_INSTEAD" "$id"; then move_to_trash "$p"; else rm -rf "$p" 2>/dev/null || true; fi
    # Protected files (e.g. com.apple.* caches) survive rm; don't count them.
    if [ -e "$p" ]; then kb=$((kb - $(kb_of "$p"))); fi
    total=$((total + kb))
  done < <(paths_for "$id" 2>/dev/null || true)

  ITEMS_TOTAL=$((ITEMS_TOTAL + total))
  LOG_PARTS="$LOG_PARTS $id=$(human "$total" | tr -d ' ')"
  if [ "$count" -eq 0 ]; then
    skip "$label — already clean"
  elif [ "$DRY_RUN" = 1 ]; then
    ok "$label — would free $(human "$total") ($count item(s))"
  elif has "$TRASH_INSTEAD" "$id"; then
    ok "$label — $count moved to Trash ($(human "$total"))"
  else
    ok "$label — $(human "$total")"
  fi
}

run_command() {
  local id=$1 bin f found=0
  local sys_cmd='purge; atsutil databases -remove >/dev/null 2>&1; dscacheutil -flushcache; killall -HUP mDNSResponder; tmutil deletelocalsnapshots / >/dev/null 2>&1; true'
  case "$id" in
    trash)
      if [ "$DRY_RUN" = 1 ]; then ok "Would empty the Trash ($(trash_size))"; return 0; fi
      if osascript -e 'tell application "Finder" to empty trash' >/dev/null 2>&1; then ok "Trash emptied"; else skip "Trash — Finder didn't allow it"; fi ;;
    brew)
      if ! command -v brew >/dev/null 2>&1; then skip "Homebrew not installed"; return 0; fi
      if [ "$DRY_RUN" = 1 ]; then ok "Would run: brew cleanup --prune=all ($(human "$(kb_of "$(brew --cache)")"))"; return 0; fi
      brew cleanup --prune=all -s >/dev/null 2>&1 || true
      ok "Homebrew downloads cleaned" ;;
    conda)
      bin=$(conda_bin)
      if [ ! -x "$bin" ]; then skip "Conda not installed"; return 0; fi
      if [ "$DRY_RUN" = 1 ]; then ok "Would run: conda clean --all"; return 0; fi
      "$bin" clean --all --yes >/dev/null 2>&1 || true
      ok "Conda unused packages cleaned (your environments are kept)" ;;
    docker)
      if ! command -v docker >/dev/null 2>&1; then skip "Docker not installed"; return 0; fi
      if ! docker info >/dev/null 2>&1; then skip "Docker isn't running — open Docker Desktop and run again"; return 0; fi
      if [ "$DRY_RUN" = 1 ]; then ok "Would run: docker system prune -a (volumes kept)"; return 0; fi
      docker system prune -af >/dev/null 2>&1 || true
      ok "Docker unused images & containers removed (volumes kept)" ;;
    system)
      if [ "$DRY_RUN" = 1 ]; then ok "Would free RAM and reset font & DNS caches"; return 0; fi
      if [ "$(id -u)" = 0 ]; then
        sh -c "$sys_cmd"; ok "RAM freed, font & DNS caches reset"
      elif sudo -n true 2>/dev/null || [ -t 0 ]; then
        if sudo sh -c "$sys_cmd"; then ok "RAM freed, font & DNS caches reset"; else skip "System tune-up skipped"; fi
      else
        skip "System tune-up needs your password — run it from the app or Terminal"
      fi ;;
    large_files)
      echo "  ${B}Files over 500 MB (review these yourself — nothing deleted):${N}"
      while IFS= read -r f; do
        found=1
        printf '    %8s  %s\n' "$(du -sh "$f" 2>/dev/null | cut -f1)" "~${f#"$HOME"}"
      done < <(find "$HOME" \( -path "$HOME/Library" -o -path "$HOME/Movies" -o -path "$HOME/.Trash" \) -prune \
                 -o -type f -size +500M -print 2>/dev/null | head -15 || true)
      if [ "$found" = 0 ]; then skip "No large files found"; fi ;;
  esac
  return 0
}

# Tab-separated: id, label, size in KB, size text, group. Used by the app.
scan() {
  local id label kb hs group app p
  for id in $QUICK_ITEMS $ADVANCED_ITEMS; do
    group=advanced
    if has "$QUICK_ITEMS" "$id"; then group=quick; fi
    label=$(label_for "$id")
    if app=$(blocking_app "$id"); then label="$label (quit $app first)"; fi
    kb=0
    case "$id" in
      trash)  kb=$(kb_of "$HOME/.Trash"); hs=$(trash_size) ;;
      brew)   if ! command -v brew >/dev/null 2>&1; then continue; fi
              kb=$(kb_of "$(brew --cache)"); hs=$(human "$kb") ;;
      conda)  if [ ! -x "$(conda_bin)" ]; then continue; fi; hs="varies" ;;
      docker) if ! command -v docker >/dev/null 2>&1; then continue; fi
              if docker info >/dev/null 2>&1; then hs="varies"; else hs="start Docker first"; fi ;;
      system) hs="needs password" ;;
      large_files) hs="report" ;;
      *)
        while IFS= read -r p; do
          if [ -n "$p" ] && [ -e "$p" ]; then kb=$((kb + $(kb_of "$p"))); fi
        done < <(paths_for "$id" 2>/dev/null || true)
        if [ "$kb" -eq 0 ]; then continue; fi
        hs=$(human "$kb") ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$label" "$kb" "$hs" "$group"
  done
}

run_selected() {
  local id label app before after freed summary
  before=$(free_kb)
  echo ""
  echo "${B}${C}🧹 CleanMyMac v$VERSION${N}$( [ "$DRY_RUN" = 1 ] && echo "  ${Y}(dry run — nothing will be removed)${N}" )"
  echo "${Y}   Free before: $(human "$before")${N}"
  echo ""
  for id in $QUICK_ITEMS $ADVANCED_ITEMS; do
    if ! has "$SELECTED" "$id"; then continue; fi
    label=$(label_for "$id")
    if app=$(blocking_app "$id"); then
      skip "$label — skipped, $app is open (quit it and run again)"
      continue
    fi
    if has "$COMMAND_ITEMS" "$id"; then run_command "$id"; else clean_paths "$id" "$label"; fi
  done

  after=$(free_kb)
  freed=$((after - before))
  if [ "$freed" -lt 0 ]; then freed=0; fi
  echo ""
  if [ "$DRY_RUN" = 1 ]; then
    summary="Would free about $(human "$ITEMS_TOTAL")"
  else
    summary="Freed $(human "$freed") · $(human "$after") free"
    log "freed=$(human "$freed" | tr -d ' ') free=$(human "$after" | tr -d ' ') items:$LOG_PARTS"
  fi
  echo "${B}${G}✅ $summary${N}"
  echo ""
  if [ "$NOTIFY" = 1 ]; then
    osascript -e "display notification \"$summary\" with title \"CleanMyMac\"" >/dev/null 2>&1 || true
  fi
}

interactive() {
  local ids=() id label kb hs group i=0 ans n
  echo "Scanning your Mac…"
  echo ""
  while IFS=$'\t' read -r id label kb hs group; do
    i=$((i + 1))
    ids+=("$id")
    printf '  %2d) %-54s %14s  %s\n' "$i" "$label" "$hs" "$group"
  done < <(scan)
  echo ""
  printf 'Choose: [Enter] quick · a = all · d = preview all · or numbers like "1 4 7": '
  read -r ans || ans=""
  case "$ans" in
    ""|q|Q) SELECTED="$QUICK_ITEMS" ;;
    a|A)    SELECTED="$QUICK_ITEMS $ADVANCED_ITEMS" ;;
    d|D)    SELECTED="$QUICK_ITEMS $ADVANCED_ITEMS"; DRY_RUN=1 ;;
    *)
      for n in $ans; do
        case "$n" in ''|*[!0-9]*) echo "Ignoring '$n'"; continue ;; esac
        if [ "$n" -ge 1 ] && [ "$n" -le "$i" ]; then SELECTED="$SELECTED ${ids[$((n - 1))]}"; fi
      done ;;
  esac
  if [ -z "$SELECTED" ]; then echo "Nothing selected."; exit 0; fi
  run_selected
}

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --quick)   MODE=run; SELECTED="$QUICK_ITEMS" ;;
    --all)     MODE=run; SELECTED="$QUICK_ITEMS $ADVANCED_ITEMS" ;;
    --items)   if [ $# -lt 2 ]; then echo "--items needs a list, e.g. --items caches,claude" >&2; exit 2; fi
               MODE=run; SELECTED=$(echo "$2" | tr ',' ' '); shift ;;
    --items=*) MODE=run; SELECTED=$(echo "${1#--items=}" | tr ',' ' ') ;;
    --dry-run) DRY_RUN=1 ;;
    --notify)  NOTIFY=1 ;;
    --scan)    MODE=scan ;;
    --list)    MODE=list ;;
    -v|--version) echo "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

for id in $SELECTED; do
  if ! label_for "$id" >/dev/null; then echo "Unknown item '$id' (see --list)" >&2; exit 2; fi
done

if [ -z "$MODE" ] && [ "$DRY_RUN" = 1 ]; then MODE=run; SELECTED="$QUICK_ITEMS $ADVANCED_ITEMS"; fi

case "$MODE" in
  run)  run_selected ;;
  scan) scan ;;
  list) for id in $QUICK_ITEMS $ADVANCED_ITEMS; do
          if has "$QUICK_ITEMS" "$id"; then g=quick; else g=advanced; fi
          printf '%-15s %-9s %s\n' "$id" "$g" "$(label_for "$id")"
        done ;;
  *)    if [ -t 0 ]; then interactive; else usage; fi ;;
esac
