A teleprompter that hangs from your MacBook's notch, right under the camera.

**Download `EyeLine.dmg`**, open it and drag EyeLine to Applications.

### First launch
This build is not notarized by Apple yet, so macOS will block it the first time:

1. Open EyeLine from Applications. macOS says it can't verify the developer. Click **Done**.
2. Open **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to EyeLine.
3. Allow microphone access when asked (it powers the voice glow; nothing is recorded).

Or in Terminal: `xattr -dr com.apple.quarantine /Applications/EyeLine.app`

Requires macOS 14 Sonoma or later. Universal: Apple silicon and Intel.
