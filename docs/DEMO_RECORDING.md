# Recording a privacy-safe GrokDesk demo

GrokDesk includes a recording helper that starts the app with a brand-new,
isolated demo profile. It does not import normal GrokDesk sessions, and the demo
workspace picker uses safe sample names instead of local usernames or absolute
paths.

## Quick start

Package the app if needed:

```bash
./scripts/package-app.sh
```

Start a fresh demo and let macOS ask which window, area, or monitor to record:

```bash
./scripts/record-demo.sh --gif
```

For a GrokDesk window already placed on the secondary monitor:

```bash
./scripts/record-demo.sh --display 2 --duration 45 --gif
```

The source video and optional GIF are written to `dist/demo-recordings/`.
Creating a GIF requires `ffmpeg`; the `.mov` recording does not.

## Suggested 35–45 second flow

1. Select **English** or **简体中文** on the fresh language screen.
2. Click **New chat** and choose one of the safe demo projects.
3. Show the model and effort menu.
4. Enter a non-sensitive sample task, such as:

   > Inspect this sample SwiftUI workspace, summarize the architecture, and
   > propose one small accessibility improvement.

5. Expand **Process** to show Grok Build reasoning, file, command, Skill, Hook,
   and runtime events.
6. Open the context-window indicator or the runtime details panel.
7. Stop the recording from the macOS menu bar.

## Privacy and cleanup

- Every run gets a unique state directory under
  `/Users/Shared/GrokDesk-Recording-<timestamp>`.
- `GROKDESK_SKIP_SESSION_IMPORT=1` prevents importing existing CLI sessions.
- Demo workspace labels and paths are mock presentation values.
- The script never deletes normal or demo data automatically.
- Review the final video before publishing, especially if recording an entire
  display rather than only the GrokDesk window.

The script prints the exact isolated profile directory after recording. Delete
only that directory manually when it is no longer needed.

## Options

Run `./scripts/record-demo.sh --help` for all options. Useful examples:

```bash
# Launch the isolated demo without recording
./scripts/record-demo.sh --prepare-only

# Record the main display for 30 seconds
./scripts/record-demo.sh --display 1 --duration 30

# Use a specific packaged app and output file
./scripts/record-demo.sh \
  --app /Applications/GrokDesk.app \
  --output "$PWD/dist/demo-recordings/launch-demo.mov"
```
