package why.fs;

import tink.http.Response;
import tink.http.Header;

using tink.io.Source;
using tink.CoreApi;

class FilesApi {
  var fs:Fs;
  
  public function new(fs)
    this.fs = fs;
    
  @:put('/')
  @:params(path in query)
  public function upload(path:String, body:RealSource):Promise<Noise> {
    return body.pipeTo(fs.write(path))
      .next(o -> switch o {
        case AllWritten: Promise.lift({});
        case SourceFailed(e) | SinkFailed(e, _): e;
        case SinkEnded(_): new Error('Sink ended unexpectedly');
      });
  }
  
  @:get('/')
  @:params(path in query, saveAs in query)
  public function download(path:String, ?saveAs:String):Promise<OutgoingResponse> {
    var headers = [new HeaderField(CONTENT_TYPE, mime.Mime.lookup(path))];
    if(saveAs != null) headers.push(new HeaderField(CONTENT_DISPOSITION, 'attachment; filename="$saveAs"'));
    return new OutgoingResponse(
      new ResponseHeader(200, 'OK', headers),
      fs.read(path).idealize(e -> Source.EMPTY)
    );
  }
}