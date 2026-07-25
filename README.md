# Image Optimizer

[![Build Status](https://github.com/GijsGoudzwaard/Image-Optimizer/actions/workflows/pipelines.yml/badge.svg?branch=master)](https://github.com/GijsGoudzwaard/Image-Optimizer/actions/workflows/pipelines.yml) [![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20this%20project-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/imageoptimizer)

Simple lossless image optimizer built with Vala and Gtk.

![Screenshot](data/screenshots/welcome-screen.png)

## Get it from the elementary OS AppCenter!
Image Optimizer, is primarily available from the AppCenter of Elementary OS. Download it from there!

[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.gijsgoudzwaard.image-optimizer)

## Get it from Flathub!
You can get Image Optimizer form Flathub no matter what distribution you're using. Download it or follow the instructions to install it from here!

<a href="https://flathub.org/apps/details/com.github.gijsgoudzwaard.image-optimizer" target="_blank"><img src="https://flathub.org/assets/badges/flathub-badge-i-en.svg" width="160px" alt="Get it from Flathub!"></a>

## Dependencies

Please make sure you have these dependencies first before building.

```
granite-7
gtk4 >= 4.12
glib-2.0
jpegoptim
optipng
```

## Building

Simply clone this repo, then:

Run `meson build` to configure the build environment and run `ninja test` to build and run automated tests

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `com.github.gijsgoudzwaard.image-optimizer`

    sudo ninja install
    com.github.gijsgoudzwaard.image-optimizer

## Support this project

Image Optimizer is free and open source. If you find it useful, you can support
its development with a one-off or recurring donation:

[![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20this%20project-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/imageoptimizer)

Contributions are just as welcome — bug reports, translations and pull requests
all help. See the [issue tracker](https://github.com/GijsGoudzwaard/Image-Optimizer/issues)
to get started.
