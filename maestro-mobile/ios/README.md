# iOS platform files

Run this from `maestro-mobile` after the local Flutter SDK wrapper is usable:

```sh
flutter create --platforms=ios .
```

The Flutter source in `lib/` is platform-neutral and already targets iOS. The generated Xcode project is intentionally not hand-authored here because incomplete Xcode scaffolding is easy to break and should be produced by the Flutter toolchain.
