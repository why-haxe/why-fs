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
import aws_sdk.S3 as NativeS3;
import aws_sdk.s3.*;
#end

using tink.CoreApi;
using tink.io.Source;
using tink.io.Sink;
using StringTools;
using DateTools;
using haxe.io.Path;
using why.fs.Util;

@:require('hxnodejs-aws-sdk')
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
			return Promise.ofJsPromise(s3.listObjectsV2({Bucket: bucket, Prefix: prefix}).promise())
				.next(function(o:ListObjectsV2Output):ListResult return {
					files: [for (obj in o.Contents)
						if (!obj.Key.endsWithCharCode('/'.code)) new S3File(bucket, s3, obj.Key, {
							size: Std.int(obj.Size),
							lastModified: js.lib.Date.toHaxeDate(obj.LastModified),
						})
							.asFile()
					],
					directories: [],
				});
		} else {
			return Promise.ofJsPromise(s3.listObjectsV2({Bucket: bucket, Prefix: prefix, Delimiter: '/'}).promise())
				.next(function(o:ListObjectsV2Output):ListResult return {
					files: [
						for (obj in o.Contents)
							new S3File(bucket, s3, obj.Key, {
								size: Std.int(obj.Size),
								lastModified: js.lib.Date.toHaxeDate(obj.LastModified),
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
					} else Promise.ofJsPromise(s3.deleteObjects({
						Bucket: bucket,
						Delete: {
							Objects: [for (f in v.files) {Key: f.path}]
						}
					}).promise());
				});
		} else {
			Promise.ofJsPromise(s3.deleteObject({Bucket: bucket, Key: path}).promise());
		}
	}

	public function file(path:String) {
		return new S3File(bucket, s3, sanitize(path));
	}

	inline static function sanitize(path:String) {
		return path.removeLeadingSlash();
	}
}

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
		return Promise.ofJsPromise(s3.headObject({Bucket: bucket, Key: path}).promise())
			.next(_ -> true)
			.recover(_ -> false);

	public function move(to:String):Promise<Noise> {
		var from = path;
		to = sanitize(to);

		return copy(to).next(_ -> s3.deleteObject({Bucket: bucket, Key: from}).promise());
	}

	public function copy(to:String):Promise<Noise> {
		var from = path;
		to = sanitize(to);

		// retain acl: https://stackoverflow.com/a/38903136/3212365
		return Promise.ofJsPromise(s3.copyObject({Bucket: bucket, CopySource: '$bucket/$from', Key: to}).promise())
			.next(_ -> s3.getObjectAcl({Bucket: bucket, Key: from}).promise())
			.next(acl -> s3.putObjectAcl({Bucket: bucket, Key: to, AccessControlPolicy: acl}).promise());
	}

	public function read():RealSource {
		return Promise.ofJsPromise(s3.getObject({Bucket: bucket, Key: path}).promise())
			.next(function(o):RealSource return (cast o.Body : Buffer).hxToBytes());
	}

	public function write(source:RealSource, ?options:WriteOptions):Promise<Noise> {
		if (options == null)
			options = {}

		return source
			.all()
			.next(chunk -> {
				Promise.ofJsPromise(s3.putObject({
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
				}).promise());
			});
	}

	public function delete():Promise<Noise> {
		return Promise.ofJsPromise(s3.deleteObject({Bucket: bucket, Key: path}).promise());
	}

	public function getInfo():Promise<Info> {
		return Promise.ofJsPromise(s3.headObject({Bucket: bucket, Key: path}).promise())
			.next(function(o):Info return {
				size: Std.int(o.ContentLength),
				mime: o.ContentType,
				lastModified: js.lib.Date.toHaxeDate(o.LastModified),
				metadata: o.Metadata,
			});
	}

	public function getDownloadUrl(?options:DownloadOptions):Promise<OutgoingRequestHeader> {
		return if (options != null && options.isPublic && options.saveAsFilename == null) new OutgoingRequestHeader(GET, 'https://$bucket.s3.amazonaws.com/'
			+ path, []) else Promise.ofJsPromise(s3
			.getSignedUrlPromise('getObject', {
				Bucket: bucket,
				Key: path,
				ResponseContentDisposition: switch options {
					case null | {saveAsFilename: null}: null;
					case {saveAsFilename: filename}: 'attachment; filename="$filename"';
				},
				#if why.fs.snapExpiry
				Expires: {
					final now:Date = Date.now();
					final buffer = now.delta(15 * 60000);
					final target = new Date(buffer.getFullYear(), buffer.getMonth(), buffer.getDate() + 7 - buffer.getDay(), 0, 0, 0);
					Std.int((target.getTime() - buffer.getTime()) / 1000);
				},
				#end
			}))
			.next(url -> new OutgoingRequestHeader(GET, url, []));
	}

	public function getUploadUrl(?options:UploadOptions):Promise<OutgoingRequestHeader> {
		if (options == null || options.mime == null)
			return new Error('Requires mime type');
		return Promise.ofJsPromise(s3
			.getSignedUrlPromise('putObject', {
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
			}))
			.next(url -> {
				final headers = [new HeaderField(CONTENT_TYPE, options.mime)];
				if(options.cacheControl != null)
					headers.push(new HeaderField(CACHE_CONTROL, options.cacheControl));
				new OutgoingRequestHeader(PUT, url, headers);
			});
	}

	public inline function asFile():File
		return this;

	inline static function sanitize(path:String) {
		return path.removeLeadingSlash();
	}
}
