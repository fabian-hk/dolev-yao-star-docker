FROM lscr.io/linuxserver/code-server:4.133.0

RUN apt-get update && apt-get install -y opam libgmp-dev pkg-config python3-pip python3-venv \
	&& rm -rf /var/lib/apt/lists/*

# Configure code-server extensions
RUN /app/code-server/bin/code-server \
	--install-extension fstarlang.fstar-vscode-assistant \
	--extensions-dir /config/extensions \
	--user-data-dir /config/data

RUN mkdir -p /config/data/Machine && cat > /config/data/Machine/settings.json <<'EOF'
{
	"fstarVSCodeAssistant.verifyOnOpen": true,
	"security.workspace.trust.enabled": false,
	"git.openRepositoryInParentFolders": "always"
}
EOF

# Setup user and permissions

RUN useradd -m -u 1000 -s /bin/bash user

RUN chown -R user:user /config

USER user

ENV HOME=/home/user

# Install F*
# Everything happens in one layer so the opam caches and build/source
# directories can be deleted at the end (saves ~4GB in the final image).
RUN opam init -y \
	&& opam switch create fstar 4.14.2 \
	&& eval $(opam env --switch=fstar) \
	&& opam pin add -y fstar "git+https://github.com/FStarLang/FStar.git#0cbbc9bd61f64977cc534977a858e9291eab69cc" \
	&& opam install -y curly \
	&& opam clean --all-switches --download-cache --logs --repo-cache \
	&& rm -rf /home/user/.opam/fstar/.opam-switch/build \
		/home/user/.opam/fstar/.opam-switch/sources

WORKDIR /home/user
RUN mkdir workspace

# Install Z3
# Build and clean up in one layer so only the binary ends up in the image.
RUN git clone --depth 1 --branch z3-4.15.3 https://github.com/Z3Prover/z3.git \
	&& cd z3 \
	&& python3 scripts/mk_make.py \
	&& make -C build -j"$(nproc)" \
	&& cp build/z3 /home/user/.opam/fstar/bin/z3-4.15.3 \
	&& cd /home/user \
	&& rm -rf z3

# Set environment variables for F* and DY Star
RUN cat >> /home/user/.bashrc <<'EOF'

export PATH="/home/user/.opam/fstar/bin:$PATH"
export COMPARSE_HOME="/home/user/comparse"
export DY_HOME="/home/user/dolev-yao-star-extrinsic"
export DY_WEB="/home/user/dolev-yao-star-preliminary-web"

dystartools() {
  ( . /home/user/dolev-yao-star-tools/venv/bin/activate \
    && OPEN_VIEWER=false /home/user/dolev-yao-star-tools/dystar_tool.py vis $@ -n "")
}
EOF

# Set up DY*
WORKDIR /home/user
RUN git clone https://github.com/TWal/comparse.git
RUN git clone https://github.com/REPROSEC/dolev-yao-star-extrinsic.git
RUN git clone https://github.com/fabian-hk/dolev-yao-star-tools.git

ENV PATH=/home/user/.opam/fstar/bin:$PATH
ENV COMPARSE_HOME=/home/user/comparse
ENV DY_HOME=/home/user/dolev-yao-star-extrinsic

# Build Comparse
WORKDIR /home/user/comparse
RUN make -j 12

# Build DY*
WORKDIR /home/user/dolev-yao-star-extrinsic
RUN git checkout fabian-hk/development
RUN make -j 12

# Include and build DY* preliminary Web
RUN mkdir -p /home/user/dolev-yao-star-preliminary-web
COPY . /home/user/dolev-yao-star-preliminary-web
WORKDIR /home/user/dolev-yao-star-preliminary-web
RUN make -j 12

# Setup DY* Tools
WORKDIR /home/user/dolev-yao-star-tools
RUN python3 -m venv venv
RUN . venv/bin/activate && pip install --no-cache-dir -r requirements.txt
