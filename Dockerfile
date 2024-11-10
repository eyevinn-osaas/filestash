FROM node:18-alpine AS builder-frontend
WORKDIR /source
RUN apk add --no-cache git \
  gzip \
  make \
  brotli

COPY . .
RUN npm install --legacy-peer-deps
RUN make build_frontend && cd public && make compress

FROM golang:1.23-bookworm AS builder-backend
WORKDIR /source
COPY --from=builder-frontend /source/ ./
RUN apt-get update > /dev/null && \
    apt-get install -y libvips-dev curl make > /dev/null 2>&1 && \
    apt-get install -y libjpeg-dev libtiff-dev libpng-dev libwebp-dev libraw-dev libheif-dev libgif-dev && \
    make build_init && \
    make build_backend && \
    mkdir -p ./dist/data/state/config/ && \
    cp config/config-osc.json ./dist/data/state/config/config.json

FROM debian:stable-slim
WORKDIR /app
COPY --from=builder-backend /source/dist/ ./
COPY --from=builder-backend /source/server/.assets/emacs/htmlize.el /usr/share/emacs/site-lisp/htmlize.el
COPY --from=builder-backend /source/server/.assets/emacs/ox-gfm.el  /usr/share/emacs/site-lisp/ox-gfm.el
RUN apt-get update
RUN apt-get install -y --no-install-recommends apt-utils \
      curl emacs-nox ffmpeg zip poppler-utils libheif1
RUN apt-get install -y wget perl > /dev/null && \
    export CTAN_REPO="http://mirror.las.iastate.edu/tex-archive/systems/texlive/tlnet" && \
    curl -sL "https://yihui.name/gh/tinytex/tools/install-unx.sh" | sh && \
    mv ~/.TinyTeX /usr/share/tinytex && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install wasy && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install ulem && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install marvosym && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install wasysym && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install xcolor && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install listings && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install parskip && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install float && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install wrapfig && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install sectsty && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install capt-of && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install epstopdf-pkg && \
    /usr/share/tinytex/bin/$(uname -m)-linux/tlmgr install cm-super && \
    ln -s /usr/share/tinytex/bin/$(uname -m)-linux/pdflatex /usr/local/bin/pdflatex && \
    apt-get purge -y --auto-remove perl wget && \
    # Cleanup
    find /usr/share/ -name 'doc' | xargs rm -rf && \
    find /usr/share/emacs -name '*.pbm' | xargs rm -f && \
    find /usr/share/emacs -name '*.png' | xargs rm -f && \
    find /usr/share/emacs -name '*.xpm' | xargs rm -f

RUN useradd filestash && \
    chown -R filestash:filestash /app/ && \
    find /app/data/ -type d -exec chmod 770 {} \; && \
    find /app/data/ -type f -exec chmod 760 {} \; && \
    chmod 730 /app/filestash && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

USER filestash
EXPOSE 8080
ENTRYPOINT [ "/app/entrypoint.sh" ]
    