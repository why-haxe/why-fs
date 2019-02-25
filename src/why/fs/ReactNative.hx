package why.fs;

#if !rn_fetch_blob
	#error "Requires the rn-fetch-blob extern library"
#end

import react.native.fetch_blob.*;
import why.Fs;
import haxe.DynamicAccess;
import tink.state.Progress;

using tink.CoreApi;
using haxe.io.Path;
using tink.io.Source;
using tink.io.Sink;
using Lambda;

@:require('react-native-fs')
class ReactNative implements Fs {
	var root:String;
	
	public static var DOCUMENT_DIRECTORY(get, never):String;
	public static var CACHE_DIRECTORY(get, never):String;
	
	inline static function get_DOCUMENT_DIRECTORY():String return RNFetchBlob.fs.dirs.DocumentDir;
	inline static function get_CACHE_DIRECTORY():String return RNFetchBlob.fs.dirs.CacheDir;
	
	public function new(root) {
		this.root = root;
	}
	
	public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
		return Progress.make(function(progress, finish) {
			RNFetchBlob.config({path: getFullPath(local)})
				.fetch(req.method, req.url, {
					var headers:DynamicAccess<String> = {};
					for(header in req.headers) headers[header.name] = header.value;
					headers;
				})
				.progress(function(received, total) progress(received, total == -1 ? None : Some(total)))
				.then(function(_) finish(Success(Noise)))
				.catchError(function(e) finish(Failure(Error.ofJsError(e))));
		});
	}
	
	public function list(path:String, ?recursive:Bool):Promise<Array<Entry>> {
		var fullpath = getFullPath(path);
		
		return (function _list(rel:String) {
			var p = Path.join([fullpath, rel]).normalize();
			return Promise.ofJsPromise(RNFetchBlob.fs.ls(Path.join([fullpath, rel]).normalize()))
				.next(function(files) {
					return Promise.inParallel([for(file in files) 
						RNFetchBlob.fs.isDir(Path.join([fullpath, rel, file]).normalize())
							.then(function(isDir) return new Entry(Path.join([rel, file]), isDir ? Directory : File, {}))
					]);
				})
				.next(function(entries) {
					return if(recursive) {
						Promise.inParallel([for(entry in entries) if(entry.type == Directory) _list(entry.path)])
							.next(function(subs) return subs.fold(function(sub, all:Array<Entry>) return all.concat(sub), entries));
					} else {
						entries;
					}
				});
		})('.');
	}
	
	public function exists(path:String):Promise<Bool> {
		return RNFetchBlob.fs.exists(getFullPath(path));
	}
	
	public function move(from:String, to:String):Promise<Noise> {
		return RNFetchBlob.fs.mv(getFullPath(from), getFullPath(to)).then(_ -> Noise);
	}
	
	public function copy(from:String, to:String):Promise<Noise> {
		return RNFetchBlob.fs.cp(getFullPath(from), getFullPath(to)).then(_ -> Noise);
	}
	
	public function read(path:String):RealSource {
		throw 'not implemented: why.fs.ReactNative.read';
		// readStream
	}
	
	public function write(path:String, ?options:WriteOptions):RealSink {
		throw 'not implemented: why.fs.ReactNative.write';
		// writeStream
	}
	
	public function delete(path:String):Promise<Noise> {
		return RNFetchBlob.fs.unlink(getFullPath(path)).then(_ -> Noise);
	}
	
	public function stat(path:String):Promise<Stat> {
		throw 'not implemented: why.fs.ReactNative.stat';
		// stat
	}
	
	public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo> {
		throw 'not supported: why.fs.ReactNative.getDownloadUrl';
	}
	
	public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo> {
		throw 'not supported: why.fs.ReactNative.getUploadUrl';
	}
	
	inline function getFullPath(path:String) {
		var full = Path.join([root, path]);
		return full.normalize();
	}	
}