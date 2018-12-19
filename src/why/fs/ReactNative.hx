package why.fs;

@:require('react-native-fs')
class ReactNative implements Fs {
	var root:String;
	
	public function new(root) {
		this.root = root;
	}
	
	public function list(path:String):Promise<Array<String>> {
		throw 'not implemented: why.fs.ReactNative.list';
	}
	
	public function exists(path:String):Promise<Bool> {
		throw 'not implemented: why.fs.ReactNative.exists';
	}
	
	public function move(from:String, to:String):Promise<Noise> {
		throw 'not implemented: why.fs.ReactNative.move';
	}
	
	public function read(path:String):RealSource {
		throw 'not implemented: why.fs.ReactNative.read';
	}
	
	public function write(path:String, ?options:WriteOptions):RealSink {
		throw 'not implemented: why.fs.ReactNative.write';
	}
	
	public function delete(path:String):Promise<Noise> {
		throw 'not implemented: why.fs.ReactNative.delete';
	}
	
	public function stat(path:String):Promise<Stat> {
		throw 'not implemented: why.fs.ReactNative.stat';
	}
	
	public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo> {
		throw 'not implemented: why.fs.ReactNative.getDownloadUrl';
	}
	
	public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo> {
		throw 'not implemented: why.fs.ReactNative.getUploadUrl';
	}
	
}