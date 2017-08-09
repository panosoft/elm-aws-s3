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
			sslEnabled: true,
			computeChecksums: true
		});

	const headObjectInternal = (config, bucket, key, cb) => {
		const s3 = createS3(config);
		return s3.headObject({Bucket: bucket, Key: key}, cb);
	};

    const printableResponse = response => {
        const pResponse = {};
        Object.keys(response).filter(key =>  response.hasOwnProperty(key) && key != "Body").forEach(key => pResponse[key] = response[key]);
        return pResponse;
    };

    const logRequest = (debug, operation, bucket, key, body) => {
            debug
                ? console.log('Native Request --' + operation + ' Bucket: ' + bucket + ' Key: ' + key
                    + (body ? ' Body length: ' + body.length : ''))
                : null;
    };

    const logResponse = (debug, operation, bucket, key, err, data) => {
        debug
            ? (err
                ? console.log(('Native Error --' + operation + ' Bucket: ' + bucket + ' Key: ' + key), err)
                : console.log(('Native Response --' + operation + ' Bucket: ' + bucket + ' Key: ' + key), printableResponse(data))
                )
            : null;
    };

    const createMaybe = value => value ? _elm_lang$core$Maybe$Just(value) : _elm_lang$core$Maybe$Nothing;

    const createErrorResponse = (bucket, key, err) =>
        ({
            bucket: bucket,
            key: key,
            message: createMaybe(err.message),
            code: createMaybe(err.code),
            retryable: createMaybe(err.retryable),
            statusCode: createMaybe(err.statusCode),
            time: createMaybe(err.time ? err.time.toUTCString() : err.time),
            region: createMaybe(err.region)
        });

    const objectExists = F3((config, bucket, key) =>
        nativeBinding(callback => {
            try {
                const operation = 'objectExists';
                logRequest(config.debug, operation, bucket, key);
				headObjectInternal(config, bucket, key, (err, data) => {
                    logResponse(config.debug, operation, bucket, key, err, data);
					callback(err
                        ? (err.statusCode === 404 || err.code === 'NotFound' ? succeed({bucket: bucket, key: key, exists: false}) : fail(createErrorResponse(bucket, key, err)))
                        : succeed({bucket: bucket, key: key, exists: true}));
                });
            }
            catch (error) {
                callback(fail(createErrorResponse(bucket, key, error)));
            }
        }));

    const objectProperties = F3((config, bucket, key) =>
        nativeBinding(callback => {
            try {
                const operation = 'objectProperties';
                logRequest(config.debug, operation, bucket, key);
                headObjectInternal(config, bucket, key, (err, data) => {
                    logResponse(config.debug, operation, bucket, key, err, data);
                    callback(err
                        ? fail(createErrorResponse(bucket, key, err))
                        : succeed({bucket: bucket, key: key, contentType: data.ContentType, contentLength: data.ContentLength,
                            contentEncoding: createMaybe(data.ContentEncoding),
                            lastModified: createMaybe(data.LastModified ? data.LastModified.toUTCString() : data.LastModified),
                            deleteMarker: createMaybe(data.DeleteMarker),
                            versionId: createMaybe(data.VersionId),
                            serverSideEncryption: data.ServerSideEncryption, storageClass: data.StorageClass ? data.StorageClass : 'STANDARD'}));
                });
            }
            catch (error) {
                callback(fail(createErrorResponse(bucket, key, error)));
            }
        }));

    const getObject = F3((config, bucket, key) =>
        nativeBinding(callback => {
            try {
				const s3 = createS3(config);
                const operation = 'getObject';
                logRequest(config.debug, operation, bucket, key);
				s3.getObject({Bucket: bucket, Key: key}, (err, data) => {
                    logResponse(config.debug, operation, bucket, key, err, data);
                    callback(err
                        ? fail(createErrorResponse(bucket, key, err))
                        : succeed({bucket: bucket, key: key, body: data.Body, contentType: data.ContentType, contentLength: data.ContentLength,
                            contentEncoding: createMaybe(data.ContentEncoding),
                            lastModified: createMaybe(data.LastModified ? data.LastModified.toUTCString() : data.LastModified),
                            deleteMarker: createMaybe(data.DeleteMarker),
                            versionId: createMaybe(data.VersionId),
                            serverSideEncryption: data.ServerSideEncryption, storageClass: data.StorageClass ? data.StorageClass : 'STANDARD'})
                    );
                });
            }
            catch (error) {
                callback(fail(createErrorResponse(bucket, key, error)));
            }
        }));

    const putObject = F4((config, bucket, key, body) =>
        nativeBinding(callback => {
            try {
				const s3 = createS3(config);
                const operation = 'putObject';
                logRequest(config.debug, operation, bucket, key, body);
				const params = {Bucket: bucket, Key: key, Body: body};
				const contentType = mime.lookup(key);
     	       	if (contentType) {
					params.ContentType = contentType;
				}
     	       	if (config.serverSideEncryption) {
					params.ServerSideEncryption = 'AES256';
				}

            	s3.putObject(params, (err, data) => {
                    logResponse(config.debug, operation, bucket, key, err, data);
                    callback(err
                        ? fail(createErrorResponse(bucket, key, err))
                        : succeed({bucket: bucket, key: key, versionId: createMaybe(data.VersionId), serverSideEncryption: data.ServerSideEncryption})
                    );
                });
            }
            catch (error) {
                callback(fail(createErrorResponse(bucket, key, error)));
            }
        }));

    return { objectExists, objectProperties, getObject, putObject };
}();
