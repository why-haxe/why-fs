package why.fs;

import why.Fs;
import tink.streams.Stream;
import tink.http.Method;
import tink.http.Header;
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
  
  public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
    throw 'download not implemented';
  }
  
  public function list(path:String, ?recursive:Bool = true):Promise<Array<Entry>> {
    var prefix = sanitize(path);
		if(prefix.length > 0) prefix = prefix.addTrailingSlash();
    
    if(recursive) {
      return @:futurize s3.listObjectsV2({Bucket: bucket, Prefix: prefix}, $cb1)
        .next(function(o):Array<Entry> {
          return [for(obj in o.Contents) {
            switch Util.createEntry(prefix, obj.Key, {
              size: obj.Size,
              lastModified: cast obj.LastModified, // extern is wrong, it is Date already
            }) {
              case null: continue;
              case entry: entry;
            }
          }];
        });
    } else {
      return @:futurize s3.listObjectsV2({Bucket: bucket, Prefix: prefix, Delimiter: '/'}, $cb1)
        .next(function(o):Array<Entry> {
          var ret = [];
          for(obj in o.Contents)
            ret.push(new Entry(obj.Key.substr(prefix.length), File, {
              size: obj.Size,
              lastModified: cast obj.LastModified, // extern is wrong, it is Date already
            }));
          for(folder in o.CommonPrefixes)
            ret.push(new Entry(folder.Prefix.substr(prefix.length), Directory, {}));
          return ret;
        });
    }
  }
  
  public function exists(path:String):Promise<Bool>
    return @:futurize s3.headObject({Bucket: bucket, Key: sanitize(path)}, $cb1)
      .next(function(_) return true)
      .recover(function(_) return false);
      
  public function move(from:String, to:String):Promise<Noise> {
    from = sanitize(from);
    to = sanitize(to);
    
    return copy(from, to)
      .next(function(_) return @:futurize s3.deleteObject({Bucket: bucket, Key: from}, $cb1));
  }
      
  public function copy(from:String, to:String):Promise<Noise> {
    from = sanitize(from);
    to = sanitize(to);
    
    // retain acl: https://stackoverflow.com/a/38903136/3212365
    return @:futurize s3.copyObject({Bucket: bucket, CopySource: '$bucket/$from', Key: to}, $cb1)
        .next(function(_) return @:futurize s3.getObjectAcl({Bucket: bucket, Key: from}, $cb1))
        .next(function(acl) return @:futurize s3.putObjectAcl({Bucket: bucket, Key: to, AccessControlPolicy: acl}, $cb1));
  }
  
  public function read(path:String):RealSource {
    return @:futurize s3.getObject({Bucket: bucket, Key: sanitize(path)}, $cb1)
      .next(function(o):RealSource return (o.Body:Buffer).hxToBytes());
  }
  
  public function write(path:String, ?options:WriteOptions):RealSink {
    if(options == null) options = {}
    return new S3Sink(s3, {
      Bucket: bucket, 
      Key: sanitize(path), 
      ACL: (options != null && options.isPublic) ? 'public-read' : 'private',
      ContentType: options.mime,
      CacheControl: options.cacheControl,
      Expires: cast options.expires,
      Metadata: 
        switch options {
          case null | {metadata: null}: {}
          case {metadata: obj}: (cast obj:{});
        }
    });
  }
  
  public function delete(path:String):Promise<Noise> {
    path = sanitize(path);
    return 
      if(path.endsWithCharCode('/'.code)) { // delete recursively if `path` is a folder
        // WTH batch delete not supported in Node.js?! https://docs.aws.amazon.com/AmazonS3/latest/dev/DeletingMultipleObjects.html
        list(path)
          .next(function(entries) {
            return @:futurize s3.deleteObjects({
                Bucket: bucket, 
                Delete: {
                  Objects: [for(e in entries) {Key: Path.join([path, e.path])}]
                }
            }, $cb);
          });
      } else {
        @:futurize s3.deleteObject({Bucket: bucket, Key: path}, $cb1);
      }
  }
  
  public function stat(path:String):Promise<Stat> {
    return @:futurize s3.headObject({Bucket: bucket, Key: sanitize(path)}, $cb1)
      .next(function(o):Stat return {
        size: o.ContentLength,
        mime: o.ContentType,
        lastModified: cast o.LastModified, // extern is wrong, it is Date already
        metadata: o.Metadata,
      });
  }
  
  public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo> {
    return if(options != null && options.isPublic && options.saveAsFilename == null)
      {url: 'https://$bucket.s3.amazonaws.com/' + sanitize(path), method: GET, headers: []}
    else @:futurize s3.getSignedUrl('getObject', {
      Bucket: bucket, 
      Key: sanitize(path),
      ResponseContentDisposition: switch options {
        case null | {saveAsFilename: null}: null;
        case {saveAsFilename: filename}: 'attachment; filename="$filename"';
      },
      #if why.fs.snapExpiry
      Expires: {
        var now = Date.now();
        var buffer = now.delta(15 * 60000);
        var target = new Date(buffer.getFullYear(), buffer.getMonth(), buffer.getDate() + 7 - buffer.getDay(), 0, 0, 0);
        Std.int((target.getTime() - buffer.getTime()) / 1000);
      },
      #end
    }, $cb1)
      .next(function(url) return {url: url, method: GET, headers: []});
  }
  
  public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo> {
    if(options == null || options.mime == null) return new Error('Requires mime type');
    return @:futurize s3.getSignedUrl('putObject', {
      Bucket: bucket, 
      Key: sanitize(path), 
      ACL: (options != null && options.isPublic) ? 'public-read' : 'private',
      ContentType: options.mime,
      CacheControl: options.cacheControl,
      Expires: options.expires,
      Metadata: 
        switch options {
          case null | {metadata: null}: {}
          case {metadata: obj}: obj;
        }
    }, $cb1)
      .next(function(url) return {
        url: url, 
        method: PUT, 
        headers: [
          new HeaderField(CONTENT_TYPE, options.mime),
          new HeaderField(CACHE_CONTROL, options.cacheControl),
        ]
      });
  }
  
  inline static function sanitize(path:String) {
    return path.removeLeadingSlash();
  }
}

@:build(futurize.Futurize.build())
class S3Sink extends SinkBase<Error, Noise> {
  var buffer = new BytesBuffer();
  var ended = false;
  var s3:NativeS3;
  var params:PutObjectInput;
  
  public function new(s3, params) {
    this.s3 = s3;
    this.params = params;
  }
  
  override function get_sealed() return ended;
  
  override function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
    return source.forEach(function(chunk) {
      buffer.add(chunk);
      return Resume;
    }).flatMap(function(o):Future<PipeResult<EIn, Error, Noise>> return switch o {
      case Depleted:
        if(options.end) {
          ended = true;
          params.Body = Buffer.hxFromBytes(buffer.getBytes());
          @:futurize s3.putObject(params, $cb).map(function(o) return switch o {
            case Success(_): AllWritten;
            case Failure(e): cast SinkFailed(e, Source.EMPTY);
          });
        } else {
          Future.sync(AllWritten);
        }
      case Failed(e):
        Future.sync(cast SourceFailed(e));
      case Halted(rest):
        throw 'unreachable';
    });
  }
}