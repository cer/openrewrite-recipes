#! /bin/bash

tempfile=$(mktemp)

# Init script from: https://docs.openrewrite.org/running-recipes/running-rewrite-on-a-gradle-project-without-modifying-the-build#step-2-create-a-gradle-init-script

cat > $tempfile <<EOF
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
        rewrite("org.openrewrite.recipe:rewrite-spring:latest.release")

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

./gradlew rewriteRun --init-script $tempfile \
    -Drewrite.activeRecipe=org.openrewrite.java.spring.boot2.SpringBoot2JUnit4to5Migration \
    -Dorg.gradle.jvmargs=-Xmx8G

