#! /bin/bash -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REFRESH_DEPS=""
if [ "$1" = "--refresh-dependencies" ]; then
    REFRESH_DEPS="--refresh-dependencies"
    shift
fi

# Check if at least 2 arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <targetPackage> <fullyQualifiedClassName1> [<fullyQualifiedClassName2> ...]"
    echo "Example: $0 com.example.newpackage com.example.oldpackage.Class1 com.example.oldpackage.Class2"
    exit 1
fi

TARGET_PACKAGE="$1"
shift # Remove the first argument, leaving only the class names

# Init script from: https://docs.openrewrite.org/running-recipes/running-rewrite-on-a-gradle-project-without-modifying-the-build#step-2-create-a-gradle-init-script

if [ -f rewrite.yml ]; then
    echo rewrite.yml exists - please remove
    exit 1
fi

if [ ! -f build.gradle ]; then
    echo this must be run in the root directory of a Gradle project
    exit 1
fi

# Start building the recipe configuration
cat > "rewrite.yml" <<EOF
type: specs.openrewrite.org/v1beta/recipe
name: net.chrisrichardson.recipes.MoveClasses
displayName: Move classes to target package
description: Move multiple classes to a target package.
recipeList:
EOF

# Add a ChangeType recipe for each class
for OLD_CLASS in "$@"; do
    # Extract the simple class name from the fully qualified name
    SIMPLE_CLASS_NAME="${OLD_CLASS##*.}"
    NEW_CLASS="${TARGET_PACKAGE}.${SIMPLE_CLASS_NAME}"
    
    cat >> "rewrite.yml" <<EOF
  - org.openrewrite.java.ChangeType:
      oldFullyQualifiedTypeName: $OLD_CLASS
      newFullyQualifiedTypeName: $NEW_CLASS
EOF
done

cat >> rewrite.yml <<EOF
  - net.chrisrichardson.openrewrite.recipes.addimportsfrompackage.AddImportsFromPackageRecipe:
      classMapping:
EOF

for OLD_CLASS in "$@"; do
    SIMPLE_CLASS_NAME="${OLD_CLASS##*.}"
    NEW_CLASS="${TARGET_PACKAGE}.${SIMPLE_CLASS_NAME}"
    
    cat >> "rewrite.yml" <<EOF
        $OLD_CLASS: $NEW_CLASS
EOF
done

cat >> rewrite.yml <<EOF
  - org.openrewrite.java.ShortenFullyQualifiedTypeReferences
  - org.openrewrite.java.RemoveUnusedImports
EOF

$DIR/_run-rewrite-recipe.sh $REFRESH_DEPS

echo NOT rm rewrite.yml