package ;

import tink.unit.*;
import tink.testrunner.*;
import why.Fs;
import why.fs.*;

using tink.CoreApi;
using StringTools;
using haxe.io.Path;
using Lambda;

@:asserts
class RunTests {

  static function main() {
    Runner.run(TestBatch.make([
      new RunTests(new Local({root: '.', getDownloadUrl: null, getUploadUrl: null})),
    ])).handle(Runner.exit);
  }
  
  var fs:Fs;
  function new(fs) this.fs = fs;
  
  @:variant('Recursive'(true, false))
  @:variant('Non-Recursive'(false, true))
  @:variant('Default'(null, false))
  public function list(recursive:Null<Bool>, result) {
    fs.list('src/why', recursive)
      .next(function(entries) {
        asserts.assert(entries.exists(function(entry) return entry == 'fs') == result);
        return Noise;
      })
      .handle(asserts.handle);
    return asserts;
  }
}