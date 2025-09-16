#! /bin/bash -e

REFRESH_DEPS=""
RECIPE_NAME=""

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
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--refresh-dependencies] [--recipe recipeName]"
            exit 1
            ;;
    esac
done

temp_init_file=$(mktemp)

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
    }
    dependencies {
        classpath("org.openrewrite:plugin:latest.release")
        classpath("net.chrisrichardson.openrewrite.recipes:add-imports-from-package:0.1.0-SNAPSHOT")
    }
}

rootProject {
    plugins.apply(org.openrewrite.gradle.RewritePlugin)
    repositories {
        mavenLocal()
    }
    dependencies {
        rewrite("org.openrewrite:rewrite-java:latest.release")
        rewrite("net.chrisrichardson.openrewrite.recipes:add-imports-from-package:0.1.0-SNAPSHOT")
    }


    afterEvaluate {
        if (repositories.isEmpty()) {
            repositories {
                mavenCentral()
            }
        }
    }
}
EOF

LOG_FILE="/var/tmp/openrewrite-$(date +%Y%m%d-%H%M%S).log"
echo "Logging output to: $LOG_FILE"

./gradlew --info ${REFRESH_DEPS} rewriteRun --init-script "$temp_init_file" \
    -Drewrite.activeRecipe="$RECIPE_NAME" \
    -Dorg.gradle.jvmargs=-Xmx8G --stacktrace > "$LOG_FILE" 2> >(tee -a "$LOG_FILE" >&2)
