# Why File System

Abstraction of various (cloud) file systems.

## Interface

See [Fs.hx](src/why/Fs.hx)

## Usage

Pick one implementation from the `why.fs` package or roll your own.

- Local.hx: Works with your local filesystem (requires the Haxe library [asys](https://github.com/benmerckx/asys))
- S3.hx: Works with AWS S3 (requires the node module [aws-sdk](https://github.com/aws/aws-sdk-js))
- ReactNative.hx: Works with React Native (requires the node module [rn-fetch-blob](https://github.com/joltup/rn-fetch-blob) and the [same-named Haxe extern library](https://github.com/haxe-react/rn-fetch-blob) )