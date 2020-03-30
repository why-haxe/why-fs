package why.fs;

import why.Fs;
import tink.streams.Stream;
import tink.http.Method;
import tink.http.Header;
import tink.http.Request;
import tink.io.PipeOptions;
import tink.io.PipeResult;
import tink.state.Progress;
import tink.Chunk;
import haxe.io.BytesBuffer;
#if nodejs
import js.node.Buffer;
import js.aws.s3.PutObjectInput;
import js.aws.s3.S3 as NativeS3;
#end

using tink.CoreApi;
using tink.io.Source;
using tink.io.Sink;
using StringTools;
using DateTools;
using haxe.io.Path;
using why.fs.Util;

@:build(futurize.Futurize.build())
@:require('extern-js-aws-sdk')
class S3 implements Fs {
	var bucket:String;
	var s3:NativeS3;

	public function new(bucket, ?opt) {
		this.bucket = bucket;
		s3 = new NativeS3(opt);
	}

	public function download(req:OutgoingRequestHeader, local:String):Progress<Outcome<Noise, Error>> {
		throw 'download not implemented';
	}

	public function list(path:String, ?recursive:Bool = true):Promise<ListResult> {
		var prefix = sanitize(path);
		if (prefix.length > 0)
			prefix = prefix.addTrailingSlash();

		if (prefix.startsWith('./'))
			prefix = prefix.substr(2);

		if (recursive) {
			return @:futurize s3
				.listObjectsV2({Bucket: bucket, Prefix: prefix}, $cb1)
				.next(function(o):ListResult return {
					files: [for (obj in o.Contents)
						if (!obj.Key.endsWithCharCode('/'.code))
							new S3File(bucket, s3, obj.Key, {
								size: obj.Size,
								lastModified: cast obj.LastModified, // extern is wrong, it is Date already
							})
								.asFile()
					],
					directories: [],
				});
		} else {
			return @:futurize s3
				.listObjectsV2({Bucket: bucket, Prefix: prefix, Delimiter: '/'}, $cb1)
				.next(function(o):ListResult return {
					files: [
						for (obj in o.Contents)
							new S3File(bucket, s3, obj.Key, {
								size: obj.Size,
								lastModified: cast obj.LastModified, // extern is wrong, it is Date already
							})
								.asFile()
					],
					directories: [for (v in o.CommonPrefixes) v.Prefix],
				});
		}
	}

	public function delete(path:String):Promise<Noise> {
		path = sanitize(path);
		return if (path.endsWithCharCode('/'.code)) { // delete recursively if `path` is a folder
			// WTH batch delete not supported in Node.js?! https://docs.aws.amazon.com/AmazonS3/latest/dev/DeletingMultipleObjects.html
			list(path, true)
				.next(function(v) {
					return if (v.files.length == 0) {
						Promise.NOISE;
					} else @:futurize s3.deleteObjects({
						Bucket: bucket,
						Delete: {
							Objects: [for (f in v.files) {Key: f.path}]
						}
					}, $cb);
				});
		} else {
			@:futurize s3.deleteObject({Bucket: bucket, Key: path}, $cb1);
		}
	}

	public function file(path:String) {
		return new S3File(bucket, s3, sanitize(path));
	}

	inline static function sanitize(path:String) {
		return path.removeLeadingSlash();
	}
}

@:build(futurize.Futurize.build())
class S3File implements File {
	public final path:String;
	public final info:Info;

	final bucket:String;
	final s3:NativeS3;

	public function new(bucket, s3, path, ?info) {
		this.path = path;
		this.info = info;
		this.bucket = bucket;
		this.s3 = s3;
	}

	public function exists():Promise<Bool>
		return @:futurize s3
			.headObject({Bucket: bucket, Key: path}, $cb1)
			.next(function(_) return true)
			.recover(function(_) return false);

	public function move(to:String):Promise<Noise> {
		var from = path;
		to = sanitize(to);

		return copy(to)
			.next(function(_) return @:futurize s3.deleteObject({Bucket: bucket, Key: from}, $cb1));
	}

	public function copy(to:String):Promise<Noise> {
		var from = path;
		to = sanitize(to);

		// retain acl: https://stackoverflow.com/a/38903136/3212365
		return @:futurize s3
			.copyObject({Bucket: bucket, CopySource: '$bucket/$from', Key: to}, $cb1)
			.next(function(_) return @:futurize s3.getObjectAcl({Bucket: bucket, Key: from}, $cb1))
			.next(function(acl) return @:futurize s3.putObjectAcl({Bucket: bucket, Key: to, AccessControlPolicy: acl}, $cb1));
	}

	public function read():RealSource {
		return @:futurize s3
			.getObject({Bucket: bucket, Key: path}, $cb1)
			.next(function(o):RealSource return (o.Body : Buffer)
				.hxToBytes()
			);
	}

	public function write(source:RealSource, ?options:WriteOptions):Promise<Noise> {
		if (options == null)
			options = {}

		return source
			.all()
			.next(chunk -> {
				@:futurize s3.putObject({
					Bucket: bucket,
					Key: path,
					ACL: (options != null && options.isPublic) ? 'public-read' : 'private',
					ContentType: options.mime,
					CacheControl: options.cacheControl,
					Expires: cast options.expires,
					Metadata: switch options {
						case null | {metadata: null}: {}
						case {metadata: obj}: (cast obj : {});
					},
					Body: chunk.toBuffer(),
				}, $cb);
			});
	}

	public function delete():Promise<Noise> {
		return @:futurize s3.deleteObject({Bucket: bucket, Key: path}, $cb1);
	}

	public function getInfo():Promise<Info> {
		return @:futurize s3
			.headObject({Bucket: bucket, Key: path}, $cb1)
			.next(function(o):Info return {
				size: o.ContentLength,
				mime: o.ContentType,
				lastModified: cast o.LastModified, // extern is wrong, it is Date already
				metadata: o.Metadata,
			});
	}

	public function getDownloadUrl(?options:DownloadOptions):Promise<OutgoingRequestHeader> {
		return if (options != null && options.isPublic && options.saveAsFilename == null)
			new OutgoingRequestHeader(GET, 'https://$bucket.s3.amazonaws.com/' + path, [])
		else @:futurize
			s3
				.getSignedUrl('getObject', {
					Bucket: bucket,
					Key: path,
					ResponseContentDisposition: switch options {
						case null | {saveAsFilename: null}: null;
						case {saveAsFilename: filename}: 'attachment; filename="$filename"';
					},
					#if why.fs.snapExpiry
					Expires: {
						var now = Date.now();
						var buffer = now.delta(15 * 60000);
						var target = new Date(buffer.getFullYear(), buffer.getMonth(), buffer.getDate() + 7 - buffer.getDay(), 0, 0, 0);
						Std.int
						((target.getTime() - buffer.getTime()) / 1000);
					},
					#end
				}, $cb1)
				.next(function(url) return new OutgoingRequestHeader(GET, url, []));
	}

	public function getUploadUrl(?options:UploadOptions):Promise<OutgoingRequestHeader> {
		if (options == null || options.mime == null)
			return new Error('Requires mime type');
		return @:futurize s3
			.getSignedUrl('putObject', {
				Bucket: bucket,
				Key: path,
				ACL: (options != null && options.isPublic) ? 'public-read' : 'private',
				ContentType: options.mime,
				CacheControl: options.cacheControl,
				Expires: options.expires,
				Metadata: switch options {
					case null | {metadata: null}: {}
					case {metadata: obj}: obj;
				}
			}, $cb1)
			.next(function(url) return new OutgoingRequestHeader(PUT, url, [
				new HeaderField(CONTENT_TYPE, options.mime),
				new HeaderField(CACHE_CONTROL, options.cacheControl),
			]));
	}

	public inline function asFile():File
		return this;

	inline static function sanitize(path:String) {
		return path.removeLeadingSlash();
	}
}
