The best available desktop app for Facebook Messenger. Created for [elementary OS](https://elementary.io).

## Getting started

1. Download the repository and all necessary dependencies. Enter the terminal and type:

  ```
  git clone https://github.com/aprilis/messenger
  sudo apt install elementary-sdk libwebkit2gtk-4.0-dev libunity-dev libsoup2.4-dev
  sudo apt build-dep plank
  ```

2. Build a modified version of Plank.

  ```
  cd messenger/plank
  ./autogen.sh
  make
  sudo make install
  killall plank    #this will restart plank
  cd ..
  ```

3. Build the app.

  ```
  mkdir build
  cd build
  cmake ..
  make
  sudo make install
  ```
