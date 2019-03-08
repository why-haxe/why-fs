# Why File System

Abstraction of various (cloud) file systems.
Mostly useful for reusing the same code for both local development and production environment.
For example one may use the `Local` implementation while development on local machine and use the `S3` implementation on production.
Since they implements the same interface, the swapping can be as simple as this:

```haxe
var fs:Fs = #if local new Local(root) #else new S3(bucket) #end;

// then use the `fs` instance everywhere
```

## Interface

A quick glance:

```haxe
interface Fs {
	function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>>;
	function list(path:String, ?recursive:Bool):Promise<Array<Entry>>;
	function exists(path:String):Promise<Bool>;
	function move(from:String, to:String):Promise<Noise>;
	function copy(from:String, to:String):Promise<Noise>;
	function read(path:String):RealSource;
	function write(path:String, ?options:WriteOptions):RealSink;
	function delete(path:String):Promise<Noise>;
	function stat(path:String):Promise<Stat>;
	function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo>;
	function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo>;
}
```

Check out [Fs.hx](src/why/Fs.hx) for the documentations of each method.


## Usage

Pick one implementation from the `why.fs` package or roll your own.

- Local.hx: Works with your local filesystem (requires the Haxe library [asys](https://github.com/benmerckx/asys))
- S3.hx: Works with AWS S3 (requires the node module [aws-sdk](https://github.com/aws/aws-sdk-js))
- ReactNative.hx: Works with React Native (requires the node module [rn-fetch-blob](https://github.com/joltup/rn-fetch-blob) and the [same-named Haxe extern library](https://github.com/haxe-react/rn-fetch-blob) )