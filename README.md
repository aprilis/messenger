The best available desktop app for Facebook Messenger. Created for [elementary OS](https://elementary.io). Inspired by [this mockup](https://github.com/elementary/mockups/blob/master/apps/plank/with-chat-bubble.png). Many thanks to [purple facebook](https://github.com/dequis/purple-facebook)'s authors for creating API to communicate with Messenger service.

## Features

1. Native notifications of incoming messages (including notification badges)
2. Easy access to your conversations via chat bubbles
3. Simple, beautiful interface
4. No useless, Snapchat-like features :)

![alt text](https://raw.githubusercontent.com/aprilis/messenger/master/screenshot.png)

## Getting started

1. Download the repository and all necessary dependencies. Enter the terminal and type:

  ```
  git clone https://github.com/aprilis/messenger
  sudo apt install elementary-sdk libwebkit2gtk-4.0-dev libunity-dev libsoup2.4-dev libnotify-dev libbamf3-dev libwnck-3-dev
  sudo apt build-dep plank
  ```

2. Build a modified version of Plank.

  ```
  cd messenger/plank
  ./autogen.sh
  make
  sudo make install
  sudo ldconfig
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

## Updates

As this app isn't stable yet, updates may occur quite often. To download and install an update, you should open the terminal and navigate to the directory with cloned repository (probably it's named messenger) and type:

  ```
  git pull
  cd build
  sudo make install
  ```

Now you have to restart the app. To do this, open the main window, click the gear icon and select 'Quit'. Now open the main window again - your app is up-to-date!

NOTE: There are new dependencies so you might need to install them (```sudo apt install libnotify-dev```) before building updated source code.
