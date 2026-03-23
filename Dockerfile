FROM lscr.io/linuxserver/code-server:4.112.0

RUN apt-get update && apt-get install -y opam libgmp-dev pkg-config

# Configure code-server extensions
RUN /app/code-server/bin/code-server \
	--install-extension fstarlang.fstar-vscode-assistant \
	--extensions-dir /config/extensions \
	--user-data-dir /config/data

RUN mkdir -p /config/data/Machine && cat > /config/data/Machine/settings.json <<'EOF'
{
	"fstarVSCodeAssistant.verifyOnOpen": true
}
EOF

# Setup user and permissions

RUN useradd -m -u 1000 -s /bin/bash user

RUN chown -R user:user /config

USER user

ENV HOME=/home/user

# Install F*

RUN opam init -y
RUN opam update
RUN opam switch create fstar 4.14.2
RUN eval $(opam env --switch=fstar) && opam pin add -y fstar "git+https://github.com/FStarLang/FStar.git#0cbbc9bd61f64977cc534977a858e9291eab69cc"

WORKDIR /home/user
RUN mkdir workspace

# Install Z3
RUN git clone https://github.com/Z3Prover/z3.git

WORKDIR /home/user/z3
RUN git checkout z3-4.15.3
RUN python3 scripts/mk_make.py

WORKDIR /home/user/z3/build
RUN make -j 12
RUN cp z3 /home/user/.opam/fstar/bin/z3-4.15.3

# Set environment variables for F* and DY Star
RUN cat >> /home/user/.bashrc <<'EOF'

export PATH="/home/user/.opam/fstar/bin:$PATH"
export COMPARSE_HOME="/home/user/comparse"
export DY_HOME="/home/user/dolev-yao-star-extrinsic"
EOF

# Set up DY Star
WORKDIR /home/user
RUN git clone https://github.com/fabian-hk/comparse.git
RUN git clone https://github.com/REPROSEC/dolev-yao-star-extrinsic.git

ENV PATH=/home/user/.opam/fstar/bin:$PATH
ENV COMPARSE_HOME=/home/user/comparse
ENV DY_HOME=/home/user/dolev-yao-star-extrinsic

# Build Comparse
WORKDIR /home/user/comparse
RUN make -j 12

# Build DY Star
WORKDIR /home/user/dolev-yao-star-extrinsic
RUN make -j 12
