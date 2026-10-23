#!/usr/bin/env python3
"""Idempotently patch the platform folders created by `flutter create .`
with what background audio, media controls and Android TV need."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent

ANDROID_PERMS = """
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-feature android:name="android.software.leanback" android:required="false"/>
    <uses-feature android:name="android.hardware.touchscreen" android:required="false"/>"""

ANDROID_SERVICES = """
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
    """


def patch_android():
    f = root / "android/app/src/main/AndroidManifest.xml"
    if not f.exists():
        return
    s = f.read_text()
    if "AudioServiceActivity" in s:
        print("android: already patched")
        return
    s = re.sub(r"(<manifest[^>]*>)", lambda m: m.group(1) + ANDROID_PERMS, s, count=1)
    s = s.replace(
        'android:name=".MainActivity"',
        'android:name="com.ryanheise.audioservice.AudioServiceActivity"',
    )
    s = s.replace("</application>", ANDROID_SERVICES + "</application>", 1)
    s = re.sub(
        r'(<category android:name="android.intent.category.LAUNCHER"\s*/>)',
        lambda m: m.group(1)
        + '\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>',
        s,
        count=1,
    )
    f.write_text(s)
    print("android: patched")


def patch_ios():
    f = root / "ios/Runner/Info.plist"
    if not f.exists():
        return
    s = f.read_text()
    if "UIBackgroundModes" in s:
        print("ios: already patched")
        return
    add = (
        "\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>audio</string>\n\t</array>\n"
        "\t<key>UIFileSharingEnabled</key>\n\t<true/>\n"
        "\t<key>LSSupportsOpeningDocumentsInPlace</key>\n\t<true/>\n"
    )
    i = s.rfind("</dict>")
    f.write_text(s[:i] + add + s[i:])
    print("ios: patched")


patch_android()
patch_ios()
