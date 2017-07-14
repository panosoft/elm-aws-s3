var _panosoft$elm_aws_s3$Native_S3 = function() {
    const S3 = require('aws-sdk/clients/s3');
	const mime = require('mime-types');
    const { nativeBinding, succeed, fail } = _elm_lang$core$Native_Scheduler

    const apiVersion = '2006-03-01';

	const createS3 = config =>
		new S3({
			apiVersion: apiVersion,
			region: config.region,
			accessKeyId: config.accessKeyId,
			secretAccessKey: config.secretAccessKey,
            serverSideEncryption: config.serverSideEncryption,
			sslEnabled: true,
			computeChecksums: true
		});

	const headObjectInternal = (config, bucket, key, cb) => {
		const s3 = createS3(config);
		return s3.headObject({Bucket: bucket, Key: key}, cb);
	};

    const objectExists = F3((config, bucket, key) =>
        nativeBinding(callback => {
            console.log(config, bucket, key);
            try {
				headObjectInternal(config, bucket, key, (err, data) => {
                    console.log(err, data);
					callback(err
						? (err.statusCode === 404 ? succeed(false) : fail(err.code))
						: succeed(true)
					);
                });
            }
            catch (error) {
            	callback(fail(error.message));
        	 }
        }));

    const objectProperties = F3((config, bucket, key) =>
        nativeBinding(callback => {
            try {
                headObjectInternal(config, bucket, key, (err, data) => {
                    console.log(err, data);
                    callback(err
                    	? fail(err.code)
                    	: succeed({contentType: data.ContentType, contentLength: data.ContentLength,
                            contentEncoding: (data.ContentEncoding ? _elm_lang$core$Maybe$Just(data.ContentEncoding) : _elm_lang$core$Maybe$Nothing),
                            serverSideEncryption: data.ServerSideEncryption})
                    );
                });
            }
            catch (error) {
            	callback(fail(error.message));
        	 }
        }));

    const getObject = F3((config, bucket, key) =>
        nativeBinding(callback => {
            try {
				const s3 = createS3(config);
				s3.getObject({Bucket: bucket, Key: key}, (err, data) => {
                    callback(err
                    	? fail(err.message)
                    	: succeed(data)
                    );
                });
            }
            catch (error) {
            	callback(fail(error.message));
        	 }
        }));

    const putObject = F4((config, bucket, key, body) =>
        nativeBinding(callback => {
            try {
				const s3 = createS3(config);
				const params = {Bucket: bucket, Key: filename, Body: body};
				const contentType = mime.lookup(filename);
     	       	if (contentType) {
					params.ContentType = contentType;
				}
     	       	if (config.serverSideEncryption) {
					params.ServerSideEncryption = 'AES256';
				}

            	s3.putObject(params, (err, data) => {
                    callback(err
                    	? fail(err.message)
                    	: succeed(data)
                    );
                });
            }
            catch (error) {
            	callback(fail(error.message));
        	 }
        }));

    return { objectExists, objectProperties, getObject, putObject };
}();
