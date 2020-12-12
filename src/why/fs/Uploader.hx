package why.fs;

import tink.http.Client.*;
import tink.http.Request;
import tink.io.Source;

using tink.CoreApi;

class Uploader {
	public static function upload(request:Promise<OutgoingRequestHeader>, body:IdealSource) {
		return Progress.make((progress, finish) -> {
			request
				.next(header -> {
					fetch(header.url, {
						method: header.method,
						headers: [for (f in header) f],
						body: body,
						handlers: {
							upload: v -> progress(v.value, v.total),
						}
					})
						.all();
				})
				.handle(finish);
		});
	}
}
