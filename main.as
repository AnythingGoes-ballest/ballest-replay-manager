// Replay Manager: controls along the bottom of the screen while watching a replay.
//
//   [pause]  ====o=================  0:12.345 / 0:45.678   speed [1x v]   camera [default v]   [v]
//   distance  ====o=====  375           [x] see through objects        (shown with the arrow on the right)
//
// How it drives the game (all through the host's Replay API):
//   * the playhead is Replay::Time(), the game's own playback clock
//   * the length is Replay::Length(), the followed ghost's recorded duration, so the whole run can be scrubbed
//     from the start, whoever's replay it is
//   * the game's replay has no pause or rate, and ignores game speed, so pause and speed are driven by seeking:
//     while paused or not at 1x this plugin keeps its own clock and seeks to it every frame. At 1x the game
//     plays the replay itself.
//   * Space toggles pause while a replay is on screen.
//   * distance is how far the camera stays from the ball, in whole units (the game's own is 375), in the default
//     and follow 3d cameras; see through objects turns anything between the camera and the ball to glass instead of
//     letting the camera be pushed in. Both are saved, and so is whether that row is open.

UI::Window@ window;
UI::Button@ playButton;
UI::Slider@ slider;
UI::Text@ timeText;
UI::Dropdown@ speedBox;
UI::Dropdown@ cameraBox;
UI::Slider@ distanceSlider;
UI::Text@ distanceText;
UI::CheckBox@ seeThroughBox;
UI::Button@ moreButton;
UI::Text@ distanceLabel;
bool expanded = false;                // the camera options row is open

const int MIN_DISTANCE = 150, MAX_DISTANCE = 1500;
int distance = 375;                   // the replay camera's own arm length, measured

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

int Clamp(int d) { return d < MIN_DISTANCE ? MIN_DISTANCE : (d > MAX_DISTANCE ? MAX_DISTANCE : d); }

// The distance and see-through as chosen, to the host and on screen.
void ApplyCamera()
{
    Replay::SetCameraDistance(distance);
    Replay::SetSeeThrough(seeThroughBox.checked);
    distanceText.text = "" + distance;
    if (!distanceSlider.dragging)
        distanceSlider.value = float(distance - MIN_DISTANCE) / float(MAX_DISTANCE - MIN_DISTANCE);
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
    @moreButton = window.AddIconButton("down");

    window.NewRow();
    @distanceLabel = window.AddText("distance", 16);
    @distanceSlider = window.AddSlider(300);
    @distanceText = window.AddText("", 16);
    @seeThroughBox = window.AddCheckBox("see through objects", 16);

    distance = Clamp(int(parseInt(Storage::Get("distance", "375"))));
    seeThroughBox.checked = Storage::Get("seeThrough", "false") == "true";
    expanded = Storage::Get("expanded", "false") == "true";
    ShowMore();
    ApplyCamera();
    Log::Info("replay manager ready");
}

// The camera options row, opened and closed with the arrow at the end of the first row.
void ShowMore()
{
    distanceLabel.visible = expanded;
    distanceSlider.visible = expanded;
    distanceText.visible = expanded;
    seeThroughBox.visible = expanded;
    moreButton.icon = expanded ? "up" : "down";
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
    if (moreButton.Clicked())
    {
        expanded = !expanded;
        ShowMore();
        Storage::Set("expanded", expanded ? "true" : "false");
    }
    if (speedBox.Changed())
    {
        Reanchor(time);
        speedIndex = speedBox.selected;
        Log::Info("speed " + SpeedLabel(speedIndex));
    }
    if (distanceSlider.dragging)
    {
        // Whole units only: the slider snaps to them.
        int d = Clamp(int(MIN_DISTANCE + distanceSlider.value * (MAX_DISTANCE - MIN_DISTANCE) + 0.5f));
        if (d != distance)
        {
            distance = d;
            ApplyCamera();
            Storage::Set("distance", "" + distance);
        }
    }
    if (seeThroughBox.Changed())
    {
        ApplyCamera();
        Storage::Set("seeThrough", seeThroughBox.checked ? "true" : "false");
        Log::Info("see through objects " + (seeThroughBox.checked ? "on" : "off"));
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
