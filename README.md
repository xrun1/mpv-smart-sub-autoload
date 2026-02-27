# mpv-smart-sub-autoload

An mpv script that automatically loads external subtitles by matching episode
numbers rather than requiring identical filenames.

## Example

With a directory containing these files:

    [QYQ][Kanon][DVDRIP][01][AVC_AAC_AC3][E424B079].jp.ass
    [QYQ][Kanon][DVDRIP][02][AVC_AAC][A7E9008C].jp.ass
    [QYQ][Kanon][DVDRIP][03][AVC_AAC][AC13FD66].jp.ass
    [VCB-S&philosophy-raws][Kanon(2006)][BDRIP][01][Hi10P FLAC][1920X1080]_track5_jpn.sup
    [VCB-S&philosophy-raws][Kanon(2006)][BDRIP][02][Hi10P FLAC][1920X1080]_track5_jpn.sup
    [VCB-S&philosophy-raws][Kanon(2006)][BDRIP][03][Hi10P FLAC][1920X1080]_track5_jpn.sup
    01-01.mkv
    01-02.mkv
    01-03.mkv
    ...

When you open `01-01.mkv` in mpv, the script will:

- Look at all the video filenames and detect that the second number is the
  first one to differ between files, so it's probably the episode number

- Do the same checks on subtitle files to detect that the first number is
  probably the episode number

- Since the detected episode number for `01-01.mkv`,
  `[QYQ][Kanon][DVDRIP][01][AVC_AAC_AC3][E424B079].jp.ass` and
  `[VCB-S&philosophy-raws][Kanon(2006)][BDRIP][01][Hi10P FLAC][1920X1080]_track5_jpn.sup`
  are all `01`, add those two subtitles in mpv for the current video; thus
  saving you from either having to rename everything by hand or
  picking files every time an episode starts.

If there's only one video in a folder, then any subtitle in that folder
gets loaded.

## Limitations

- Don't mix multiple shows, or seasons of a same show, in the same folder
- Might fail with very exotic naming schemes

## Installation

Git clone or click **Code** → **Download ZIP** and then extract into your mpv
scripts folder (usually `%APPDATA%\mpv\scripts` or `~/.config/mpv/scripts`).

## Configuration

Create a `smart-sub-autoload.conf` file in your script-opts folder
(usually `%APPDATA%\mpv\script-opts` or `~/.config/mpv/script-opts`)
to change the default options.

To reverse the order in which subtitles are loaded when multiple ones
are found for a video, add the line:

```
auto_select_first_matching_sub=no
```

To limit the search depth in subfolders add the line (default: 1):
```
max_depth=1
```
