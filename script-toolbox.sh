#!/bin/bash

# Configuration variables
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-podman}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-quay.io/mhild/rhdh-toolbox}
WORK_DIR=$(pwd)

echo "Using container runtime: $CONTAINER_RUNTIME"
echo "Using container image: $CONTAINER_IMAGE"

# Function to run commands in container
run_in_container() {
  $CONTAINER_RUNTIME run --rm \
    -v "$WORK_DIR:/workspace" \
    -w /workspace \
    -e QUAY_USERNAME="$QUAY_USERNAME" \
    -e QUAY_PASSWORD="$QUAY_PASSWORD" \
    -e QUAY_IMAGE_NAME="$QUAY_IMAGE_NAME" \
    -e QUAY_IMAGE_TAG="$QUAY_IMAGE_TAG" \
    $CONTAINER_IMAGE \
    /bin/bash -c "$1"
}

# Display version information
display_versions() {
  echo "Checking environment versions..."
  run_in_container "echo \"Yarn version: \$(yarn --version)\" && \
  echo \"Node.js version: \$(node --version)\" && \
  echo \"npm version: \$(npm --version)\" && \
  echo \"Backstage CLI version: \$(backstage-cli --version)\" && \
  echo \"Janus CLI version: \$(janus-cli --version)\""
}

# Clone or update repository
prepare_repository() {
  echo "Checking community plugins repository..."
  run_in_container "if [ -d \"community-plugins\" ]; then \
    echo \"Repository already exists, pulling latest changes...\"; \
    cd community-plugins && git pull; \
  else \
    echo \"Cloning the community plugins repository...\"; \
    git clone https://github.com/backstage/community-plugins; \
  fi"
}

# Install dependencies and run tsc
setup_project() {
  echo "Performing Yarn installation and the Typescript compiler check..."
  run_in_container "cd community-plugins/workspaces/todo && \
  pwd && \
  yarn install && \
  yarn tsc"
}

# Export backend plugin
export_backend_plugin() {
  echo "Exporting backend plugin..."
  run_in_container "cd community-plugins/workspaces/todo/plugins/todo-backend && \
  pwd && \
  janus-cli package export-dynamic-plugin"
}

# Export frontend plugin
export_frontend_plugin() {
  echo "Exporting frontend plugin..."
  run_in_container "cd community-plugins/workspaces/todo/plugins/todo && \
  pwd && \
  janus-cli package export-dynamic-plugin"
}

# Login to Quay.io
login_to_quay() {
  echo "Logging in to quay.io as $QUAY_USERNAME..."
  run_in_container "$CONTAINER_RUNTIME login -u=$QUAY_USERNAME -p=$QUAY_PASSWORD quay.io"
}

# Build the container image
# once we have buildah support we can use buildah bud
# use export STORAGE_DRIVER=vfs

build_image() {
  echo "Building the image: $QUAY_USERNAME/$QUAY_IMAGE_NAME:$QUAY_IMAGE_TAG"
  run_in_container "cd community-plugins/workspaces/todo && \
  pwd && \
  janus-cli package package-dynamic-plugins --tag quay.io/$QUAY_USERNAME/$QUAY_IMAGE_NAME:$QUAY_IMAGE_TAG"
}

# Push the container image to quay.io
push_image() {
  echo "Pushing the image: $QUAY_USERNAME/$QUAY_IMAGE_NAME:$QUAY_IMAGE_TAG"
  run_in_container "$CONTAINER_RUNTIME push quay.io/$QUAY_USERNAME/$QUAY_IMAGE_NAME:$QUAY_IMAGE_TAG"
}

export_plugins_to_workspace() {
  echo "Exporting plugins"
  run_in_container "cd community-plugins/workspaces/todo && \
  pwd && \
  janus-cli package package-dynamic-plugins --export-to /workspace"
}

# Main execution
main() {
  display_versions
  prepare_repository
  setup_project
  export_backend_plugin
  export_frontend_plugin
#   login_to_quay
#   build_image
#   push_image
  export_plugins_to_workspace
}

# Run the main function
display_versions
# main
