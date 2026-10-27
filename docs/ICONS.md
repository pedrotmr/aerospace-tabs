# App icon

The original icon assets live in `Resources/`, and Xcode is the only tool that adds the app icon to the bundle. `Resources/AerospaceTabs.icns` is the existing product icon and remains the bundle asset named by `CFBundleIconFile` in `Config/Info.plist`. It is copied unchanged. `Resources/aerospace-tabs-icon.png` and `Resources/AppIcon.png` are identical 1024-pixel PNG assets used for documentation and repository presentation.

There is no icon generation command for this app. Keep the ICNS file as the installed app icon. `make bundle` and `make check` inspect the built app bundle and fail if that icon is missing.
