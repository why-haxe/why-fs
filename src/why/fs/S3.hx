package why.fs;

import why.Fs;
import tink.http.Method;
import tink.http.Header;

#if nodejs
import js.node.Buffer;
import js.aws.s3.S3 as NativeS3;
#end

using tink.CoreApi;
using tink.io.Source;
using tink.io.Sink;
using StringTools;
using haxe.io.Path;

@:build(futurize.Futurize.build())
@:require('extern-js-aws-sdk')
class S3 implements Fs {
  
  var bucket:String;
  var s3:NativeS3;
  
  public function new(bucket, ?opt) {
    this.bucket = bucket;
    s3 = new NativeS3(opt);
  }
  
  public function list(path:String, ?resursive:Bool = true):Promise<Array<Entry>> {
    var prefix = sanitize(path).addTrailingSlash();
    if(resursive) {
      return @:futurize s3.listObjectsV2({Bucket: bucket, Prefix: prefix}, $cb1)
        .next(function(o):Array<Entry> {
          return [for(obj in o.Contents) {
            var relativePath = obj.Key.substr(prefix.length); // Folder created in S3 console GUI
            if(relativePath != '')
              new Entry(relativePath, File, {
                size: obj.Size,
                lastModified: cast obj.LastModified, // extern is wrong, it is Date already
              });
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
    var from = sanitize(from);
    var to = sanitize(to);
    
    // https://stackoverflow.com/a/38903136/3212365
    return @:futurize s3.copyObject({Bucket: bucket, CopySource: '$bucket/$from', Key: to}, $cb1)
        .next(function(_) return @:futurize s3.getObjectAcl({Bucket: bucket, Key: from}, $cb1))
        .next(function(acl) return @:futurize s3.putObjectAcl({Bucket: bucket, Key: to, AccessControlPolicy: acl}, $cb1))
        .next(function(_) return @:futurize s3.deleteObject({Bucket: bucket, Key: from}, $cb1));
  }
  
  public function read(path:String):RealSource {
    return @:futurize s3.getObject({Bucket: bucket, Key: sanitize(path)}, $cb1)
      .next(function(o):RealSource return (o.Body:Buffer).hxToBytes());
  }
  
  public function write(path:String, ?options:WriteOptions):RealSink {
    if(options == null) options = {};
    var pass = new js.node.stream.PassThrough();
    var buf = new Buffer(0);
    pass.on('data', function(d) buf = Buffer.concat([buf, d]));
    pass.on('end', function() @:futurize s3.putObject({
      Bucket: bucket, 
      Key: sanitize(path), 
      Body: buf,
      ACL: (options != null && options.isPublic) ? 'public-read' : 'private',
      ContentType: options.mime,
      CacheControl: options.cacheControl,
      Expires: cast options.expires,
      Metadata: 
        switch options {
          case null | {metadata: null}: {}
          case {metadata: obj}: (cast obj:{});
        }
    }, $cb1).handle(function(o) trace(o)));
    var sink = Sink.ofNodeStream('Sink: $path', pass);
    return sink;
  }
  
  public function delete(path:String):Promise<Noise> {
    path = sanitize(path);
    return 
      if(path.charCodeAt(path.length - 1) == '/'.code) { // delete recursively if `path` is a folder
        // WTH batch delete not supported in Node.js?! https://docs.aws.amazon.com/AmazonS3/latest/dev/DeletingMultipleObjects.html
        list(path)
          .next(function(entries) {
            return Promise.inParallel([for(e in entries) 
              @:futurize s3.deleteObject({Bucket: bucket, Key: Path.join([path, e.path])}, $cb1)
            ]);
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
  
  static function sanitize(path:String) {
    if(path.startsWith('/')) path = path.substr(1);
    return path;
  }
}