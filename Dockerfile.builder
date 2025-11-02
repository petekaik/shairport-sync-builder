# ----- VAIHE 1: Rakennusympäristö -----
FROM debian:bullseye AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG PACKAGE_VERSION=0.0.0-local

# Asennetaan shairport-syncin KAIKKI rakennusaikaiset riippuvuudet.
# TÄHÄN LISÄTTY PYYTÄMÄSI KIRJASTOT
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    libpopt-dev \
    libconfig-dev \
    libasound2-dev \
    libssl-dev \
    libavahi-client-dev \
    libsndfile1-dev \
    libsoxr-dev \
    libdaemon-dev \
    libnss-mdns \
    # PULSEAUDIO JA AIRPLAY2
    xmltoman \
    libpulse-dev \
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    libavutil-dev \
    libavcodec-dev \
    libavformat-dev \
    # FPM:n riippuvuudet
    ruby \
    rubygems \
    && apt-get clean

# Asennetaan FPM (Effing Package Management)
RUN gem install fpm

# Kopioidaan kaikki lähdekoodi kontin sisään
WORKDIR /build
COPY . .

# ----- VAIHE 2: Kääntäminen -----

RUN autoreconf -i -f

# Ajetaan configure-skripti
# TÄHÄN LISÄTTY --with-airplay-2 ja --with-pa
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --with-alsa \
    --with-avahi \
    --with-ssl=openssl \
    --with-metadata \
    --with-soxr \
    --with-sndfile \
    --with-systemd \
    --with-pi-extras \
    # PULSEAUDIO JA AIRPLAY2 OPTIOT
    --with-pa \
    --with-airplay-2

# Käännetään ohjelmisto
RUN make -j$(nproc)

# ----- VAIHE 3: Paketointi -----

RUN mkdir -p /build/staging
RUN make install DESTDIR=/build/staging

# Käytetään FPM:ää .deb-paketin luomiseen
# LISÄTTY UUDET AJONAIKAISET RIIPPUVUUDET
RUN fpm -s dir -t deb \
    -n shairport-sync \
    -v ${PACKAGE_VERSION} \
    -a armhf \
    -C /build/staging \
    --description "Shairport Sync - AirPlay 2 audio player" \
    --license "MIT" \
    --url "https://github.com/mikebrady/shairport-sync" \
    # Perusriippuvuudet
    --depends libasound2 \
    --depends libavahi-client3 \
    --depends libconfig9 \
    --depends libdaemon0 \
    --depends libpopt0 \
    --depends libsoxr0 \
    --depends libssl1.1 \
    --depends adduser \
    # PulseAudio ja Airplay2 riippuvuudet
    --depends libpulse0 \
    --depends libplist3 \
    --depends libsodium23 \
    --depends libgcrypt20 \
    --depends libavutil56 \
    --depends libavcodec58 \
    --depends libavformat58 \
    -p /artifacts \
    .

# ----- VAIHE 4: Lopputulos -----
FROM scratch
COPY --from=builder /artifacts /artifacts
CMD ["/bin/true"]
