<img width="333" height="645" alt="Screenshot 2026-11-23 at 11 41 22 AM" src="https://github.com/user-attachments/assets/ba88736e-4aa7-4c9b-b5a1-ed1ffcbcc042" />



# Routines

Routines is a small checklist app for the Mac. It shows your work routines in a floating window, like Stickies.

- The app shows the routine that matches the time of day.
- Some items show only on some days of the week.
- Habits reset each day.
- Obligations stay on the list until you check them off.
- A Top 5 card holds your priorities for the week.

Routines needs macOS 14 (Sonoma) or later.

## Install

### Option 1: Download the app

1. Download [Routines-macOS.zip](https://github.com/jenniferlynparsons/routines/releases/latest/download/Routines-macOS.zip) from the latest release.
2. Double-click the zip file to unzip it.
3. Drag `Routines.app` into your Applications folder.
4. Open Routines.

The app does not have an Apple signature, so macOS blocks it the first time. To open it:

1. In the warning, click **Done**.
2. Open **System Settings** and select **Privacy & Security**.
3. Scroll down to the message about Routines.
4. Click **Open Anyway**.
5. Enter your Mac password if macOS asks for it.

You do this one time only.

### Option 2: Build from source

You need the Apple Command Line Tools. You do not need the full Xcode app.

1. Open Terminal.
2. If you do not have the Command Line Tools, run `xcode-select --install`.
3. Clone this repository:

   ```
   git clone https://github.com/jenniferlynparsons/routines.git
   ```

4. Go into the folder:

   ```
   cd routines
   ```

5. Build and install the app:

   ```
   bash build.sh --install
   ```

The script copies `Routines.app` to your Applications folder and opens it. Run the same command again after you change the code.

### First launch

macOS can ask if Routines can use your Documents folder. Click **Allow**. The app keeps your checklist in that folder.

## Use the app

- **Check off an item:** click the item. Click it again to undo.
- **Open or close a section:** click the section name.
- **Float the window:** click the pin at the top right. The window then stays above other windows. Click the pin again to stop.
- **Edit your routines:** click the pencil at the top right, or press ⌘E. Your routines file opens in TextEdit.
- **Show your files in Finder:** press ⇧⌘E.
- **Change the colors:** click the palette at the top right, or press ⌘,.

### Top 5 This Week

The Top 5 card is at the top of the window. Type up to five priorities for the week into it. The priorities stay on the card from Monday to Sunday.

- To mark a priority as done, click its circle.
- To edit a finished priority, click its circle to uncheck it. Then edit the text.

## How the app chooses what to show

- **Sections start at set times.** The current section is the one whose start time passed most recently. A dot marks it, and it opens automatically.
- **Earlier sections stay open** while they have unchecked items.
- **Later sections stay closed** until you open them or their start time arrives.
- **Habits reset at midnight.** An unchecked habit does not move to the next day.
- **Obligations carry over.** An obligation that you did not check off moves to the top of the next morning. A label shows the day it came from, for example "from Fri". The app does this even if it was closed on that day.
- **Priorities last all week.** On Monday, the app removes finished priorities. Unfinished priorities move to the top of the card for the new week.
- **Empty sections do not show.** If a section has no items for today, the app hides it.

## Write your routines

Your routines are in a plain text file:

```
~/Documents/Routines/routines.txt
```

The app makes a sample file the first time it opens. Edit the file, save it, and go back to the app. The app reads the file again.

Example:

```
# Morning @ 8:00
Check email
Choose this week's Top 5 [Mon]

# Afternoon @ 12:00
Submit timesheet [Fri, carry]

# End of day @ 16:00
Write down tomorrow's first task
```

| Write this | Result |
|---|---|
| `# Morning @ 8:00` | Starts a section named Morning at 8:00. You can also write `16:00`, `4pm`, or `4:30 pm`. |
| A line of text | Adds an item. The item shows Monday to Friday. |
| `[Fri]` or `[Mon, Wed]` | Shows the item only on those days. |
| `[daily]` | Shows the item every day. |
| `[weekends]` | Shows the item on Saturday and Sunday. |
| `[weekdays]` | Shows the item Monday to Friday. |
| `[carry]` | Makes the item an obligation. You can combine it with days, for example `[Fri, carry]`. |
| `// note` | Adds a comment. The app does not show comments. |

The app identifies an item by its section and its text. If you change the text, the app sees a new item. A check mark on the old text does not move to the new text.

## Your data

The app keeps all of your data in `~/Documents/Routines/`:

- `routines.txt` is your list of routines. You edit this file.
- `state.json` holds your check marks, obligations, and Top 5. The app edits this file. Do not edit it.

To back up your data, copy this folder.

## Change the colors

1. Click the palette button at the top right, or press ⌘,.
2. Click a palette in the list.

The window changes color at once. The app remembers your choice.

### Use your own colors

1. In the Custom palette field, type five hex codes, for example `#93b7be #554348 #d4f5f5 #8c9a9e #747578`. You can also paste a link from coolors.co.
2. Click **Use These Colors**.

The app gives each color a job:

| Color | Light mode | Dark mode |
|---|---|---|
| The darkest color | Text | Background tint |
| The lightest color | Background tint | Text |
| The most colorful of the other three | Check circles, progress ring, badges | Check circles, progress ring, badges |
| The two remaining colors | Times, counts, and finished items | Times, counts, and finished items |

If text or check marks will be hard to read, the Settings window shows a warning.

### For developers

The preset palettes and the rules that give each color a job are in `Sources/Routines/Theme.swift`.

## Take screenshots

Demo mode shows sample routines. It does not read or change your own data.

1. Quit Routines.
2. In Terminal, run:

   ```
   open /Applications/Routines.app --args --demo
   ```

3. Press ⇧⌘4, then press Space.
4. Click the Routines window. macOS saves the screenshot to your Desktop.
5. Quit Routines. The demo data goes away.

## Make a release

The Release workflow builds the app and attaches it to a GitHub release. The app runs on Apple silicon and Intel Macs. To start the workflow, do one of these:

- Push a tag that starts with `v`, for example `v1.0.0`.
- On the **Actions** tab, select **Release**, then click **Run workflow**. Type a version, for example `v1.0.0`.

## Uninstall

1. Quit Routines.
2. Move `Routines.app` from Applications to the Trash.
3. To also remove your data, move `~/Documents/Routines` to the Trash.
