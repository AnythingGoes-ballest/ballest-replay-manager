# Replay Manager

A plugin for the [Ballest plugin manager](https://github.com/AnythingGoes-ballest/ballest-plugin-manager): proper
controls for watching replays in Ballest of Them All.

```
[pause]  ====o=================  0:12.345 / 0:45.678   speed [1x v]   camera [default v]
```

- **The real length** of the replay from the start (the recorded duration), so the whole run can be scrubbed straight
  away, whoever's replay it is.
- **Pause and play**, also with Space.
- **Speed** from .1x to 5x. At the end of the replay it starts again.
- **Scrubbing**: drag the bar to any point.
- **Cameras**: the game's default, follow 3D (the camera turns with the ball), and a free camera (WASD, E/Q up and
  down, Shift faster, hold the right mouse button to look).

## Install

In the game: footer **plugins** > **open** > **browse** > Replay Manager > **install**. Needs the plugin manager
host 0.3.0 or newer.

## How it works

`main.as` uses the host's `Replay` API (playback time, the recorded length, seeking, camera modes) and draws its bar
with the `UI` window API. The game's replay has no pause or rate of its own, so pause and speed are driven by
seeking: while paused or not at 1x, the plugin keeps its own clock and seeks to it every frame.

## License

MIT
