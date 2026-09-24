# Replay Manager

A plugin for the [Ballest plugin manager](https://github.com/AnythingGoes-ballest/ballest-plugin-manager): proper
controls for watching replays in Ballest of Them All.

```
[pause]  ====o=================  0:12.345 / 0:45.678   speed [1x v]   camera [default v]   [v]
distance  ====o=====  375   [x] see through objects        (opened with the arrow on the right)
```

- **The real length** of the replay from the start (the recorded duration), so the whole run can be scrubbed straight
  away, whoever's replay it is.
- **Pause and play**, also with Space.
- **Speed** from .1x to 5x. At the end of the replay it starts again.
- **Scrubbing**: drag the bar to any point.
- **Cameras**: the game's default, follow 3D (a chase camera behind the ball along its direction of travel, turning
  smoothly), and a free camera (WASD, E/Q up and down, Shift faster, hold the right mouse button to look).
- **The arrow** at the end of the bar opens a second row with the camera options below, and closes it again. Whether
  it's open is saved.
- **Distance**: how far the camera stays from the ball, 150 to 1500 units (the game's own is 375), for the default and
  follow 3D cameras. Saved.
- **See through objects**: anything between the camera and the ball turns to glass while it's in the way, instead of
  the camera being pushed in close. Saved.

## Install

In the game: footer **plugins** > **browse** > Replay Manager > **install**. Needs the plugin manager
host 0.9.0 or newer.

## How it works

`main.as` uses the host's `Replay` API (playback time, the recorded length, seeking, camera modes) and draws its bar
with the `UI` window API. The game's replay has no pause or rate of its own, so pause and speed are driven by
seeking: while paused or not at 1x, the plugin keeps its own clock and seeks to it every frame.

## License

MIT
