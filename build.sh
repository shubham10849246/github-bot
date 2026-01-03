
#!/usr/bin/env bash
# Robust build script for packaging a WAR as ROOT.war
# Compiles Java sources into WEB-INF/classes and packages JSP/static assets + WEB-INF.
# Places the final ROOT.war in the repo root.

set -euo pipefail

# Move to the repo root (directory where this script resides)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure src exists
if [ ! -d "src" ]; then
  echo "ERROR: src/ directory not found at repo root: $SCRIPT_DIR"
  exit 1
fi

cd src

# Ensure output directories
mkdir -p WEB-INF/classes

# Build classpath (include WEB-INF/lib/*.jar if present)
CLASSPATH="WEB-INF/classes"
if ls WEB-INF/lib/*.jar >/dev/null 2>&1; then
  CLASSPATH="WEB-INF/lib/*:${CLASSPATH}"
fi

echo "."
echo "Compiling Java sources with CLASSPATH=${CLASSPATH}"

# Compile all Java sources under com/
if find com -type f -name "*.java" >/dev/null 2>&1; then
  javac -classpath "${CLASSPATH}" -d WEB-INF/classes $(find com -type f -name "*.java")
else
  echo "WARNING: No Java sources found under src/com/. Skipping compilation."
fi

echo "."

# Build the WAR contents list safely (include only paths/files that exist)
INCLUDES=()

# Include all JSPs in src/
JSP_FILES=()
shopt -s nullglob
JSP_FILES=( *.jsp )
shopt -u nullglob
if [ ${#JSP_FILES[@]} -gt 0 ]; then
  INCLUDES+=( "${JSP_FILES[@]}" )
fi

# Static asset directories if present
for d in images css js; do
  if [ -d "$d" ]; then
    INCLUDES+=( "$d" )
  fi
done

# Always include WEB-INF
INCLUDES+=( "WEB-INF" )

# Optional .ebextensions configs
EB_CONFIGS=()
shopt -s nullglob
EB_CONFIGS=( .ebextensions/*.config .ebextensions/*.json )
shopt -u nullglob
if [ -d ".ebextensions" ] && [ ${#EB_CONFIGS[@]} -gt 0 ]; then
  INCLUDES+=( "${EB_CONFIGS[@]}" )
fi

# Optional httpd conf.d under .ebextensions
HTTPD_CONFS=()
shopt -s nullglob
HTTPD_CONFS=( .ebextensions/httpd/conf.d/*.conf )
shopt -u nullglob
if [ -d ".ebextensions/httpd/conf.d" ] && [ ${#HTTPD_CONFS[@]} -gt 0 ]; then
  INCLUDES+=( "${HTTPD_CONFS[@]}" )
fi

echo "."
echo "Packaging WAR (ROOT.war) with includes:"
printf '  - %s\n' "${INCLUDES[@]}"

if [ ${#INCLUDES[@]} -eq 0 ]; then
  echo "ERROR: Nothing to package. Ensure JSPs/static assets/WEB-INF exist."
  exit 1
fi

# Create the WAR
jar -cf ROOT.war "${INCLUDES[@]}"

# Optional: copy to local macOS Tomcat if present
if [ -d "/Library/Tomcat/webapps" ]; then
  cp ROOT.war /Library/Tomcat/webapps
  echo "."
fi

# Move WAR to repo root for CI to pick up
mv -f ROOT.war "$SCRIPT_DIR/"

echo "."
echo "SUCCESS: Built ROOT.war at $SCRIPT_DIR/ROOT.war"
