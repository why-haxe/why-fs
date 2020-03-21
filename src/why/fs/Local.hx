package why.fs;

import why.Fs;
import tink.state.Progress;

using asys.io.File;
using asys.FileSystem;
using tink.CoreApi;
using tink.io.Sink;
using tink.io.Source;
using haxe.io.Path;
using StringTools;

@:require('asys')
class Local implements Fs {
	var options:LocalOptions;

	public function new(options:LocalOptions) {
		this.options = options;
	}

	public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
		throw 'download not implemented';
	}

	public function list(prefix:String, ?recursive:Bool = true):Promise<ListResult> {
		var fullpath = getFullPath(prefix);
		return fullpath
			.exists()
			.next(function(exists) {
				var files:Array<why.Fs.File> = [];
				var directories:Array<String> = [];
				var ret = {files: files, directories: directories}
				return if (!exists) {
					ret;
				} else {
					function read(f:String):Promise<Noise> {
						return f
							.readDirectory()
							.next(function(list) {
								return Promise.inParallel([for (item in list) {
									var path = Path.join([f, item]);
									path
										.isDirectory()
										.next(function(isDir) {
											return if (isDir) {
												if (recursive) {
													read(path);
												} else {
													directories.push(path
														.substr(fullpath.length - prefix.length)
														.addTrailingSlash()
													);
													Noise;
												}
											} else {
												files.push(new LocalFile(options, path.substr(fullpath.length - prefix.length)));
												Noise;
											}
										});
								}]);
							});
					}
					read(fullpath)
						.swap(ret);
				}
			});
	}

	public function file(path:String):why.Fs.File {
		return new LocalFile(options, path);
	}

	public function delete(path:String):Promise<Noise> {
		var fullpath = getFullPath(path);
		return fullpath
			.exists()
			.next(function(exists) {
				return if (!exists) new Error(NotFound, 'Path "$fullpath" does not exist'); else fullpath.isDirectory();
			})
			.next(function(isDir) {
				return isDir ? fullpath.deleteDirectory() : fullpath.deleteFile();
			});
	}

	inline function getFullPath(path:String) {
		var full = Path.join([options.root, path]);
		while (full.startsWith('.//'))
			full = '.' + full.substr(2); // https://github.com/HaxeFoundation/haxe/issues/7548
		return full.normalize();
	}
}

class LocalFile implements why.Fs.File {
	public final stats:Null<Stat>;
	public final path:String;

	final options:LocalOptions;
	final fullpath:String;

	public function new(options, path, ?stats) {
		this.options = options;
		this.path = path;
		this.stats = stats;
		fullpath = getFullPath(path);
	}

	public function exists():Promise<Bool>
		return fullpath.exists();

	public function move(to:String):Promise<Noise> {
		var from = fullpath;
		var to = getFullPath(to);
		return ensureDirectory(to.directory())
			.next(function(_) return from.rename(to));
	}

	public function copy(to:String):Promise<Noise> {
		var from = fullpath;
		var to = getFullPath(to);
		return ensureDirectory(to.directory())
			.next(function(_) return from.copy(to));
	}

	public function read():RealSource
		return fullpath.readStream();

	public function write(source:RealSource, ?options:WriteOptions):Promise<Noise> {
		return ensureDirectory(fullpath.directory())
			.next(function(_) return source.pipeTo(fullpath.writeStream(), {end: true}))
			.next(function(v) return v.toOutcome())
			.noise();
	}

	public function delete():Promise<Noise> {
		return fullpath.deleteFile();
	}

	public function stat():Promise<Stat> {
		return fullpath
			.stat()
			.asPromise()
			.next(function(stat):Stat return {
				size: stat.size,
				mime: mime.Mime.lookup(path),
				lastModified: stat.mtime,
			});
	}

	public function getDownloadUrl(?opt:DownloadOptions):Promise<RequestInfo>
		return options.getDownloadUrl == null ? new Error(NotImplemented, 'getDownloadUrl is not implemented') : options.getDownloadUrl(path, opt);

	public function getUploadUrl(?opt:UploadOptions):Promise<RequestInfo>
		return options.getUploadUrl == null ? new Error(NotImplemented, 'getUploadUrl is not implemented') : options.getUploadUrl(path, opt);

	inline function getFullPath(path:String) {
		var full = Path.join([options.root, path]);
		while (full.startsWith('.//'))
			full = '.' + full.substr(2); // https://github.com/HaxeFoundation/haxe/issues/7548
		return full.normalize();
	}

	function ensureDirectory(dir:String):Promise<Noise>
		return dir
			.exists()
			.next(function(e) return e ? Noise : dir.createDirectory());
}

typedef LocalOptions = {
	root:String,
	?getDownloadUrl:String->DownloadOptions->Promise<RequestInfo>,
	?getUploadUrl:String->UploadOptions->Promise<RequestInfo>,
}
