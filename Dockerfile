# Use the gcloud CLI image as the base
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:debian_component_based

# Switch to root (the base image runs as root by default, but just in case)
USER root

# Install essential packages
RUN apt-get update && apt-get install -y \
    sudo \
    wget \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    git \
    vim \
    python3 \
    python3-venv \
    python3-pip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh

# Install Azure CLI
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" \
        | tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && apt-get install -y azure-cli

# Clone the two GitHub repositories into /opt
RUN git clone https://github.com/aerospike/aerospike-vector /opt/aerospike-vector && \
    git clone https://github.com/aerospike-community/ann-benchmarks /opt/ann-benchmarks

# Set up a Python virtual environment and install requirements
# Adjust the path to your requirements file as needed.
WORKDIR /opt/ann-benchmarks/aerospike
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip && \
    if [ -f ../requirements.txt ]; then pip install -r ../requirements.txt; fi\
    if [ -f requirements.txt ]; then pip install -r requirements.txt; fi


# Install latest version of asvec (pre if pre is latest)
RUN mkdir -p /usr/local/bin && \
    latest_release=$(curl -s https://api.github.com/repos/aerospike/asvec/releases | jq -r '[.[] | select(.prerelease == true)][0]') && \
    echo "latest_release: $latest_release" && \
    if [ -z "$latest_release" ]; then \
        echo "No pre-release version found, using latest release" && \
        latest_release=$(curl -s https://api.github.com/repos/aerospike/asvec/releases/latest); \
    fi && \
    version=$(echo "$latest_release" | jq -r .tag_name) && \
    echo "version: $version" && \
    echo "Installing asvec version $version..." && \
    download_url=$(echo "$latest_release" | jq -r '.assets[] | select(.name | contains("linux-amd64") and endswith(".deb")) | .browser_download_url') && \
    echo "download_url: $download_url" && \
    curl -L "$download_url" -o asvec.deb && \
    dpkg -i ./asvec.deb 

CMD ["bash"]