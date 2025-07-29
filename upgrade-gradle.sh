#! /bin/bash

temp_init_file=$(mktemp)
temp_config_file=$(mktemp).yml

# Init script from: https://docs.openrewrite.org/running-recipes/running-rewrite-on-a-gradle-project-without-modifying-the-build#step-2-create-a-gradle-init-script

cat > "$temp_config_file" <<EOF
type: specs.openrewrite.org/v1beta/recipe
name: org.openrewrite.gradle.UpgradeGradle
displayName: Upgrade Gradle Dependencies and Wrapper
description: Replace deprecated Gradle dependencies and update the Gradle wrapper version.
recipeList:
  - org.openrewrite.gradle.ChangeDependencyConfiguration:
      oldConfiguration: "testCompile"
      newConfiguration: "testImplementation"
  - org.openrewrite.gradle.ChangeDependencyConfiguration:
      oldConfiguration: "compile"
      newConfiguration: "api"
  - org.openrewrite.gradle.ChangeDependencyConfiguration:
      oldConfiguration: "testRuntime"
      newConfiguration: "testRuntimeOnly"
  - org.openrewrite.gradle.UpgradeGradleWrapper:
      version: "8.6.4"
EOF

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
    dependencies {
        rewrite("org.openrewrite.recipe:rewrite-gradle:latest.release")
    }

    rewrite {
        configFile = file("$temp_config_file")
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

./gradlew rewriteRun --init-script "$temp_init_file" \
    -Drewrite.activeRecipe=org.openrewrite.gradle.UpgradeGradle \
    -Drewrite.configFile="$temp_config_file" \
    -Dorg.gradle.jvmargs=-Xmx8G --stacktrace

