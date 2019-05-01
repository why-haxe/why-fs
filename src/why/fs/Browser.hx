package why.fs;

import js.html.Blob;
import js.Browser.*;
import js.html.idb.*;
import why.Fs;
import tink.state.Progress;

using tink.CoreApi;
using tink.io.Sink;
using tink.io.Source;
using haxe.io.Path;
using StringTools;
using why.fs.Browser;

class Browser implements Fs {
	static inline var OBJECT_STORE_NAME = 'files';
	var ready:Promise<Database>;
	
	public function new(name) {
		ready = Future.async(function(cb) {
			var request = window.indexedDB.open(name, 1);
			
			request.onerror = function() {
				cb(Failure(new Error('Failed to open Database')));
			}
			request.onsuccess = function(event) {
				var db:Database = request.result;
				cb(Success(db));
			}
			request.onupgradeneeded = function(event) {
				var db:Database = event.target.result;
				if(!db.objectStoreNames.contains(OBJECT_STORE_NAME)) {
					var store = db.createObjectStore(OBJECT_STORE_NAME);
				}
			}
		});
	}
	
	public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
		throw 'TODO download';
	}
	
	public function list(path:String, ?recursive:Bool):Promise<Array<Entry>> {
		throw 'TODO list';
		// return [];
	}
	
	public function exists(path:String):Promise<Bool> {
		return store(READONLY)
			.next(function(store) return store.count(path).promisify())
			.next(function(count) return count > 0);
	}
	
	public function move(from:String, to:String):Promise<Noise> {
		throw 'TODO move';
	}
	
	public function copy(from:String, to:String):Promise<Noise> {
		throw 'TODO copy';
	}
	
	public function read(path:String):RealSource {
		return store(READONLY)
			.next(function(store) return store.get(path).promisify())
			.next(Source.ofJsBlob.bind(path));
	}
	
	public function write(path:String, ?options:WriteOptions):RealSink {
		return new CollectSink(function(chunk) {
			return store(READWRITE)
				.next(function(store) {
					var blob = new Blob([chunk.toBytes().getData()], {type: options == null || options.mime == null ? 'application/octet-stream' : options.mime});
					return store.put(blob, path).promisify();
				});
		});
	}
	
	public function delete(path:String):Promise<Noise> {
		return store(READWRITE)
			.next(function(store) return store.delete(path).promisify())
			.noise();
	}
	
	public function stat(path:String):Promise<Stat> {
		throw 'TODO stat';
	}
	
	public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo> {
		throw 'TODO getDownloadUrl';
	}
	
	public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo> {
		throw 'TODO getUploadUrl';
	}
	
	// public function new(path, type, stat) {
	// 	throw 'TODO new';
	// }
	
	public function toString():String {
		throw 'TODO toString';
	}
	
	function store(mode):Promise<ObjectStore> {
		return ready.next(function(db) {
			return try {
				Promise.resolve(db.transaction([OBJECT_STORE_NAME], mode).objectStore(OBJECT_STORE_NAME));
			} catch(e:js.Error) {
				Promise.reject(Error.ofJsError(e));
			} catch(e:Dynamic) {
				Promise.reject(Error.withData('Unable to retrieve object store', e));
			}
		});
	}
	
	static function promisify<T>(req:Request):Promise<T> {
		return new Promise(function (resolve, reject) {
			req.onsuccess = function(_) resolve(req.result);
			req.onerror = function(_) reject(new Error('Request failed'));
		});
	}
	
	static function sanitize(path:String) {
		if(path.charCodeAt(0) == '/'.code) path = path.substr(1);
		return path;
	}
}