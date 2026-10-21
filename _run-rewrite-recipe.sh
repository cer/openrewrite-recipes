#! /bin/bash -e

REFRESH_DEPS=""
RECIPE_NAME=""
CONFIG_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --refresh-dependencies)
            REFRESH_DEPS="--refresh-dependencies"
            shift
            ;;
        --recipe)
            RECIPE_NAME="$2"
            shift 2
            ;;
        --config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--refresh-dependencies] [--recipe recipeName] [--config-file path]"
            exit 1
            ;;
    esac
done

temp_init_file=$(mktemp)

REWRITE_CONFIG=""
if [ -n "$CONFIG_FILE" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: config file not found: $CONFIG_FILE"
        exit 1
    fi
    CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
    REWRITE_CONFIG="rewrite { configFile = file(\"$CONFIG_FILE\") }"
fi

# If recipe name was not provided via --recipe, get it from rewrite.yml
if [ -z "$RECIPE_NAME" ]; then
    if [ ! -f "rewrite.yml" ]; then
        echo "Error: rewrite.yml file not found in current directory"
        exit 1
    fi
    
    RECIPE_NAME=$(grep "^name:" rewrite.yml | sed 's/name: *//')
    if [ -z "$RECIPE_NAME" ]; then
        echo "Error: Could not find recipe name in rewrite.yml"
        exit 1
    fi
fi

echo "Running recipe: $RECIPE_NAME"

cat > "$temp_init_file" <<EOF
initscript {
    repositories {
        mavenLocal()
        maven { url "https://plugins.gradle.org/m2" }
        mavenCentral()
    }
    dependencies {
        // 7.40.0 and 7.41.0 depend on rewrite-bom 8.91.0, which is not in Maven Central
        classpath("org.openrewrite:plugin:7.39.0")
    }
}

rootProject {
    plugins.apply(org.openrewrite.gradle.RewritePlugin)
    repositories {
        mavenLocal()
        mavenCentral()
    }
    dependencies {
        rewrite("org.openrewrite:rewrite-java:latest.release")
    }
    $REWRITE_CONFIG
}
EOF

LOG_FILE="/var/tmp/openrewrite-$(date +%Y%m%d-%H%M%S).log"
echo "Logging output to: $LOG_FILE"

./gradlew --info ${REFRESH_DEPS} rewriteRun --init-script "$temp_init_file" \
    -Drewrite.activeRecipe="$RECIPE_NAME" \
    -Dorg.gradle.jvmargs=-Xmx8G --stacktrace > "$LOG_FILE" 2> >(tee -a "$LOG_FILE" >&2)
