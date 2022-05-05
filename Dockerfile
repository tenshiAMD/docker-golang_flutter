ARG GOLANG_IMAGE
ARG SWIFTLINT_IMAGE

FROM ${SWIFTLINT_IMAGE} AS builder
FROM ${GOLANG_IMAGE}

# ------------------------------------------------------
# --- Install required tools
# ------------------------------------------------------

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    wget \
    gnupg2 \
    sudo

# Required for OpenJDK 8 on Debian 10
RUN wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
RUN add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/

RUN apt-get update -qq && \
    apt-cache search openjdk

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    adoptopenjdk-8-hotspot \
    expect \
    git \
    curl \
    unzip \
    lcov \
    git-core \
    emacs-nox \
    screen \
    libstdc++6 \
    lib32stdc++6 \
    software-properties-common \
    build-essential \
    ruby-full \
    grep \
    protobuf-compiler \
    libprotobuf-dev \
    libprotoc-dev \
    mingw-w64 \
    python3-pip && \
    apt-get clean

RUN pip3 install awscli --upgrade

# ------------------------------------------------------
# --- Download Android SDK tools into $ANDROID_HOME
# ------------------------------------------------------

ENV ANDROID_HOME /opt/android-sdk-linux
ENV ANDROID_SDK_ROOT $ANDROID_HOME
# Version found at https://developer.android.com/studio
ENV ANDROID_SDK_TOOLS_VERSION 4333796

RUN cd /opt && \
    wget -q https://dl.google.com/android/repository/sdk-tools-linux-$ANDROID_SDK_TOOLS_VERSION.zip -O android-sdk-tools.zip && \
    unzip -q android-sdk-tools.zip -d ${ANDROID_HOME} && \
    rm android-sdk-tools.zip

ENV PATH=$PATH:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/bin

RUN yes | sdkmanager --licenses

RUN sdkmanager platform-tools "platforms;android-15"

# ------------------------------------------------------
# --- Flutter setup
# ------------------------------------------------------

WORKDIR /

ARG FLUTTER_VERSION=master
RUN git clone --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git && \
    /flutter/bin/flutter doctor && \
    apt autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/flutter/bin/cache/dart-sdk/bin:/flutter/bin

# ------------------------------------------------------
# --- Protobuf setup
# ------------------------------------------------------

RUN cd /opt \
    && git clone https://github.com/grpc-ecosystem/grpc-gateway.git

ENV PATH=$PATH:/root/.pub-cache/bin

RUN flutter pub global activate protoc_plugin

VOLUME ["/opt/android-sdk-linux"]

# Pull the latest from Flutter
ONBUILD RUN cd /flutter && \
    git checkout master && \
    git pull origin master

# Install Swift
ARG SWIFT_VERSION=5.5.3
RUN cd /opt/ && \
    apt-get update -qq && \
    apt-get -y install libncurses5 clang libcurl4 libpython2.7 libpython2.7-dev && \
    wget https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu1804/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu18.04.tar.gz && \
    tar -xzf swift-${SWIFT_VERSION}-RELEASE-ubuntu18.04.tar.gz --no-same-owner && \
    mv swift-${SWIFT_VERSION}-RELEASE-ubuntu18.04 /opt/swift && \
    ln -s /opt/swift/usr/bin/swift /usr/bin/swift && \
    swift --version

# Install SwiftLint
COPY --from=builder /usr/bin/swiftlint /usr/bin
RUN swiftlint version

# ------------------------------------------------------
# --- Download Android NDK into $ANDROID_NDK_HOME
# ------------------------------------------------------

ENV ANDROID_NDK_HOME /opt/android-ndk-linux
ENV ANDROID_NDK_VERSION android-ndk-r21d

RUN cd /opt && \
    wget -q https://dl.google.com/android/repository/${ANDROID_NDK_VERSION}-linux-x86_64.zip -O android-ndk.zip

RUN cd /opt && \
    unzip -q android-ndk.zip && \
    mv ${ANDROID_NDK_VERSION} ${ANDROID_NDK_HOME} && \
    rm android-ndk.zip

LABEL maintainer="Angel Aviel Domaoan <dev.tenshiamd@gmail.com>"
