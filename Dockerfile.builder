# ----- VAIHE 1: Rakennusympäristö (ARMv6hf Build) -----
# Käytetään Balenan RPi Zero W:n (ARMv6hf) Build-imagea.
# Tämä image sisältää kaikki kehitystyökalut, mikä ratkaisee autoreconf-virheen.
FROM balenalib/armv6hf-debian:bullseye-build AS builder 

ENV DEBIAN_FRONTEND=noninteractive
ARG PACKAGE_VERSION=0.0.0-local

# Poistettiin turhat asennukset (build-essential, autoconf jne.), 
# koska ne ovat jo 'build'-imagessa.
RUN apt-get update && apt-get install -y \
    git \
    libpopt-dev \
    libconfig-dev \
    libasound2-dev \
    libssl-dev \
    libavahi-client-dev \
    libsndfile1-dev \
    libsoxr-dev \
    libdaemon-dev \
    libnss-mdns \
    xmltoman \
    libpulse-dev \
    libplist-dev \
    libsodium-dev \
    libgcrypt-dev \
    libavutil-dev \
    libavcodec-dev \
    libavformat-dev \
    ruby \
    rubygems \
    && gem install fpm \
    && apt-get clean

# Kopioidaan kaikki lähdekoodi kontin sisään
WORKDIR /build
COPY . .

# ----- VAIHE 2: Kääntäminen -----

# Tämä komento toimii nyt Build-imagessa
RUN autoreconf -i -f

# Ajetaan configure-skripti (AirPlay 2 ja PulseAudio)
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
    --with-pa \
    --with-airplay-2

# Käännetään ohjelmisto
RUN make -j$(nproc)

# ----- VAIHE 3: Paketointi -----

RUN mkdir -p /build/staging
RUN make install DESTDIR=/build/staging

# Käytetään FPM:ää .deb-paketin luomiseen (armhf on Debian-termi ARMv6/v7:lle)
RUN fpm -s dir -t deb \
    -n shairport-sync \
    -v ${PACKAGE_VERSION} \
    -a armhf \
    -C /build/staging \
    --description "Shairport Sync - AirPlay 2 audio player" \
    --license "MIT" \
    --url "https://github.com/mikebrady/shairport-sync" \
    --depends libasound2 \
    --depends libavahi-client3 \
    --depends libconfig9 \
    --depends libdaemon0 \
    --depends libpopt0 \
    --depends libsoxr0 \
    --depends libssl1.1 \
    --depends adduser \
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
