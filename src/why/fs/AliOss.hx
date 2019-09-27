package why.fs;

import js.node.stream.Readable.IReadable;
import why.Fs;
import tink.state.Progress;
import haxe.DynamicAccess;

using tink.io.Source;
using tink.io.Sink;
using tink.CoreApi;
using haxe.io.Path;
using why.fs.Util;

class AliOss implements Fs {
	
	var oss:NativeOss;
	
	public function new(opt) {
		oss = new NativeOss(opt);
	}
	
	public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
		throw 'AliOss#download is not implemented';
	}
	
	public function list(path:String, ?recursive:Bool = true):Promise<Array<Entry>> {
		var prefix = sanitize(path);
		if(prefix.length > 0) prefix = prefix.addTrailingSlash();
		return
			if(recursive)
				Promise.ofJsPromise(oss.list({prefix: prefix}))
					.next(function(o):Array<Entry> {
						return switch o.objects {
							case null: [];
							case objects:
								[for(obj in objects) {
									switch [obj.name.substr(prefix.length), obj.name.endsWithCharCode('/'.code)] {
										case ['', _]: continue;
										case [path, isDir]:
											new Entry(
												isDir ? path.substr(0, path.length - 1) : path,
												isDir ? Directory : File,
												{
													size: obj.size, 
													lastModified: js.Syntax.code('new Date({0})', obj.lastModified),
												}
											);
									}
								}];
						}
					});
			else
				new Error(NotImplemented, 'Not implemented');
	}
	
	public function exists(path:String):Promise<Bool> {
		return Promise.ofJsPromise(oss.head(sanitize(path)))
			.swap(true)
			.tryRecover(function(e) return e.data != null && e.data.code == 'NoSuchKey' ? false : e);
	}
	
	public function move(from:String, to:String):Promise<Noise> {
		return copy(from, to).next(_ -> delete(from));
	}
	
	public function copy(from:String, to:String):Promise<Noise> {
		return Promise.ofJsPromise(oss.copy(sanitize(to), sanitize(from)));
	}
	
	public function read(path:String):RealSource {
		return Promise.ofJsPromise(oss.getStream(sanitize(path)))
			.next(function(o) return Source.ofNodeStream('ReadStream for $path', o.stream));
	}
	
	public function write(path:String, ?options:WriteOptions):RealSink {
		return new Error(NotImplemented, 'AliOss#write is not implemented');
	}
	
	public function delete(path:String):Promise<Noise> {
		return Promise.ofJsPromise(oss.delete(sanitize(path)));
	}
	
	public function stat(path:String):Promise<Stat> {
		return Promise.ofJsPromise(oss.head(sanitize(path)))
			.next(function(o) return {
				size: Std.parseInt(o.res.headers['content-length']),
				lastModified: js.Syntax.code('new Date({0})', o.res.headers['last-modified']),
				metadata: o.meta == null ? {} : o.meta,
				mime: o.res.headers['content-type'],
			});
	}
	
	public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo> {
		return new Error(NotImplemented, 'AliOss#getDownloadUrl is not implemented');
	}
	
	public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo> {
		return new Error(NotImplemented, 'AliOss#getUploadUrl is not implemented');
	}
	
	inline static function sanitize(path:String) {
		return path.removeLeadingSlash();
	}
}

@:jsRequire('ali-oss')
private extern class NativeOss {
	@:selfCall
	function new(opt:{});
	function head(name:String, ?options:{}):js.Promise<HeadResult>;
	function delete(name:String, ?options:{}):js.Promise<DeleteResult>;
	function getStream(name:String, ?options:{}):js.Promise<GetStreamResult>;
	function copy(to:String, from:String, ?options:{}):js.Promise<DeleteResult>;
	function list(query:{}, ?options:{}):js.Promise<ListResult>;
}

private typedef Result = {
	res:{
		status:Int,
		statusCode:Int,
		statusMessage:String,
		headers:DynamicAccess<String>,
		size:Int,
		rt:Int,
	}
}
private typedef HeadResult = {
	> Result,
	status:Int,
	meta:DynamicAccess<String>,
}
private typedef GetStreamResult = {
	> Result,
	stream:IReadable,
}
private typedef DeleteResult = {
	> Result,
}
private typedef ListResult = {
	> Result,
	objects:Array<{
		name:String,
		lastModified:String,
		etag:String,
		type:String,
		size:Int,
		storageClass:String,
		owner:{id:String, displayName:String},
	}>,
	prefixes:Array<String>,
	isTruncated:Bool,
	nextMarker:String,
}