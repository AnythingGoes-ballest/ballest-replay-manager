// Replay Manager: controls along the bottom of the screen while watching a replay.
//
//   [pause]  ====o=================  0:12.345 / 0:45.678   speed [1x v]   camera [default v]
//
// How it drives the game (all through the host's Replay API):
//   * the playhead is Replay::Time(), the game's own playback clock
//   * the length is Replay::Length(), the followed ghost's recorded duration, so the whole run can be scrubbed
//     from the start, whoever's replay it is
//   * the game's replay has no pause or rate, and ignores game speed, so pause and speed are driven by seeking:
//     while paused or not at 1x this plugin keeps its own clock and seeks to it every frame. At 1x the game
//     plays the replay itself.
//   * Space toggles pause while a replay is on screen.

UI::Window@ window;
UI::Button@ playButton;
UI::Slider@ slider;
UI::Text@ timeText;
UI::Dropdown@ speedBox;
UI::Dropdown@ cameraBox;

const int NORMAL_SPEED = 3;           // index of 1x
int speedIndex = NORMAL_SPEED;
bool paused = false;
bool shown = false;
double anchorTime = 0;                // replay time when the clock was last anchored
double anchorClock = 0;               // host time at that moment
double furthestSeen = 0;              // fallback length for a replay whose record has no duration
double lastSeenReplay = -100;

float Speed(int index)
{
    switch (index)
    {
    case 0: return 0.1f;
    case 1: return 0.25f;
    case 2: return 0.5f;
    case 4: return 2.0f;
    case 5: return 5.0f;
    }
    return 1.0f;
}

string SpeedLabel(int index)
{
    switch (index)
    {
    case 0: return ".1x";
    case 1: return ".25x";
    case 2: return ".5x";
    case 4: return "2x";
    case 5: return "5x";
    }
    return "1x";
}

// Dropdown order matches Replay::Camera (Default, Follow3D, Free).
string CameraLabel(int mode)
{
    switch (mode)
    {
    case Replay::Follow3D: return "follow 3d";
    case Replay::Free: return "free cam";
    }
    return "default";
}

double Min(double a, double b) { return a < b ? a : b; }
double Max(double a, double b) { return a > b ? a : b; }

// m:ss.mmm
string FormatTime(double seconds)
{
    seconds = Max(0, seconds);
    int minutes = int(seconds / 60);
    return minutes + ":" + formatFloat(seconds - minutes * 60, "0", 6, 3);
}

void Main()
{
    @window = UI::CreateWindow();
    window.SetAnchor(0.5f, 1.0f);
    window.SetPivot(0.5f, 1.0f);
    window.SetOffset(0, -40);
    window.visible = false;

    @playButton = window.AddIconButton("pause");
    @slider = window.AddSlider(620);
    @timeText = window.AddText("0:00.000 / 0:00.000", 16);
    window.AddText("speed", 16);
    @speedBox = window.AddDropdown(90);
    for (int i = 0; i < 6; i++)
        speedBox.AddOption(SpeedLabel(i));
    speedBox.selected = NORMAL_SPEED;
    window.AddText("camera", 16);
    @cameraBox = window.AddDropdown(180);
    for (int mode = Replay::Default; mode <= Replay::Free; mode++)
        cameraBox.AddOption(CameraLabel(mode));
    cameraBox.selected = Replay::CameraMode();
    Log::Info("replay manager ready");
}

bool Driving() { return paused || speedIndex != NORMAL_SPEED; }

void Reanchor(double time)
{
    anchorTime = time;
    anchorClock = Host::Time();
}

double DrivenTime()
{
    if (paused)
        return anchorTime;
    return anchorTime + (Host::Time() - anchorClock) * Speed(speedIndex);
}

void Show()
{
    shown = true;
    paused = false;
    speedIndex = NORMAL_SPEED;
    furthestSeen = 0;
    playButton.icon = "pause";
    speedBox.selected = NORMAL_SPEED;
    cameraBox.selected = Replay::CameraMode();
    window.visible = true;
    UI::SetCursorVisible(true);
    Log::Info("replay controls shown");
}

void Hide()
{
    shown = false;
    window.visible = false;
    UI::SetCursorVisible(false);
    Log::Info("replay controls hidden");
}

void Update(float dt)
{
    if (!Replay::IsActive())
    {
        // The replay camera drops out briefly when a replay loops; only hide after a real gap.
        if (shown && Host::Time() - lastSeenReplay > 1.5)
            Hide();
        return;
    }
    lastSeenReplay = Host::Time();
    if (!shown)
        Show();

    double gameTime = Replay::Time();
    furthestSeen = Max(furthestSeen, gameTime);
    double length = Replay::Length();
    bool known = length > 0;
    if (!known)
        length = Max(furthestSeen, 1);
    double time = Driving() ? DrivenTime() : gameTime;

    if (playButton.Clicked() || Input::Pressed(Input::Space))
    {
        Reanchor(time);
        paused = !paused;
        playButton.icon = paused ? "play" : "pause";
        Log::Info(paused ? "paused" : "playing");
    }
    if (speedBox.Changed())
    {
        Reanchor(time);
        speedIndex = speedBox.selected;
        Log::Info("speed " + SpeedLabel(speedIndex));
    }
    if (cameraBox.Changed())
    {
        Replay::SetCameraMode(cameraBox.selected);
        Log::Info("camera " + CameraLabel(cameraBox.selected));
    }

    if (slider.dragging)
    {
        time = slider.value * length;
        Reanchor(time);
        Replay::Seek(time);
    }
    else
    {
        if (Driving())
        {
            time = DrivenTime();
            // At 1x the game restarts a finished replay itself; while this plugin drives playback it has to.
            bool pastEnd = known ? time >= length : time - gameTime > 0.5;
            if (pastEnd && !paused)
            {
                Replay::Restart();
                time = 0;
                Reanchor(0);
                Log::Info("replay finished at " + SpeedLabel(speedIndex) + "; restarted");
            }
            else
            {
                if (known)
                    time = Min(time, length);
                Replay::Seek(time);
            }
        }
        slider.value = float(Min(1.0, time / length));
    }
    timeText.text = FormatTime(time) + " / " + FormatTime(length);
}
