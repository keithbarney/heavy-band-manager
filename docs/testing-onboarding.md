# Onboarding simulator preview

Run `bash scripts/preview-onboarding.sh` to build and open **Onboarding Test**.
Use `SIMULATOR_UDID=<device UUID>` to select another booted simulator.
The build uses a separate app identifier and simulator-only Debug compilation flag.
Normal Debug and Release builds continue to use the real sign-in flow.

The preview menu at the top also offers **Settings: Manual** and **Settings: Automatic**.
These show sample connected-calendar data so the two layouts can be compared without granting
calendar permission. Choose **Restart** to return to the onboarding test, which uses real simulator permissions.

1. Tap **Create a Band**, enter a band name, and tap **Continue**.
2. Enter your name and instrument, then tap **Continue**.
3. **Automatic** is selected initially. **Get Started** stays disabled until calendar access is connected.
4. Choose **Manual**. Connect your calendar, then choose days and hours. **Get Started** stays disabled until calendar access is granted and at least one day and a valid start/end time are selected. Calendar events do not determine Manual availability.
5. Open **Settings**. My Availability should show **Manual** and reopening it should retain your hours.
6. Tap **Restart** at the top to repeat. Try **Automatic → Connect my calendar → Get Started**.
7. Automatic should show **Automatic** in Settings after calendar permission is granted. There is no skip option during onboarding.
8. Both Settings previews show a practice calendar and **Refresh practice events**, with no opt-out toggle. Scheduled practices are always added when access is available.

To exercise the invite entry path, enter **TEST123** and submit with the keyboard.
This uses a sample band; it does not validate a real invitation or simulate other members.

Sign-in and server writes are bypassed. Profile and availability choices last for the current run;
Restart or relaunch starts over. Photo and logo uploads are not saved. Calendar access uses the real
simulator permission prompt and reads simulator events locally. Restart does not reset iOS permissions.
