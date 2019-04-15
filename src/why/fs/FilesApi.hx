package why.fs;

import tink.http.Response;
import tink.http.Header;

using tink.io.Source;
using tink.CoreApi;

/**
 * DO NOT USE THIS IN PRODUCTION
 * 
 * A handy file API. For quick testing only.
 * There is no security in place. 
 * Client and read/write any location of your filesystem.
 */
class FilesApi {
  var fs:Fs;
  
  public function new(fs)
    this.fs = fs;
    
  @:put('/')
  @:params(path in query)
  public function upload(path:String, body:RealSource):Promise<Noise> {
    return body.pipeTo(fs.write(path))
      .next(function(o) return switch o {
        case AllWritten: Noise;
        case SourceFailed(e) | SinkFailed(e, _): e;
        case SinkEnded(_): new Error('Sink ended unexpectedly');
      });
  }
  
  @:get('/')
  @:params(path in query, saveAs in query)
  public function download(path:String, ?saveAs:String):Promise<OutgoingResponse> {
    var mime = switch mime.Mime.lookup(path) {
      case null: 'application/octet-stream';
      case v: v;
    }
    var headers = [new HeaderField(CONTENT_TYPE, mime)];
    if(saveAs != null) headers.push(new HeaderField(CONTENT_DISPOSITION, 'attachment; filename="$saveAs"'));
    return new OutgoingResponse(
      new ResponseHeader(200, 'OK', headers),
      fs.read(path).idealize(function(_) return Source.EMPTY)
    );
  }
}