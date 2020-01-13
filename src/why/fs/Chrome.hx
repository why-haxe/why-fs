package why.fs;

import js.html.*;
import js.Browser.*;
import why.Fs;
import haxe.DynamicAccess;
import tink.state.Progress;
import tink.streams.Stream;
import tink.io.PipeOptions;
import tink.Chunk;

using tink.CoreApi;
using haxe.io.Path;
using tink.io.Source;
using tink.io.Sink;
using tink.io.PipeResult;
using Lambda;

@:native('window')
extern enum abstract FileSystemType(Int) {
	@:native('PERSISTENT') var Persistent;
	@:native('TEMPORARY') var Temporary;
}

/**
 * Based on Chrome's FileSystem API (which is abandoned/discontinued)
 */
class Chrome implements Fs {
	var fs:Promise<FileSystem>;
	
	public function new(type:FileSystemType, size:Int) {
		fs = promise(function(resolve, reject) {
			var request = js.Syntax.code('window.requestFileSystem || window.webkitRequestFileSystem');
			request(type, size, resolve, reject);
		});
	}
	
	inline function promise<T>(f:(T->Void)->(js.lib.Error->Void)->Void):Promise<T> {
		return new Promise(function(resolve, reject) f(resolve, function(e) reject(Error.ofJsError(e))));
	}
	
	public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
		throw 'why.fs.Browser#download is not implemented';
	}
	
	public function list(path:String, ?recursive:Bool):Promise<Array<Entry>> {
		return fs
			.next(function(fs) {
				return promise(function(resolve, reject) {
					fs.root.getDirectory(path, resolve, reject);
				});
			})
			.next(function(dir) {
				return promise(function(resolve, reject) {
					var reader = (cast dir:FileSystemDirectoryEntry).createReader();
					reader.readEntries(resolve, reject);
				});
			})
			.next(function(entries:Array<FileSystemEntry>):Array<Entry> {
				return [for(entry in entries) new Entry(entry.fullPath, entry.isDirectory ? Directory : File, {})];
			});
	}
	
	public function exists(path:String):Promise<Bool> {
		return fs
			.next(function(fs) {
				return promise(function(resolve, reject) {
					fs.root.getFile(path, function(_) resolve(true), function(e) if(e.name == 'NotFoundError') resolve(false) else reject(cast e));
				});
			});
	}
	
	public function move(from:String, to:String):Promise<Noise> {
		return new Error(NotImplemented, 'why.fs.Browser#move is not implemented');
	}
	
	public function copy(from:String, to:String):Promise<Noise> {
		return new Error(NotImplemented, 'why.fs.Browser#copy is not implemented');
	}
	
	public function read(path:String):RealSource {
		return fs
			.next(function(fs) {
				return promise(function(resolve, reject) {
					fs.root.getFile(path, resolve, reject);
				});
			})
			.next(function(file) {
				return promise(function(resolve, reject) {
					(cast file:FileSystemFileEntry).file(resolve, reject);
				});
			})
			.next(function(file) return Source.ofJsFile(path, file));
	}
	
	public function write(path:String, ?options:WriteOptions):RealSink {
		return fs
			.next(function(fs) {
				return promise(function(resolve, reject) {
					fs.root.getFile(path, {create: true}, resolve, reject);
				});
			})
			.next(function(file):RealSink return new BrowserSink(cast file));
	}
	
	public function delete(path:String):Promise<Noise> {
		return fs
			.next(function(fs) {
				return promise(function(resolve, reject) {
					fs.root.getFile(path, {create: true}, resolve, reject);
				});
			})
			.next(function(file) {
				return promise(function(resolve, reject) {
					(untyped file.remove)(resolve.bind(Noise), reject);
				});
			});
	}
	
	public function stat(path:String):Promise<Stat> {
		return new Error(NotImplemented, 'why.fs.Browser#stat is not implemented');
	}
	
	public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo> {
		return new Error(NotImplemented, 'why.fs.Browser#getDownloadUrl is not implemented');
	}
	
	public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo> {
		return new Error(NotImplemented, 'why.fs.Browser#getUploadUrl is not implemented');
	}
}

class BrowserSink extends SinkBase<Error, Noise> {
	var ended = false;
	var file:FileSystemFileEntry;

	public function new(file) {
		this.file = file;
	}

	override function get_sealed() return ended;

	override function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
		return source.forEach(function(chunk) {
			return Future.async(function(cb) {
				(untyped file.createWriter)(function(writer) {
					writer.onwriteend = function() cb(Resume);
					writer.onerror = function(e) cb(Clog(Error.ofJsError(e)));
						
					writer.write(new Blob([chunk.toBytes().getData()]));
				});
			});
		}).flatMap(function(o):Future<PipeResult<EIn, Error, Noise>> return switch o {
			case Depleted:
				if(options.end)
					ended = true;
				Future.sync(AllWritten);
			case Clogged(e, rest):
				Future.sync(SinkFailed(e, rest));
			case Failed(e):
				Future.sync(cast SourceFailed(e));
			case Halted(rest):
				throw 'unreachable';
		});
	}
}