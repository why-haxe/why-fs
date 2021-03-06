package why.fs;

import why.Fs;
import tink.state.Progress;
import tink.http.Method;
import tink.http.Header;

using tink.CoreApi;
using tink.io.Source;
using tink.io.Sink;
using StringTools;
using haxe.io.Path;
using why.fs.Util;

class GoogleCloudStorage implements Fs {
	
	var bucket:Bucket;
	
	public function new(bucket, ?opt) {
		var storage = new Storage(opt);
		this.bucket = storage.bucket(bucket);
		
	}
	
	public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
		throw 'why.fs.GoogleCloudStorage.download is not implemented';
	}
	
	public function list(path:String, ?recursive:Bool = true):Promise<Array<Entry>> {
		var prefix = sanitize(path);
		if(prefix.length > 0) prefix = prefix.addTrailingSlash();
		
		return
			if(recursive)
				Promise.ofJsPromise(bucket.getFiles({prefix: prefix}))
					.next(function(o):Array<Entry> {
						return [for(file in o.files) {
							switch Util.createEntry(prefix, file.name, parseStat(file.metadata)) {
								case null: continue;
								case entry: entry;
							}
						}];
					});
			else
				new Error(NotImplemented, 'Not implemented');
	}
	
	public function exists(path:String):Promise<Bool> {
		return Promise.ofJsPromise(bucket.file(sanitize(path)).exists())
			.next(function(v) return v.exists);
	}
	
	public function move(from:String, to:String):Promise<Noise> {
		return copy(from, to).next(function(_) return delete(from));
	}
	
	public function copy(from:String, to:String):Promise<Noise> {
		from = sanitize(from);
		to = sanitize(to);
		return Promise.ofJsPromise(bucket.file(from).copy(to))
			.next(function(_) return Promise.ofJsPromise(bucket.file(from).isPublic()))
			.next(function(o) return o.isPublic ? makePublicWhenExists(to) : Noise);
	}
	
	public function read(path:String):RealSource {
		path = sanitize(path);
		return Source.ofNodeStream('GoogleCloudStorage ReadStream: $bucket/$path', bucket.file(path).createReadStream());
	}
	
	public function write(path:String, ?options:WriteOptions):RealSink {
		path = sanitize(path);
		return Sink.ofNodeStream('GoogleCloudStorage WriteStream: $bucket/$path', bucket.file(path).createWriteStream({
			contentType: options == null ? null : options.mime,
			metadata: options == null || options.metadata == null ? {} : options.metadata,
			predefinedAcl: options == null || !options.isPublic ? 'private' : 'publicRead',
			resumeable: false,
		}));
	}
	
	public function delete(path:String):Promise<Noise> {
		inline function deleteFile(p:String) return Promise.ofJsPromise(bucket.file(p).delete());
		
		path = sanitize(path);
		return 
			if(path.endsWithCharCode('/'.code)) { // delete recursively if `path` is a folder
				list(path)
					.next(function(entries) {
						return Promise.inParallel([for(e in entries) if(e.type == File)
							deleteFile(Path.join([path, e.path]))
						]).noise();
					});
			} else {
				deleteFile(path);
			}
	}
	
	public function stat(path:String):Promise<Stat> {
		return Promise.ofJsPromise(bucket.file(sanitize(path)).getMetadata())
			.next(function(v) return parseStat(v.metadata));
	}
	
	public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo> {
		return Promise.ofJsPromise(bucket.file(sanitize(path)).getSignedUrl({action: 'read', expires: Date.now().getTime() + 24 * 3600000, promptSaveAs: options == null ? null : options.saveAsFilename}))
			.next(function(o) return {
				url: o.url,
				method: GET,
				headers: []
			});
	}
	
	public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo> {
		var acl = options == null || !options.isPublic ? 'private' : 'public-read';
		return Promise.ofJsPromise(bucket.file(sanitize(path)).getSignedUrl({
			action: 'write',
			contentType: options == null ? null : options.mime,
			expires: Date.now().getTime() + 3600000,
			extensionHeaders: {'x-goog-acl': acl}
			// TODO: other options
		}))
			.next(function(o) return {
				url: o.url,
				method: PUT,
				headers: {
					var headers = [new HeaderField('x-goog-acl', acl)];
					if(options != null && options.mime != null)
						headers.push(new HeaderField(CONTENT_TYPE, options.mime));
					headers;
				}
			});
	}
	
	/**
	 * Wait for the file (just uploaded / created) to exist and then set it to public
	 */
	function makePublicWhenExists(path:String) {
		path = sanitize(path);
		return Promise.retry(
			function() return exists(path)
				.next(function(e) return e ? makePublic(path) : new Error('Pending')),
			function(info) return Future.delay(100, Noise)
		);
	}
	
	inline function makePublic(path:String):Promise<Noise>
		return Promise.ofJsPromise(bucket.file(sanitize(path)).makePublic());
	
	static function parseStat(metadata:Dynamic):Stat {
		return {
			size: Std.parseInt(metadata.size),
			mime: metadata.contentType,
			lastModified: js.Syntax.code('new Date({0})', metadata.updated),
			metadata: metadata,
		}
	}
	
	inline static function sanitize(path:String) {
		return path.removeLeadingSlash();
	}
}

@:jsRequire('@google-cloud/storage', 'Storage')
private extern class Storage {
	function new(?opt:{});
	function bucket(name:String):Bucket;
}
private extern class Bucket {
	final name:String;
	function file(name:String):File;
	function getFiles(opt:{}):js.lib.Promise<GetFilesResponse>;
	function getMetadata():js.lib.Promise<GetBucketMetadataResponse>;
}
private extern class File {
	final name:String;
	final metadata:Dynamic;
	function isPublic():js.lib.Promise<IsPublicResponse>;
	function makePublic():js.lib.Promise<MakeFilePublicResponse>;
	function copy(to:String, ?opt:{}):js.lib.Promise<CopyResponse>;
	function delete():js.lib.Promise<DeleteResponse>;
	function move(to:String):js.lib.Promise<MoveResponse>;
	function exists():js.lib.Promise<FileExistsResponse>;
	function createReadStream():js.node.stream.Readable.IReadable;
	function createWriteStream(?opt:{}):js.node.stream.Writable.IWritable;
	function getMetadata():js.lib.Promise<GetFileMetadataResponse>;
	function getSignedUrl(config:{}):js.lib.Promise<GetSignedUrlResponse>;
}

private extern class MoveResponse {}
private extern class CopyResponse {}
private extern class DeleteResponse {}
private extern class MakeFilePublicResponse {}
private abstract IsPublicResponse(Array<Bool>) {
	public var isPublic(get, never):Bool;
	inline function get_isPublic() return this[0];
}
private abstract GetFilesResponse(Array<Array<File>>) {
	public var files(get, never):Array<File>;
	inline function get_files() return this[0];
}
private abstract GetSignedUrlResponse(Array<String>) {
	public var url(get, never):String;
	inline function get_url() return this[0];
}
private abstract FileExistsResponse(Array<Bool>) {
	public var exists(get, never):Bool;
	inline function get_exists() return this[0];
}
private abstract GetBucketMetadataResponse(Array<Dynamic>) {
	public var metadata(get, never):Dynamic;
	public var apiResponse(get, never):Dynamic;
	inline function get_metadata() return this[0];
	inline function get_apiResponse() return this[1];
}
private abstract GetFileMetadataResponse(Array<Dynamic>) {
	public var metadata(get, never):Dynamic;
	public var apiResponse(get, never):Dynamic;
	inline function get_metadata() return this[0];
	inline function get_apiResponse() return this[1];
}