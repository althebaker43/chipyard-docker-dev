
FROM ubuntu:18.04 as base
ARG CHIPYARD_HASH

MAINTAINER https://groups.google.com/forum/#!forum/chipyard

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
               curl \
               git \
               sudo \
               ca-certificates \
               keyboard-configuration \
               console-setup

WORKDIR /root

# Install Chipyard and run ubuntu-req.sh to install necessary dependencies
RUN git clone https://github.com/ucb-bar/chipyard.git && \
        cd chipyard && \
        git checkout $CHIPYARD_HASH && \
        ./scripts/ubuntu-req.sh 1>/dev/null && \
        sudo rm -rf /var/lib/apt/lists/*

# Copy RISC-V tools
ENV RISCV="/root/riscv-tools-install"
COPY riscv/* $RISCV/

# Init submodules
RUN cd chipyard && \
        export MAKEFLAGS=-"j $(nproc)" && \
        ./scripts/init-submodules-no-riscv-tools.sh

# Install xterm for UI
RUN apt-get update && apt-get install -y xterm

# Install emacs as main editor
RUN apt-get update && apt-get install -y libxpm-dev libjpeg-dev libgif-dev libtiff-dev gnutls-dev
RUN wget http://mirror.us-midwest-1.nexcess.net/gnu/emacs/emacs-27.2.tar.gz && \
    tar xf emacs-27.2.tar.gz && \
    mkdir emacs-build && cd emacs-build && ../emacs-27.2/configure && \
    make && make install && \
    cd .. && rm -r emacs-27.2.tar.gz emacs-27.2 emacs-build
COPY .emacs .
COPY init.el ./.emacs.d/
COPY elpa/ ./.emacs.d/elpa/

# Set up bloop and metals
RUN mkdir bloop && cd bloop && \
    curl -fL https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz | gzip -d > cs && \
    chmod +x cs && \
    ./cs setup --yes && \
    ./cs install bloop && \
    ./cs install metals
ENV PATH="$PATH:/root/.local/share/coursier/bin:/root/.local/share/metals/bin"

# Include gtkwave
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata
RUN apt-get install -y gtkwave

# Build emulator to download dependencies
COPY sim_compile.patch chipyard/
RUN cd chipyard && patch -p1 < sim_compile.patch && \
    cd sims/verilator && \
    make && \
    make clean

# Update PATH for RISCV toolchain
ENV LD_LIBRARY_PATH="$RISCV/lib"
ENV PATH="$RISCV/bin:$PATH"

# ENTRYPOINT ["chipyard/scripts/entrypoint.sh"]

CMD ["xterm"]
