# Image Optimzer
[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.gijsgoudzwaard.image-optimizer)

A simple image optimizer build for [Elementary OS](https://elementary.io).

![Screenshot](data/screenshots/welcome-screen.png)

## Donations
Do you like the app? Would you like to support its development? Feel free to donate

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=PH9T46XBY7FTC)

## Dependencies

Please make sure you have these dependencies first before building.

```
granite
gtk+-3.0
```

## Building

Simply clone this repo, then:

```
$ mkdir build && cd build
$ cmake ..
$ make && sudo make install
$ com.github.gijsgoudzwaard.image-optimizer
```