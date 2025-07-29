#! /bin/bash -e

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <oldFullyQualifiedTypeName> <newFullyQualifiedTypeName>"
    echo "Example: $0 com.example.OldClass com.example.NewClass"
    exit 1
fi

OLD_TYPE="$1"
NEW_TYPE="$2"

temp_init_file=$(mktemp)
temp_config_file=$(mktemp).yml

# Init script from: https://docs.openrewrite.org/running-recipes/running-rewrite-on-a-gradle-project-without-modifying-the-build#step-2-create-a-gradle-init-script

if [ -f rewrite.yml ]; then
    echo rewrite.yml exists - please remove
    exit 1
fi

cat > "rewrite.yml" <<EOF
type: specs.openrewrite.org/v1beta/recipe
name: net.chrisrichardson.recipes.ChangeType
displayName: Change type
description: Change a given type to another.
recipeList:
  - org.openrewrite.java.ChangeType:
      oldFullyQualifiedTypeName: $OLD_TYPE
      newFullyQualifiedTypeName: $NEW_TYPE
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
        rewrite("org.openrewrite:rewrite-java:latest.release")
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
    -Drewrite.activeRecipe=net.chrisrichardson.recipes.ChangeType \
    -Dorg.gradle.jvmargs=-Xmx8G --stacktrace

rm rewrite.yml
