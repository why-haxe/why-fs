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
  
  public function listRecursive() {
    fs.list('src/why')
      .next(function(entries) {
        asserts.assert(!entries.exists(function(entry) return entry == 'fs'));
        return Noise;
      })
      .handle(asserts.handle);
    return asserts;
  }
  
  public function listNonRecursive() {
    fs.list('src/why', false)
      .next(function(entries) {
        asserts.assert(entries.exists(function(entry) return entry == 'fs'));
        return Noise;
      })
      .handle(asserts.handle);
    return asserts;
  }
}