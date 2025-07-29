#! /bin/bash -e

temp_init_file=$(mktemp)

# Init script from: https://docs.openrewrite.org/running-recipes/running-rewrite-on-a-gradle-project-without-modifying-the-build#step-2-create-a-gradle-init-script

if [ ! -f build.gradle ]; then
    echo this must be run in the root directory of a Gradle project
    exit 1
fi

cat > "$temp_init_file" <<EOF
initscript {
    repositories {
        maven { url "https://plugins.gradle.org/m2" }
    }
    dependencies {
        classpath("org.openrewrite:plugin:latest.release")
    }
}

rootProject {
    plugins.apply(org.openrewrite.gradle.RewritePlugin)
    
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

./gradlew rewriteRun --init-script "$temp_init_file" \
    -Drewrite.activeRecipe=org.openrewrite.java.RemoveUnusedImports \
    -Dorg.gradle.jvmargs=-Xmx8G --stacktrace > "$LOG_FILE" 2> >(tee -a "$LOG_FILE" >&2)